import Foundation

enum DownloadEngineError: LocalizedError {
    case missingTool(String)
    case processFailed(String)
    case missingOutputPath

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool): "Missing required tool: \(tool)"
        case .processFailed(let output): output.isEmpty ? "Download process failed" : output
        case .missingOutputPath: "Could not determine the downloaded file path"
        }
    }
}

private final class SustainedThrottleRefreshController: @unchecked Sendable {
    private let lock = NSLock()
    private var detector = RollingLowSpeedDetector(
        thresholdBytesPerSecond: 500 * 1_024,
        requiredDuration: 60
    )
    private var process: Process?
    private var latestDownloadedBytes: Double?
    private var requestedRefresh = false
    private var timer: DispatchSourceTimer?

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        if timer == nil {
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now() + 2, repeating: 2)
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
        lock.unlock()
    }

    func observe(_ progress: DownloadProgress, now: Date = Date()) {
        evaluate(downloadedBytes: progress.downloadedBytes, now: now)
    }

    private func tick() {
        lock.lock()
        let downloadedBytes = latestDownloadedBytes
        lock.unlock()
        evaluate(downloadedBytes: downloadedBytes, now: Date())
    }

    private func evaluate(downloadedBytes: Double?, now: Date) {
        var processToTerminate: Process?
        lock.lock()
        if let downloadedBytes {
            latestDownloadedBytes = downloadedBytes
        }
        if !requestedRefresh,
           detector.shouldRefresh(downloadedBytes: latestDownloadedBytes, now: now) {
            requestedRefresh = true
            processToTerminate = process
            timer?.cancel()
            timer = nil
        }
        lock.unlock()
        processToTerminate?.terminate()
    }

    var didRequestRefresh: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requestedRefresh
    }

    deinit {
        timer?.cancel()
    }
}

final class DownloadEngine {
    private let runner = ProcessRunner()
    private let fileManager = FileManager.default
    private var mediaConverter: MediaConverter {
        MediaConverter(
            runner: runner,
            fileManager: fileManager,
            ffmpegPath: ffmpegPath,
            ffprobePath: ffprobePath
        )
    }

    var ytdlpPath: String { MediaBinaryLocator.ytDlp() ?? "/opt/homebrew/bin/yt-dlp" }
    var ffmpegPath: String { MediaBinaryLocator.ffmpeg() ?? "/opt/homebrew/bin/ffmpeg" }
    var ffprobePath: String { MediaBinaryLocator.ffprobe() ?? "/opt/homebrew/bin/ffprobe" }
    private var ytDlpPluginDirectory: String? {
        // yt-dlp expects --plugin-dirs to contain one or more plugin package
        // directories; Resources/YtDlpPlugins is that package directory.
        Bundle.main.resourceURL?.path
    }

    func validateTools() throws {
        for (path, name) in [(ytdlpPath, "yt-dlp"), (ffmpegPath, "ffmpeg"), (ffprobePath, "ffprobe")] {
            if !fileManager.isExecutableFile(atPath: path) {
                throw DownloadEngineError.missingTool(name)
            }
        }
    }

