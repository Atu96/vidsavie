import Foundation

private struct TestSuite {
    private(set) var assertions = 0
    private(set) var failures: [String] = []

    mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { failures.append(message) }
    }
}

@main
struct CoreTestMain {
    static func main() throws {
        var suite = TestSuite()

        suite.expect(AppPreferences.language(nil) == "en", "fresh app language is English")
        suite.expect(AppPreferences.language("vi") == "vi", "existing Vietnamese preference stays unchanged")
        suite.expect(AppPreferences.language("auto") == "auto", "explicit System language stays unchanged")
        suite.expect(AppPreferences.language("invalid") == "en", "invalid app language falls back to English")

        suite.expect(
            URLNormalizer.normalize("https://youtu.be/abc123?t=2") == "https://www.youtube.com/watch?v=abc123",
            "youtu.be normalization"
        )
        suite.expect(
            URLNormalizer.normalize("https://www.youtube.com/shorts/xyz987?feature=share") == "https://www.youtube.com/watch?v=xyz987",
            "YouTube Shorts normalization"
        )
        suite.expect(
            URLNormalizer.normalize("https://www.douyin.com/search/test?modal_id=7664504993885457673") == "https://www.douyin.com/video/7664504993885457673",
            "Douyin modal normalization"
        )
        suite.expect(
            URLNormalizer.normalize("https://x.com/user/status/123456789/photo/1") == "https://x.com/i/status/123456789",
            "X status normalization"
        )
        suite.expect(URLNormalizer.isBilibili("https://www.bilibili.com/video/BV1xx411c7mD"), "recognize Bilibili video URL")
        suite.expect(!URLNormalizer.isSupported("file:///tmp/video.mp4"), "reject file URL")
        suite.expect(!URLNormalizer.isSupported("javascript:alert(1)"), "reject JavaScript URL")
        let portableResourceURL = URL(fileURLWithPath: "/Applications/Video Batch Downloader.app/Contents/Resources")
        suite.expect(
            MediaBinaryLocator.isBundled(
                "/Applications/Video Batch Downloader.app/Contents/Resources/Tools/yt-dlp",
                resourceURL: portableResourceURL
            ),
            "portable tool locator recognizes bundled executable"
        )
        suite.expect(
            !MediaBinaryLocator.isBundled("/opt/homebrew/bin/yt-dlp", resourceURL: portableResourceURL),
            "portable tool locator distinguishes Homebrew executable"
        )
        let locatorFixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoBatchLocator-\(UUID().uuidString)", isDirectory: true)
        let locatorTools = locatorFixture.appendingPathComponent("Tools", isDirectory: true)
        try FileManager.default.createDirectory(at: locatorTools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: locatorFixture) }
        let bundledYtDlp = locatorTools.appendingPathComponent("yt-dlp")
        FileManager.default.createFile(atPath: bundledYtDlp.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundledYtDlp.path)
        suite.expect(
            MediaBinaryLocator.ytDlp(managedToolsURL: nil, resourceURL: locatorFixture) == bundledYtDlp.path,
            "portable tool locator prefers the bundled executable"
        )
        suite.expect(
            MediaBinaryLocator.ytDlp(managedToolsURL: locatorTools, resourceURL: nil) == bundledYtDlp.path,
            "tool locator prefers the app-managed executable"
        )
        suite.expect(
            MediaBinaryLocator.isManaged(bundledYtDlp.path, managedToolsURL: locatorTools),
            "tool locator recognizes an app-managed executable"
        )
        let mediaFixture: [String: Any] = [
            "schema": 1, "provider": "vidsavie-source-build",
            "packageID": "media-9.0.2-v1", "version": "9.0.2",
            "archiveURL": "https://github.com/Atu96/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-9.0.2-v1-arm64.zip",
            "sourceURL": "https://github.com/Atu96/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-9.0.2-v1-sources.tar.gz",
            "archiveSHA256": String(repeating: "d", count: 64),
            "sourceSHA256": String(repeating: "e", count: 64),
            "ffmpegSHA256": String(repeating: "b", count: 64),
            "ffprobeSHA256": String(repeating: "c", count: 64)
        ]
        let parsedSupportTools = try SupportToolsReleaseParser.parse(
            ytDlpChecksums: String(repeating: "a", count: 64) + "  yt-dlp_macos\n",
            mediaJSON: JSONSerialization.data(withJSONObject: mediaFixture)
        )
        suite.expect(parsedSupportTools.ytDlpChecksum == String(repeating: "a", count: 64), "support tools parse official yt-dlp checksum")
        suite.expect(parsedSupportTools.ffmpegVersion == "9.0.2", "support tools parse reviewed source-build release")
        suite.expect(parsedSupportTools.ffprobeChecksum == String(repeating: "c", count: 64), "support tools parse FFprobe checksum")
        suite.expect(parsedSupportTools.mediaArchiveChecksum == String(repeating: "d", count: 64), "media archive hash is mandatory")
        suite.expect(parsedSupportTools.mediaSourceChecksum == String(repeating: "e", count: 64), "corresponding-source hash is mandatory")
        for (key, value) in [
            ("archiveURL", "https://evil.example/tool.zip"),
            ("sourceURL", "http://github.com/Atu96/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-9.0.2-v1-sources.tar.gz"),
            ("archiveURL", "https://github.com/SomeoneElse/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-9.0.2-v1-arm64.zip"),
            ("archiveURL", "https://github.com/Atu96/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-8.0.0-v1-arm64.zip"),
            ("sourceSHA256", "invalid"),
            ("provider", "osxexperts")
        ] {
            var invalid = mediaFixture; invalid[key] = value
            let result = try? SupportToolsReleaseParser.parse(
                ytDlpChecksums: String(repeating: "a", count: 64) + " yt-dlp_macos\n",
                mediaJSON: JSONSerialization.data(withJSONObject: invalid)
            )
            suite.expect(result == nil, "reject unreviewed media manifest: \(key)")
        }
        suite.expect(!ReviewedMediaPolicy.isReviewedDirectory(locatorTools), "legacy managed FFmpeg has no source-build provenance")
        let locatorMedia = locatorTools.appendingPathComponent("ffmpeg")
        FileManager.default.createFile(atPath: locatorMedia.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locatorMedia.path)
        let legacyMediaDir = locatorFixture.appendingPathComponent("LegacyManaged", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyMediaDir, withIntermediateDirectories: true)
        let legacyExecutable = legacyMediaDir.appendingPathComponent("ffmpeg")
        FileManager.default.createFile(atPath: legacyExecutable.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyExecutable.path)
        suite.expect(MediaBinaryLocator.ffmpeg(managedToolsURL: legacyMediaDir, resourceURL: locatorFixture) == locatorMedia.path, "legacy managed media falls back to a distinct bundled executable")
        let reviewedMetadata = SupportToolsMetadata(
            ytDlpChecksum: String(repeating: "a", count: 64), ffmpegChecksum: String(repeating: "b", count: 64), ffprobeChecksum: String(repeating: "c", count: 64),
            installedYtDlpChecksum: String(repeating: "a", count: 64), installedFFmpegChecksum: String(repeating: "b", count: 64), installedFFprobeChecksum: String(repeating: "c", count: 64),
            ffmpegVersion: "9.0.2", ffprobeVersion: "9.0.2", updatedAt: Date(timeIntervalSince1970: 0), mediaPackageID: "media-9.0.2-v1",
            mediaSourceURL: "https://github.com/Atu96/vidsavie/releases/download/media-9.0.2-v1/vidsavie-media-9.0.2-v1-sources.tar.gz", mediaSourceChecksum: String(repeating: "e", count: 64)
        )
        try JSONEncoder().encode(reviewedMetadata).write(to: legacyMediaDir.appendingPathComponent("versions.json"))
        suite.expect(!ReviewedMediaPolicy.isReviewedDirectory(legacyMediaDir), "metadata alone does not claim reviewed managed media without source archive")
        try FileManager.default.createDirectory(at: legacyMediaDir.appendingPathComponent("ThirdParty"), withIntermediateDirectories: true)
        try Data([1]).write(to: legacyMediaDir.appendingPathComponent("ThirdParty/media-9.0.2-v1-sources.tar.gz"))
        suite.expect(ReviewedMediaPolicy.isReviewedDirectory(legacyMediaDir), "approved managed source provenance is recognized")
        suite.expect(MediaBinaryLocator.ffmpeg(managedToolsURL: legacyMediaDir, resourceURL: locatorFixture) == legacyExecutable.path, "reviewed managed media retains normal first priority")
        suite.expect(
            MachOArchitectureInspector.containsArm64(in: Data([0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0x00, 0x00, 0x01])),
            "support tools recognize a thin arm64 Mach-O without Command Line Tools"
        )
        suite.expect(
            !MachOArchitectureInspector.containsArm64(in: Data([0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01])),
            "support tools reject a thin x86_64 Mach-O"
        )
        let universalMachO = Data(
            [0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 2]
                + [UInt8](repeating: 0, count: 20)
                + [0x01, 0, 0, 0x0C]
                + [UInt8](repeating: 0, count: 16)
        )
        suite.expect(
            MachOArchitectureInspector.containsArm64(in: universalMachO),
            "support tools recognize arm64 inside a universal Mach-O"
        )

        let smart = BrowserSessionConfiguration(policy: .smart, source: .chrome, profile: "Profile 1")
        suite.expect(smart.cookieSpecification == "chrome:Profile 1", "browser profile specification")
        suite.expect(smart.shouldUseCookiesInitially(for: "https://www.douyin.com/video/123"), "Douyin uses session first")
        suite.expect(smart.shouldUseCookiesInitially(for: "https://www.bilibili.com/video/BV1xx411c7mD"), "Bilibili uses session first")
        suite.expect(!smart.shouldUseCookiesInitially(for: "https://www.youtube.com/watch?v=abc"), "YouTube starts without session")
        suite.expect(
            smart.shouldRefreshCookiesAndRetry(
                url: "https://www.douyin.com/video/7642521640303217972",
                processOutput: "ERROR: [Douyin] Fresh cookies (not necessarily logged in) are needed",
                alreadyUsedCookies: true
            ),
            "Douyin fresh-cookie failure gets one refreshed-session retry"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.douyin.com/video/7642521640303217972",
                processOutput: "ERROR: [Douyin] Fresh cookies (not necessarily logged in) are needed"
            ) == .verificationRequired,
            "classify Douyin fresh-cookie issue"
        )
        suite.expect(smart.shouldRetryWithCookies(
            url: "https://www.youtube.com/watch?v=abc",
            processOutput: "ERROR: Sign in to confirm you’re not a bot",
            alreadyUsedCookies: false
        ), "YouTube authentication retry")
        suite.expect(smart.shouldRetryWithCookies(
            url: "https://www.youtube.com/watch?v=abc",
            processOutput: "ERROR: unable to download video data: HTTP Error 403: Forbidden",
            alreadyUsedCookies: false
        ), "YouTube 403 retries once with browser session")
        suite.expect(!smart.shouldRetryWithCookies(
            url: "https://www.youtube.com/watch?v=abc",
            processOutput: "ERROR: network timeout",
            alreadyUsedCookies: false
        ), "no cookie retry for network errors")
        let signedDouyinMediaURL = "https://v26-web.douyinvod.com/video/tos/test.mp4?token=temporary"
        suite.expect(
            !DownloadSessionPlan.shouldUseCookiesInitially(
                directMediaURL: signedDouyinMediaURL,
                pageURL: "https://www.douyin.com/video/7577064036594097743",
                browserSession: smart
            ),
            "browser-resolved Douyin media never rereads browser cookies"
        )
        suite.expect(
            !DownloadSessionPlan.shouldRetryWithCookies(
                directMediaURL: signedDouyinMediaURL,
                pageURL: "https://www.douyin.com/video/7577064036594097743",
                processOutput: "ERROR: HTTP Error 403: Forbidden",
                alreadyUsedCookies: false,
                browserSession: smart
            ),
            "direct Douyin 403 never falls through to the page cookie extractor"
        )
        suite.expect(
            !DownloadSessionPlan.shouldRefreshCookiesAndRetry(
                directMediaURL: signedDouyinMediaURL,
                pageURL: "https://www.douyin.com/video/7577064036594097743",
                processOutput: "ERROR: [Douyin] Fresh cookies are needed",
                alreadyUsedCookies: true,
                browserSession: smart
            ),
            "direct Douyin failure never becomes a fresh-cookie retry"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.youtube.com/watch?v=abc",
                processOutput: "ERROR: HTTP Error 403: Forbidden"
            ) == .forbidden,
            "classify YouTube 403"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.youtube.com/watch?v=abc",
                processOutput: "ERROR: Sign in to confirm you’re not a bot"
            ) == .verificationRequired,
            "classify YouTube verification"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.youtube.com/watch?v=abc",
                processOutput: "ERROR: Could not copy Chrome cookie database"
            ) == .cookieAccess,
            "classify browser cookie access"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.youtube.com/watch?v=abc",
                processOutput: "ERROR: network timeout"
            ) == nil,
            "network error is not a session issue"
        )
        suite.expect(
            BrowserSessionRepairTarget.url(for: "https://www.douyin.com/video/7577064036594097743")?.absoluteString
                == "https://www.douyin.com/video/7577064036594097743",
            "Douyin session repair opens the failed video to refresh its cookies"
        )
        suite.expect(
            BrowserSessionRepairTarget.url(for: "https://www.youtube.com/watch?v=abc")?.absoluteString
                == "https://www.youtube.com/",
            "YouTube session repair opens YouTube"
        )
        suite.expect(
            BrowserSessionIssueClassifier.classify(
                url: "https://www.youtube.com/watch?v=abc",
                processOutput: "ERROR: Private video"
            ) == nil,
            "private video is not misclassified as a session issue"
        )

        let videoArguments = DownloadCommandBuilder.arguments(
            url: "https://www.youtube.com/watch?v=abc",
            folder: "/tmp/downloads",
            ffmpegPath: "/opt/homebrew/bin/ffmpeg",
            maximumHeight: 1080,
            kind: .video,
            cookieSpecification: "chrome:Default"
        )
        suite.expect(videoArguments.contains("--merge-output-format"), "video merge output")
        suite.expect(videoArguments.contains(where: { $0.contains("height<=1080") }), "height selector")
        suite.expect(videoArguments.contains(where: { $0.contains("progress.downloaded_bytes") }), "byte-based yt-dlp progress template")
        suite.expect(videoArguments.contains("--progress"), "force yt-dlp progress when app captures pipes")
        suite.expect(videoArguments.contains("0.2"), "throttle yt-dlp progress updates for menu UI")
        suite.expect(videoArguments.contains("--windows-filenames"), "download filenames remain portable across output volumes")
        suite.expect(
            Array(videoArguments.suffix(3)) == ["--cookies-from-browser", "chrome:Default", "https://www.youtube.com/watch?v=abc"],
            "cookie arguments"
        )
        suite.expect(videoArguments.contains("--continue") && videoArguments.contains("--part"), "downloads explicitly preserve resumable part files")
        let bilibiliArguments = DownloadCommandBuilder.arguments(
            url: "https://www.bilibili.com/video/BV162tN6WEBG",
            folder: "/tmp/downloads",
            ffmpegPath: "/opt/homebrew/bin/ffmpeg",
            maximumHeight: 1080,
            kind: .video,
            cookieSpecification: "chrome:Default",
            temporaryFolder: "/tmp/video-batch-cache/job-1",
            pluginDirectory: "/Applications/Video Batch Downloader.app/Contents/Resources"
        )
        suite.expect(bilibiliArguments.contains("10M"), "Bilibili uses bounded HTTP chunks to recover from CDN throttling")
        suite.expect(!bilibiliArguments.contains("--throttled-rate"), "Bilibili avoids yt-dlp's three-second throttle trigger")
        suite.expect(bilibiliArguments.contains("30"), "Bilibili tolerates more transient network failures")
        suite.expect(bilibiliArguments.contains("temp:/tmp/video-batch-cache/job-1"), "Bilibili part files use the stable card cache")
        suite.expect(bilibiliArguments.contains("--plugin-dirs") && bilibiliArguments.contains("/Applications/Video Batch Downloader.app/Contents/Resources"), "Bilibili loads the bundled CDN rotation plugin")
        var lowSpeedDetector = RollingLowSpeedDetector(
            thresholdBytesPerSecond: 500 * 1_024,
            requiredDuration: 60
        )
        let throttleStart = Date(timeIntervalSince1970: 1_000)
        suite.expect(!lowSpeedDetector.shouldRefresh(downloadedBytes: 0, now: throttleStart), "Bilibili rolling window starts without refreshing")
        suite.expect(!lowSpeedDetector.shouldRefresh(downloadedBytes: 20 * 1_024 * 1_024, now: throttleStart.addingTimeInterval(59)), "Bilibili does not refresh before a full rolling minute")
        suite.expect(lowSpeedDetector.shouldRefresh(downloadedBytes: 29 * 1_024 * 1_024, now: throttleStart.addingTimeInterval(60)), "Bilibili refreshes when the latest minute averages below 500 KB/s")
        var healthySpeedDetector = RollingLowSpeedDetector(thresholdBytesPerSecond: 500 * 1_024, requiredDuration: 60)
        suite.expect(!healthySpeedDetector.shouldRefresh(downloadedBytes: 0, now: throttleStart), "Bilibili healthy-speed window starts without refreshing")
        suite.expect(!healthySpeedDetector.shouldRefresh(downloadedBytes: 40 * 1_024 * 1_024, now: throttleStart.addingTimeInterval(60)), "Bilibili does not refresh above 500 KB/s")
        suite.expect(!healthySpeedDetector.shouldRefresh(downloadedBytes: 1 * 1_024 * 1_024, now: throttleStart.addingTimeInterval(61)), "Bilibili stream reset starts a new rolling window")
        let cacheJobID = UUID(uuidString: "729E32F5-E74C-4CB5-9EE9-29CCBDAFA51B")!
        let cacheDirectory = DownloadCachePolicy.directory(downloadFolder: "/tmp/downloads", jobID: cacheJobID)
        suite.expect(
            cacheDirectory.path == "/tmp/downloads/.VideoBatchDownloader-cache/729E32F5-E74C-4CB5-9EE9-29CCBDAFA51B",
            "download cache path remains stable across attempts"
        )
        suite.expect(
            DownloadCachePolicy.owns(directoryPath: cacheDirectory.path, jobID: cacheJobID),
            "download cache cleanup accepts the exact card directory"
        )
        suite.expect(
            !DownloadCachePolicy.owns(directoryPath: "/tmp/downloads/.VideoBatchDownloader-cache/other", jobID: cacheJobID),
            "download cache cleanup rejects unrelated directories"
        )
        suite.expect(
            URLNormalizer.trustedDouyinMediaURL(
                "https://v26-web.douyinvod.com/video/tos/test.mp4?token=temporary",
                pageURL: "https://www.douyin.com/video/7577064036594097743"
            ),
            "accept short-lived media from a trusted Douyin CDN"
        )
        suite.expect(
            !URLNormalizer.trustedDouyinMediaURL(
                "https://127.0.0.1/private",
                pageURL: "https://www.douyin.com/video/7577064036594097743"
            ),
            "reject an untrusted browser-resolved media URL"
        )
        let trustedFallbacks = URLNormalizer.trustedDouyinMediaURLs(
            [
                "https://v26-web.douyinvod.com/video/tos/alternate.mp4",
                "https://127.0.0.1/private",
                "https://v26-web.douyinvod.com/video/tos/alternate.mp4",
            ],
            legacyMediaURL: "https://v3-web.douyinvod.com/test.mp4",
            pageURL: "https://www.douyin.com/video/7577064036594097743"
        )
        suite.expect(trustedFallbacks.count == 2, "Douyin media fallbacks are trusted and deduplicated")
        suite.expect(trustedFallbacks.first?.contains("v3-web") == true, "legacy currentSrc remains the first Douyin candidate")
        let directDouyinArguments = DownloadCommandBuilder.arguments(
            url: "https://v26-web.douyinvod.com/video/tos/test.mp4?token=temporary",
            folder: "/tmp/downloads",
            ffmpegPath: "/opt/homebrew/bin/ffmpeg",
            maximumHeight: nil,
            kind: .video,
            cookieSpecification: "chrome:Default",
            refererURL: "https://www.douyin.com/video/7577064036594097743",
            browserResolvedTitle: "Frankfurt / Auto: Show 100%"
        )
        suite.expect(directDouyinArguments.contains("--force-generic-extractor"), "direct Douyin media bypasses the broken extractor")
        suite.expect(directDouyinArguments.contains("--remux-video"), "direct Douyin media is forced to a known MP4 container")
        suite.expect(directDouyinArguments.contains("before_dl:TARGET:%(filepath)s"), "direct output path is captured for failed-artifact cleanup")
        suite.expect(directDouyinArguments.contains("https://www.douyin.com/video/7577064036594097743"), "direct Douyin media keeps its page referer")
        suite.expect(directDouyinArguments.contains("Frankfurt - Auto- Show 100%%.%(ext)s"), "direct Douyin media uses a safe browser-resolved filename")
        suite.expect(
            DownloadFileNameTemplate.browserResolvedTitle("  First\n  second / clip  ") == "First second - clip",
            "browser-resolved title is normalized for display and filenames"
        )
        suite.expect(
            DownloadFileNameTemplate.browserResolvedTitle("A?B*C\"D<E>F|G\\H") == "A-B-C-D-E-F-G-H",
            "browser-resolved title removes every portable-filesystem reserved character"
        )
        let longUnicodeTitle = DownloadFileNameTemplate.browserResolvedTitle(String(repeating: "汽", count: 100))
        suite.expect(
            (longUnicodeTitle?.utf8.count ?? .max) <= 160,
            "browser-resolved title is bounded by UTF-8 bytes for APFS"
        )
        suite.expect(
            ProcessFailureSummary.lastUsefulLine(
                in: "ERROR: Postprocessing: Error opening output files: Invalid argument\nFILE:/tmp/title.unknown_video"
            ) == "ERROR: Postprocessing: Error opening output files: Invalid argument",
            "failure summary does not replace the real error with an output path"
        )
        let copiedErrorReport = DownloadErrorReport.text(
            appVersion: "2.2.18",
            build: "120",
            title: "Douyin video",
            url: "https://www.douyin.com/video/7607994058489866404",
            error: "Douyin CDN returned a non-video payload"
        )
        suite.expect(copiedErrorReport.contains("2.2.18 (120)"), "copied error report includes app version")
        suite.expect(copiedErrorReport.contains("URL: https://www.douyin.com/video/7607994058489866404"), "copied error report includes stable page URL")
        suite.expect(copiedErrorReport.contains("Error: Douyin CDN returned a non-video payload"), "copied error report includes the actionable error")
        suite.expect(
            DownloadedMediaValidation.isPlausibleVideo(fileSize: 1_881_961, probeStatus: 0, probeOutput: "video\n"),
            "a probed video stream is accepted"
        )
        suite.expect(
            !DownloadedMediaValidation.isPlausibleVideo(fileSize: 1_881_961, probeStatus: 0, probeOutput: "audio\n"),
            "an audio-only MP4 is rejected as a Douyin video"
        )
        suite.expect(
            !DownloadedMediaValidation.isPlausibleVideo(fileSize: 58, probeStatus: 0, probeOutput: "video\n"),
            "a tiny CDN error payload is rejected"
        )

        let temporaryArguments = DownloadCommandBuilder.arguments(
            url: "https://www.youtube.com/watch?v=abc",
            folder: "/tmp/downloads",
            ffmpegPath: "/opt/homebrew/bin/ffmpeg",
            maximumHeight: 1080,
            kind: .video,
            cookieSpecification: nil,
            temporaryFolder: "/tmp/video-batch/job-1"
        )
        suite.expect(
            temporaryArguments.contains("temp:/tmp/video-batch/job-1"),
            "keep incomplete yt-dlp files in the job temporary folder"
        )

        let audioArguments = DownloadCommandBuilder.arguments(
            url: "https://example.com/audio",
            folder: "/tmp/downloads",
            ffmpegPath: "/opt/homebrew/bin/ffmpeg",
            maximumHeight: nil,
            kind: .audio,
            cookieSpecification: nil
        )
        suite.expect(!audioArguments.contains("--merge-output-format"), "audio does not force MP4")
        suite.expect(
            audioArguments.contains(DownloadCommandBuilder.audioSelector),
            "audio selector prefers direct M4A before conversion"
        )

        suite.expect(
            ProgressProtocol.ytDlpProgress(from: "PROGRESS: 42.7%|3.2MiB/s|00:09") == DownloadProgress(percent: 42.7, speed: "3.2MiB/s", eta: "00:09"),
            "parse explicit yt-dlp progress template"
        )
        let byteProgress = ProgressProtocol.ytDlpProgress(from: "PROGRESS:1048576|4194304|NA|2.0MiB/s|00:02")
        suite.expect(
            byteProgress == DownloadProgress(percent: 25, speed: "2.0MiB/s", eta: "00:02", downloadedBytes: 1_048_576, totalBytes: 4_194_304),
            "parse byte-based yt-dlp progress template"
        )
        suite.expect(
            ProgressProtocol.ytDlpProgress(from: "PROGRESS:1048576|NA|NA|2.0MiB/s|00:02") == DownloadProgress(percent: nil, speed: "2.0MiB/s", eta: "00:02", downloadedBytes: 1_048_576, totalBytes: nil),
            "retain byte progress before yt-dlp knows total size"
        )
        suite.expect(
            ProgressProtocol.ytDlpProgress(from: "[download] 18.4% of 42.00MiB at 2.00MiB/s ETA 00:17")?.percent == 18.4,
            "parse standard yt-dlp percentage"
        )
        var twoStreamProgress = DownloadTransferProgressAccumulator(kind: .video)
        let firstStreamFinish = twoStreamProgress.fraction(for: DownloadProgress(percent: 100, speed: "", eta: ""))
        let secondStreamStart = twoStreamProgress.fraction(for: DownloadProgress(percent: 5, speed: "", eta: ""))
        suite.expect(firstStreamFinish == 0.5 && secondStreamStart == 0.525, "combine video and audio streams into monotonic job progress")
        suite.expect(
            ProgressProtocol.ffmpegElapsedSeconds(from: "out_time_us=12500000") == 12.5,
            "parse FFmpeg out_time_us progress"
        )
        suite.expect(
            ProgressProtocol.ffmpegElapsedSeconds(from: "out_time_ms=3250000") == 3.25,
            "parse FFmpeg out_time_ms progress"
        )
        suite.expect(
            ProgressProtocol.ffmpegElapsedSeconds(from: "time=00:01:02.500") == 62.5,
            "parse legacy FFmpeg time progress"
        )
        suite.expect(
            ProgressProtocol.fraction(elapsedSeconds: 12.5, durationSeconds: 50) == 0.25,
            "normalize elapsed progress"
        )

        suite.expect(LocalAPIOriginPolicy.isAllowed(nil), "allow local command-line clients")
        suite.expect(
            LocalAPIOriginPolicy.isAllowed("chrome-extension://maffkobeoconfcafkokibppjmbccdink"),
            "allow Chrome extension"
        )
        suite.expect(LocalAPIOriginPolicy.isAllowed("moz-extension://random-id"), "allow Firefox extension")
        suite.expect(!LocalAPIOriginPolicy.isAllowed("https://example.com"), "reject website origin")
        suite.expect(LocalAPIOriginPolicy.corsValue(for: "https://example.com") == nil, "no CORS for website")

        suite.expect(!DownloadQueueRetention.shouldRetain(.completed), "completed job leaves active queue")
        suite.expect(DownloadQueueRetention.shouldRetain(.failed), "failed job remains available for retry")
        suite.expect(DownloadQueueRetention.shouldRetain(.stopped), "stopped job remains available for retry")
        suite.expect(DownloadQueueRemoval.canRemove(.failed), "failed job can be removed explicitly")
        suite.expect(!DownloadQueueRemoval.canRemove(.queued), "queued job cannot be removed")
        suite.expect(!DownloadQueueRemoval.canRemove(.downloading), "active job cannot be removed")
        suite.expect(DownloadQueueRemoval.canRemove(.stopped), "stopped job can be removed explicitly")

        let availableFolders = Set(["/Volumes/Media", "/tmp/session-downloads"])
        suite.expect(
            DownloadFolderPolicy.effectiveFolder(
                configured: "/Volumes/Media",
                sessionOverride: nil,
                isAvailableDirectory: availableFolders.contains
            ) == "/Volumes/Media",
            "available configured folder is used on launch"
        )
        suite.expect(
            DownloadFolderPolicy.effectiveFolder(
                configured: "/Volumes/Missing",
                sessionOverride: "/tmp/session-downloads",
                isAvailableDirectory: availableFolders.contains
            ) == "/tmp/session-downloads",
            "session folder replaces an unavailable configured folder"
        )
        suite.expect(
            DownloadFolderPolicy.effectiveFolder(
                configured: "/Volumes/Media",
                sessionOverride: "/tmp/session-downloads",
                isAvailableDirectory: availableFolders.contains
            ) == "/tmp/session-downloads",
            "session override remains stable until relaunch"
        )
        suite.expect(
            DownloadFolderPolicy.effectiveFolder(
                configured: "/Volumes/Missing",
                sessionOverride: nil,
                isAvailableDirectory: availableFolders.contains
            ) == nil,
            "missing configured folder requests a session selection"
        )

        let now = Date(timeIntervalSince1970: 2_000_000)
        suite.expect(!SupportToolsUpdatePolicy.hasChangedTools(current: ["yt", "ff", "fp"], latest: ["yt", "ff", "fp"]), "matching bundled checksums do not prompt")
        suite.expect(SupportToolsUpdatePolicy.hasChangedTools(current: ["old", "ff", "fp"], latest: ["new", "ff", "fp"]), "changed yt-dlp prompts independently of media")
        suite.expect(SupportToolsUpdatePolicy.hasChangedTools(current: ["yt", "old", "fp"], latest: ["yt", "new", "fp"]), "changed FFmpeg prompts")
        suite.expect(SupportToolsUpdatePolicy.hasChangedTools(current: [nil, "ff", "fp"], latest: ["yt", "ff", "fp"]), "unknown provenance offers repair update")
        suite.expect(SupportToolsUpdatePolicy.shouldStart(enabled: true, forced: false, taskIsRunning: false, lastCheck: nil, now: now), "fresh installation checks immediately")
        suite.expect(
            SupportToolsUpdatePolicy.shouldStart(
                enabled: true,
                forced: false,
                taskIsRunning: false,
                lastCheck: now.addingTimeInterval(-SupportToolsUpdatePolicy.interval),
                now: now
            ),
            "support tools update starts after 24 hours"
        )
        suite.expect(
            !SupportToolsUpdatePolicy.shouldStart(
                enabled: true,
                forced: false,
                taskIsRunning: false,
                lastCheck: now.addingTimeInterval(-60),
                now: now
            ),
            "support tools update does not run early"
        )
        suite.expect(
            SupportToolsUpdatePolicy.shouldStart(
                enabled: false,
                forced: true,
                taskIsRunning: false,
                lastCheck: now,
                now: now
            ),
            "manual support tools update bypasses interval"
        )
        suite.expect(
            !SupportToolsUpdatePolicy.shouldStart(
                enabled: true,
                forced: true,
                taskIsRunning: true,
                lastCheck: nil,
                now: now
            ),
            "support tools update cannot start twice"
        )

        let historySuiteName = "VideoBatchDownloader.CoreTests.\(UUID().uuidString)"
        guard let historyDefaults = UserDefaults(suiteName: historySuiteName) else {
            throw TestFailure(count: 1)
        }
        defer { historyDefaults.removePersistentDomain(forName: historySuiteName) }
        let historyStore = DownloadHistoryStore(defaults: historyDefaults, maximumItems: 2)
        let firstHistoryItem = DownloadHistoryItem(
            id: UUID(),
            originalURL: "https://youtu.be/one",
            normalizedURL: "https://www.youtube.com/watch?v=one",
            maximumHeight: 1080,
            kind: .video,
            title: "One",
            filePath: "/tmp/one.mp4",
            completedAt: now.addingTimeInterval(-10)
        )
        let replacementHistoryItem = DownloadHistoryItem(
            id: UUID(),
            originalURL: "https://youtu.be/one",
            normalizedURL: firstHistoryItem.normalizedURL,
            maximumHeight: 1080,
            kind: .video,
            title: "One replacement",
            filePath: "/tmp/one-new.mp4",
            completedAt: now
        )
        var storedHistory = historyStore.recording(firstHistoryItem, in: [])
        storedHistory = historyStore.recording(replacementHistoryItem, in: storedHistory)
        suite.expect(storedHistory.count == 1, "history replaces matching download identity")
        suite.expect(storedHistory.first?.filePath == "/tmp/one-new.mp4", "history keeps newest matching file")
        suite.expect(historyStore.load() == storedHistory, "history store round trip")
        suite.expect(historyStore.removing(id: replacementHistoryItem.id, from: storedHistory).isEmpty, "history removes one item")
        suite.expect(historyStore.clear().isEmpty && historyStore.load().isEmpty, "history clears persisted state")

        let cutInput = URL(fileURLWithPath: "/tmp/source.mov")
        let cutOutput = URL(fileURLWithPath: "/tmp/source_segments", isDirectory: true)
        let fastCut = try MediaToolCommandBuilder.videoCut(
            input: cutInput,
            outputDirectory: cutOutput,
            seconds: 8,
            mode: .fastCopy,
            filenamePrefix: "source"
        )
        suite.expect(fastCut.arguments.contains("copy"), "fast cutter preserves source streams")
        suite.expect(fastCut.arguments.contains("0"), "cutter uses hidden temporary numbering")
        let preciseCut = try MediaToolCommandBuilder.videoCut(
            input: cutInput,
            outputDirectory: cutOutput,
            seconds: 5,
            mode: .precise,
            filenamePrefix: "source"
        )
        suite.expect(preciseCut.arguments.contains("h264_videotoolbox"), "precise cutter uses Apple GPU")

        let mp3Output = URL(fileURLWithPath: "/tmp/source-mp3-320.mp3")
        let mp3Command = MediaToolCommandBuilder.conversion(
            input: cutInput,
            preset: .audioMP3,
            outputURL: mp3Output
        )
        suite.expect(mp3Command.arguments.contains("320k"), "converter MP3 preset uses 320 kbps")

        let masteredAudio = MediaToolCommandBuilder.audioMastering(
            input: URL(fileURLWithPath: "/tmp/voice.wav"),
            outputURL: URL(fileURLWithPath: "/tmp/voice-audio-mastered.wav"),
            containsVideo: false
        )
        suite.expect(masteredAudio.arguments.contains(MediaToolCommandBuilder.masteringFilter), "audio mastering uses stable filter")
        let masteredVideo = MediaToolCommandBuilder.audioMastering(
            input: cutInput,
            outputURL: URL(fileURLWithPath: "/tmp/source-audio-mastered.mp4"),
            containsVideo: true
        )
        suite.expect(masteredVideo.arguments.contains("copy"), "video mastering preserves video stream")
        suite.expect(
            MediaFilePolicy.outputDescriptor(for: .imagePNG).extension == "png",
            "PNG conversion output descriptor"
        )
        let uniqueOutput = MediaFilePolicy.uniqueOutputURL(
            for: URL(fileURLWithPath: "/tmp/photo.heic"),
            suffix: "-jpg",
            extension: "jpg",
            fileExists: { $0 == "/tmp/photo-jpg.jpg" }
        )
        suite.expect(uniqueOutput.path == "/tmp/photo-jpg-1.jpg", "media tools avoid overwriting outputs")
        suite.expect(MediaFilePolicy.inputKind(for: URL(fileURLWithPath: "/tmp/movie.mov")) == .video, "media tools classify video inputs")
        suite.expect(MediaFilePolicy.inputKind(for: URL(fileURLWithPath: "/tmp/voice.mp3")) == .audio, "media tools classify audio inputs")
        suite.expect(MediaFilePolicy.inputKind(for: URL(fileURLWithPath: "/tmp/photo.webp")) == .image, "media tools classify image inputs")
        suite.expect(MediaInputKind.image.compatiblePresets == [.imageJPG, .imagePNG], "images expose only image conversions")
        suite.expect(MediaInputKind.audio.compatiblePresets == [.audioMP3], "audio exposes only audio conversion")
        suite.expect(FinderQuickActionKind.cutVideo.accepts(URL(fileURLWithPath: "/tmp/movie.mov")), "Finder cutter accepts video")
        suite.expect(!FinderQuickActionKind.cutVideo.accepts(URL(fileURLWithPath: "/tmp/voice.mp3")), "Finder cutter rejects audio")
        suite.expect(FinderQuickActionKind.convertMedia.accepts(URL(fileURLWithPath: "/tmp/photo.png")), "Finder converter accepts images")
        suite.expect(FinderQuickActionKind.masterAudio.accepts(URL(fileURLWithPath: "/tmp/voice.wav")), "Finder mastering accepts audio")
        suite.expect(FinderQuickActionKind.masterAudio.accepts(URL(fileURLWithPath: "/tmp/movie.mp4")), "Finder mastering accepts video")
        suite.expect(!FinderQuickActionKind.masterAudio.accepts(URL(fileURLWithPath: "/tmp/photo.jpg")), "Finder mastering rejects images")
        let segmentPlan = SegmentRenamePlan(
            outputDirectory: cutOutput,
            temporaryPrefix: ".test",
            filenamePrefix: "source",
            arrangement: .sequential
        )
        suite.expect(segmentPlan.filename(for: 0, totalSegments: 3) == "source_0001_A", "cutter starts with A")
        let unnamedSegmentPlan = SegmentRenamePlan(
            outputDirectory: cutOutput,
            temporaryPrefix: ".test-unnamed",
            filenamePrefix: "",
            arrangement: .sequential
        )
        suite.expect(unnamedSegmentPlan.filename(for: 0, totalSegments: 1) == "0001_A", "cutter omits leading separator without a prefix")
        suite.expect(segmentPlan.filename(for: 25, totalSegments: 27) == "source_0026_A", "single-video cutter keeps source suffix A")
        suite.expect(segmentPlan.filename(for: 26, totalSegments: 27) == "source_0027_A", "single-video cutter keeps source suffix A after Z")
        let creativeRandomPlan = SegmentRenamePlan(
            outputDirectory: cutOutput,
            temporaryPrefix: ".test-random",
            filenamePrefix: "source",
            arrangement: .creativeRandom
        )
        suite.expect(creativeRandomPlan.filename(for: 0, totalSegments: 3) == "source_0001_A", "random cutter keeps stable output numbering after shuffle")
        let batchRenamePlan = BatchSegmentRenamePlan(
            outputDirectory: cutOutput,
            sources: [BatchSegmentSource(temporaryPrefix: ".alpha", sourceIndex: 0), BatchSegmentSource(temporaryPrefix: ".beta", sourceIndex: 1)],
            arrangement: .sequential
        )
        suite.expect(batchRenamePlan.fileName(for: 0, sourceIndex: 0) == "0001_A", "batch timeline marks first video as A")
        suite.expect(batchRenamePlan.fileName(for: 1, sourceIndex: 1) == "0002_B", "batch timeline marks second video as B")
        let batchPlan = VideoCutBatchPlan(
            inputs: [
                URL(fileURLWithPath: "/tmp/alpha.mov"),
                URL(fileURLWithPath: "/tmp/beta.mov"),
            ],
            outputRoot: URL(fileURLWithPath: "/tmp/batch-output", isDirectory: true)
        )
        suite.expect(batchPlan.outputDirectory(for: URL(fileURLWithPath: "/tmp/alpha.mov")).path == "/tmp/batch-output", "batch cutter uses one shared timeline folder")
        suite.expect(batchPlan.outputDirectory(for: URL(fileURLWithPath: "/tmp/beta.mov")).path == "/tmp/batch-output", "batch cutter interleaves all sources in the shared folder")
        suite.expect(batchPlan.filenamePrefix(for: URL(fileURLWithPath: "/tmp/beta.mov"), requestedPrefix: "shared") == "beta", "batch cutter uses source names to avoid collisions")

        let legacy = try JSONDecoder().decode(
            EnqueueRequest.self,
            from: Data(#"{"urls":["https://youtu.be/abc"]}"#.utf8)
        )
        suite.expect(legacy.items.count == 1 && legacy.items[0].kind == .video, "legacy queue request")
        let typed = try JSONDecoder().decode(
            EnqueueRequest.self,
            from: Data(#"{"items":[{"url":"https://example.com/image.jpg","maxHeight":null,"kind":"image"}]}"#.utf8)
        )
        suite.expect(typed.items.first?.kind == .image, "typed queue request")
        let browserResolved = try JSONDecoder().decode(
            EnqueueRequest.self,
            from: Data(#"{"items":[{"url":"https://www.douyin.com/video/123","mediaURL":"https://v3-web.douyinvod.com/test.mp4","mediaURLs":["https://v3-web.douyinvod.com/test.mp4","https://v26-web.douyinvod.com/alternate.mp4"],"title":"Real Douyin title","maxHeight":null,"kind":"video"}]}"#.utf8)
        )
        suite.expect(browserResolved.items.first?.mediaURL?.contains("douyinvod.com") == true, "browser-resolved media request")
        suite.expect(browserResolved.items.first?.mediaURLs?.count == 2, "browser-resolved media fallback request")
        suite.expect(browserResolved.items.first?.title == "Real Douyin title", "browser-resolved title request")
        suite.expect(browserResolved.items.first?.browserResolutionAttempted == false, "older browser request defaults to no resolution attempt")
        let attemptedResolution = try JSONDecoder().decode(
            EnqueueRequest.self,
            from: Data(#"{"items":[{"url":"https://www.douyin.com/video/7688724747735141678","browserResolutionAttempted":true,"maxHeight":null}]}"#.utf8)
        )
        suite.expect(attemptedResolution.items.first?.browserResolutionAttempted == true, "floating Douyin request reports a browser resolution attempt")
        let diagnosedResolution = try JSONDecoder().decode(
            EnqueueRequest.self,
            from: Data(#"{"items":[{"url":"https://www.douyin.com/video/7688724747735141678","browserResolutionAttempted":true,"browserResolutionDetail":"player-blob;state-absent;api-empty;html-no-match"}]}"#.utf8)
        )
        suite.expect(
            diagnosedResolution.items.first?.browserResolutionDetail == "player-blob;state-absent;api-empty;html-no-match",
            "safe Douyin browser diagnostics cross the local bridge"
        )
        suite.expect(BrowserResolutionDetail.safe("cookie=secret") == nil, "browser diagnosis rejects sensitive freeform text")
        suite.expect(BrowserResolutionDetail.safe(String(repeating: "a", count: 97)) == nil, "browser diagnosis is length bounded")

        if suite.failures.isEmpty {
            print("Swift core tests: \(suite.assertions) passed")
        } else {
            let report = suite.failures.map { "FAIL: \($0)" }.joined(separator: "\n") + "\n"
            FileHandle.standardOutput.write(Data(report.utf8))
            throw TestFailure(count: suite.failures.count)
        }
    }
}

private struct TestFailure: Error {
    let count: Int
}