    func download(
        url: String,
        directMediaURLs: [String] = [],
        browserResolvedTitle: String? = nil,
        folder: String,
        temporaryFolder: String? = nil,
        maximumHeight: Int? = nil,
        kind: DownloadKind = .video,
        browserSession: BrowserSessionConfiguration,
        onProcess: @escaping (Process) -> Void,
        onTitle: @escaping (String) -> Void,
        onProgress: @escaping (DownloadProgress) -> Void
    ) async throws -> String {
        if kind == .image {
            return try await downloadImage(url: url, folder: folder, onTitle: onTitle, onProgress: onProgress)
        }
        try validateTools()
        // Keep FFmpeg and yt-dlp away from untrusted social captions while
        // they are writing. A simple ASCII staging name prevents an otherwise
        // valid download from failing at output creation; after success we
        // rename locally and keep the staging file if that rename is rejected.
        let pageWorkingOutputTitle = browserResolvedTitle.map { _ in "vbd-\(UUID().uuidString.lowercased())" }
        var directFailures: [String] = []
        for directMediaURL in directMediaURLs {
            let directWorkingOutputTitle = browserResolvedTitle.map { _ in "vbd-\(UUID().uuidString.lowercased())" }
            let directAttempt = try await runDownloadAttempt(
                url: directMediaURL,
                refererURL: url,
                browserResolvedTitle: directWorkingOutputTitle,
                folder: folder,
                temporaryFolder: temporaryFolder,
                maximumHeight: maximumHeight,
                kind: kind,
                cookieSpecification: nil,
                onProcess: onProcess,
                onTitle: onTitle,
                onProgress: onProgress
            )
            if directAttempt.result.status == 0 {
                guard let downloadedPath = directAttempt.downloadedPath, !downloadedPath.isEmpty else {
                    removeOwnedStagingArtifact(directAttempt.targetPath, folder: folder)
                    throw DownloadEngineError.missingOutputPath
                }
                let hasPlausibleMedia = kind == .video
                    ? await isPlausibleMediaFile(downloadedPath)
                    : true
                guard hasPlausibleMedia else {
                    removeOwnedStagingArtifact(downloadedPath, folder: folder)
                    removeOwnedStagingArtifact(directAttempt.targetPath, folder: folder)
                    directFailures.append("Douyin CDN returned a non-video payload; trying another source")
                    continue
                }
                return applyBrowserResolvedFilename(
                    downloadedPath,
                    browserResolvedTitle: browserResolvedTitle,
                    folder: folder
                )
            }
            removeOwnedStagingArtifact(directAttempt.targetPath, folder: folder)
            directFailures.append(lastUsefulLine(in: directAttempt.result.output))
        }

        // When all browser-resolved CDN variants fail, make one truthful page
        // extractor attempt. This is a final fallback, not a replacement for
        // the direct error: if it also fails, both tiers remain visible.
        let initiallyUseCookies = browserSession.shouldUseCookiesInitially(for: url)
        if initiallyUseCookies { try BrowserProfileProbe.check(browserSession) }
        var attempt = try await runDownloadAttempt(
            url: url,
            refererURL: nil,
            browserResolvedTitle: pageWorkingOutputTitle,
            folder: folder,
            temporaryFolder: temporaryFolder,
            maximumHeight: maximumHeight,
            kind: kind,
            cookieSpecification: initiallyUseCookies ? browserSession.cookieSpecification : nil,
            onProcess: onProcess,
            onTitle: onTitle,
            onProgress: onProgress
        )
        let retryWithCookies = attempt.result.status != 0 && DownloadSessionPlan.shouldRetryWithCookies(
            directMediaURL: nil,
            pageURL: url,
            processOutput: attempt.result.output,
            alreadyUsedCookies: initiallyUseCookies,
            browserSession: browserSession
        )
        let refreshDouyinCookies = attempt.result.status != 0 && DownloadSessionPlan.shouldRefreshCookiesAndRetry(
            directMediaURL: nil,
            pageURL: url,
            processOutput: attempt.result.output,
            alreadyUsedCookies: initiallyUseCookies,
            browserSession: browserSession
        )
        if retryWithCookies || refreshDouyinCookies {
            try BrowserProfileProbe.check(browserSession)
            // A fresh process makes yt-dlp copy the browser cookie database
            // again. The brief pause lets a just-opened Douyin page finish
            // rotating its ephemeral anti-bot token, without adding a loop.
            if refreshDouyinCookies {
                try await Task.sleep(for: .milliseconds(900))
            }
            removeOwnedStagingArtifact(attempt.targetPath, folder: folder)
            attempt = try await runDownloadAttempt(
                url: url,
                refererURL: nil,
                browserResolvedTitle: pageWorkingOutputTitle,
                folder: folder,
                temporaryFolder: temporaryFolder,
                maximumHeight: maximumHeight,
                kind: kind,
                cookieSpecification: browserSession.cookieSpecification,
                onProcess: onProcess,
                onTitle: onTitle,
                onProgress: onProgress
            )
        }

        guard attempt.result.status == 0 else {
            removeOwnedStagingArtifact(attempt.targetPath, folder: folder)
            let pageFailure = lastUsefulLine(in: attempt.result.output)
            if let directFailure = directFailures.last {
                throw DownloadEngineError.processFailed(
                    "Direct media fallback exhausted (\(directFailures.count)): \(directFailure) · Page extractor: \(pageFailure)"
                )
            }
            throw DownloadEngineError.processFailed(pageFailure)
        }
        guard let downloadedPath = attempt.downloadedPath, !downloadedPath.isEmpty else {
            throw DownloadEngineError.missingOutputPath
        }
        return applyBrowserResolvedFilename(
            downloadedPath,
            browserResolvedTitle: browserResolvedTitle,
            folder: folder
        )
    }

    func testBrowserSession(_ configuration: BrowserSessionConfiguration) async throws -> String {
        try validateTools()
        guard configuration.policy != .never else {
            throw DownloadEngineError.processFailed("Browser session is disabled")
        }
        try BrowserProfileProbe.check(configuration)
        let result = try await runner.run(executable: ytdlpPath, arguments: [
            "--cookies-from-browser", configuration.cookieSpecification,
            "--socket-timeout", "15", "--retries", "1",
            "--simulate",
            "--skip-download",
            "--no-playlist",
            "--no-warnings",
            "--print", "SESSION_OK:%(id)s",
            "https://www.youtube.com/watch?v=BaW_jenozKc",
        ])
        guard result.status == 0, result.output.contains("SESSION_OK:") else {
            throw DownloadEngineError.processFailed(lastUsefulLine(in: result.output))
        }
        return configuration.source.displayName
    }

    private func runDownloadAttempt(
        url: String,
        refererURL: String?,
        browserResolvedTitle: String?,
        folder: String,
        temporaryFolder: String?,
        maximumHeight: Int?,
        kind: DownloadKind,
        cookieSpecification: String?,
        onProcess: @escaping (Process) -> Void,
        onTitle: @escaping (String) -> Void,
        onProgress: @escaping (DownloadProgress) -> Void
    ) async throws -> (result: ProcessResult, downloadedPath: String?, targetPath: String?) {
        let arguments = DownloadCommandBuilder.arguments(
            url: url,
            folder: folder,
            ffmpegPath: ffmpegPath,
            maximumHeight: maximumHeight,
            kind: kind,
            cookieSpecification: cookieSpecification,
            temporaryFolder: temporaryFolder,
            refererURL: refererURL,
            browserResolvedTitle: browserResolvedTitle,
            pluginDirectory: ytDlpPluginDirectory
        )
        var throttleRefreshCount = 0
        let maximumThrottleRefreshes = 3
        while true {
            var downloadedPath: String?
            var targetPath: String?
            let throttleController = URLNormalizer.isBilibili(url) && throttleRefreshCount < maximumThrottleRefreshes
                ? SustainedThrottleRefreshController()
                : nil
            var processEnvironment = ["PYTHONDONTWRITEBYTECODE": "1"]
            if URLNormalizer.isBilibili(url) {
                processEnvironment["VBD_BILIBILI_CDN_INDEX"] = String(throttleRefreshCount)
            }
            let result = try await runner.run(
                executable: ytdlpPath,
                arguments: arguments,
                environmentOverrides: processEnvironment,
                onProcess: { process in
                    throttleController?.attach(process)
                    onProcess(process)
                }
            ) { line in
                if line.hasPrefix("TITLE:") {
                    onTitle(String(line.dropFirst("TITLE:".count)))
                } else if line.hasPrefix("TARGET:") {
                    targetPath = String(line.dropFirst("TARGET:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("FILE:") {
                    downloadedPath = String(line.dropFirst("FILE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let progress = ProgressProtocol.ytDlpProgress(from: line) {
                    throttleController?.observe(progress)
                    onProgress(progress)
                }
            }
            if throttleController?.didRequestRefresh == true {
                // The same stable temp directory and explicit --continue make
                // the fresh extraction resume its existing .part bytes.
                throttleRefreshCount += 1
                continue
            }
            return (result, downloadedPath, targetPath)
        }
    }

    private func downloadImage(
        url rawURL: String,
        folder: String,
        onTitle: (String) -> Void,
        onProgress: (DownloadProgress) -> Void
    ) async throws -> String {
        guard let url = URL(string: rawURL) else {
            throw DownloadEngineError.processFailed("Invalid image URL")
        }
        // Social CDNs commonly reject a bare, app-originated request as a
        // hotlink. The extension deliberately passes the final media URL, so
        // give that request the same ordinary browser context a viewer would
        // have, without reading or copying any browser cookies.
        let (temporaryURL, response) = try await URLSession.shared.download(for: imageRequest(for: url))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse).map { " (HTTP \($0.statusCode))" } ?? ""
            throw DownloadEngineError.processFailed("Image server did not return a downloadable file\(status)")
        }

        let queryFormat = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "format" })?.value?.lowercased()
        let mimeExtension: String? = switch http.mimeType?.lowercased() {
        case "image/jpeg": "jpg"
        case "image/png": "png"
        case "image/webp": "webp"
        case "image/gif": "gif"
        default: nil
        }
        let fileExtension = queryFormat?.replacingOccurrences(of: "jpeg", with: "jpg")
            ?? mimeExtension
            ?? "jpg"
        let rawStem = url.deletingPathExtension().lastPathComponent
        let safeStem = rawStem.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar.value == 45 || scalar.value == 95 ? String(scalar) : "-"
        }.joined()
        let platform = URLNormalizer.imageDisplayName(for: rawURL).replacingOccurrences(of: " image", with: "")
        let safePlatform = platform.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }.joined().trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let prefix = safePlatform.isEmpty ? "Image" : safePlatform
        let stem = safeStem.isEmpty ? "\(prefix)-image" : "\(prefix)-\(safeStem)"
        let destination = uniqueDestinationURL(folder: folder, stem: stem, extension: fileExtension)
        try fileManager.moveItem(at: temporaryURL, to: destination)
        onTitle(URLNormalizer.imageDisplayName(for: rawURL))
        onProgress(DownloadProgress(percent: 100, speed: "", eta: ""))
        return destination.path
    }

    private func imageRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.setValue(
            "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X 15_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9,vi;q=0.8", forHTTPHeaderField: "Accept-Language")

        let host = url.host?.lowercased() ?? ""
        let referer: String?
        if host.hasSuffix("fbcdn.net") {
            referer = "https://www.facebook.com/"
        } else if host.hasSuffix("cdninstagram.com") {
            referer = "https://www.instagram.com/"
        } else if host == "pbs.twimg.com" {
            referer = "https://x.com/"
        } else if host.contains("googleusercontent.com") || host.contains("gstatic.com") || host.hasPrefix("images.google.") {
            referer = "https://www.google.com/"
        } else {
            referer = nil
        }
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }

    func needsAudioConversion(_ filePath: String) -> Bool {
        mediaConverter.needsAudioConversion(filePath)
    }

    func convertToMP3(
        _ sourcePath: String,
        onProcess: @escaping (Process) -> Void
    ) async throws -> String {
        try await mediaConverter.convertToMP3(sourcePath, onProcess: onProcess)
    }

    func needsConversion(_ filePath: String) async throws -> Bool {
        try await mediaConverter.needsVideoConversion(filePath)
    }

    func convertToCompatibleMP4(
        _ sourcePath: String,
        onProcess: @escaping (Process) -> Void
    ) async throws -> String {
        try await mediaConverter.convertToCompatibleMP4(sourcePath, onProcess: onProcess)
    }

    private func uniqueDestinationURL(folder: String, stem: String, extension fileExtension: String) -> URL {
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        var candidate = directory.appendingPathComponent("\(stem).\(fileExtension)")
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-\(index).\(fileExtension)")
            index += 1
        }
        return candidate
    }

    private func applyBrowserResolvedFilename(
        _ downloadedPath: String,
        browserResolvedTitle: String?,
        folder: String
    ) -> String {
        guard let stem = DownloadFileNameTemplate.browserResolvedTitle(browserResolvedTitle) else {
            return downloadedPath
        }
        let source = URL(fileURLWithPath: downloadedPath)
        let fileExtension = source.pathExtension
        guard !fileExtension.isEmpty else { return downloadedPath }
        let destination = uniqueDestinationURL(folder: folder, stem: stem, extension: fileExtension)
        guard source.standardizedFileURL != destination.standardizedFileURL else { return downloadedPath }
        do {
            try fileManager.moveItem(at: source, to: destination)
            return destination.path
        } catch {
            // The media is already complete. A cosmetic rename must never turn
            // it into a failed download on an unusual volume/filesystem.
            return downloadedPath
        }
    }

    private func isPlausibleMediaFile(_ path: String) async -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        guard let probe = try? await runner.run(
            executable: ffprobePath,
            arguments: [
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=codec_type",
                "-of", "default=noprint_wrappers=1:nokey=1",
                path,
            ]
        ) else { return false }
        return DownloadedMediaValidation.isPlausibleVideo(
            fileSize: size.int64Value,
            probeStatus: probe.status,
            probeOutput: probe.output
        )
    }

    private func removeOwnedStagingArtifact(_ path: String?, folder: String) {
        guard let path, !path.isEmpty else { return }
        let candidate = URL(fileURLWithPath: path).standardizedFileURL
        let outputFolder = URL(fileURLWithPath: folder, isDirectory: true).standardizedFileURL
        guard candidate.deletingLastPathComponent() == outputFolder,
              candidate.lastPathComponent.hasPrefix("vbd-") else { return }
        try? fileManager.removeItem(at: candidate)
    }

    private func lastUsefulLine(in output: String) -> String {
        ProcessFailureSummary.lastUsefulLine(in: output)
    }
}
