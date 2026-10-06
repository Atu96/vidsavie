import AppKit
import Foundation

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var jobs: [DownloadJob] = []
    @Published private(set) var history: [DownloadHistoryItem] = []
    @Published private(set) var serverMessage = "Starting local connection…"
    @Published private(set) var unseenCompletedCount = 0
    @Published private(set) var latestCompletedTitle: String?
    @Published private(set) var latestCompletedPath: String?
    @Published private(set) var sessionDownloadFolder: String?
    @Published var downloadFolder: String {
        didSet { UserDefaults.standard.set(downloadFolder, forKey: Self.folderKey) }
    }
    @Published var extensionEnabled = AppPreferences.bool(PreferenceKeys.extensionEnabled, default: true) {
        didSet { UserDefaults.standard.set(extensionEnabled, forKey: PreferenceKeys.extensionEnabled) }
    }
    @Published var showOverlay = AppPreferences.bool(PreferenceKeys.showOverlay, default: true) {
        didSet { UserDefaults.standard.set(showOverlay, forKey: PreferenceKeys.showOverlay) }
    }
    @Published var defaultQuality = AppPreferences.string(PreferenceKeys.defaultQuality, default: "best") {
        didSet { UserDefaults.standard.set(defaultQuality, forKey: PreferenceKeys.defaultQuality) }
    }
    @Published var defaultDownloadKind = DownloadKind(
        rawValue: AppPreferences.string(PreferenceKeys.defaultDownloadKind, default: DownloadKind.video.rawValue)
    ) ?? .video {
        didSet { UserDefaults.standard.set(defaultDownloadKind.rawValue, forKey: PreferenceKeys.defaultDownloadKind) }
    }
    @Published var interfaceLanguage = AppPreferences.language(UserDefaults.standard.string(forKey: PreferenceKeys.interfaceLanguage)) {
        didSet { UserDefaults.standard.set(interfaceLanguage, forKey: PreferenceKeys.interfaceLanguage) }
    }
    @Published var visualTheme = AppPreferences.theme(UserDefaults.standard.string(forKey: PreferenceKeys.visualTheme)) {
        didSet { UserDefaults.standard.set(visualTheme, forKey: PreferenceKeys.visualTheme) }
    }
    @Published var browserCookiePolicy = BrowserCookiePolicy(
        rawValue: AppPreferences.string(PreferenceKeys.browserCookiePolicy, default: BrowserCookiePolicy.smart.rawValue)
    ) ?? .smart {
        didSet { UserDefaults.standard.set(browserCookiePolicy.rawValue, forKey: PreferenceKeys.browserCookiePolicy) }
    }
    @Published var browserCookieSource = BrowserCookieSource(
        rawValue: AppPreferences.string(PreferenceKeys.browserCookieSource, default: BrowserCookieSource.chrome.rawValue)
    ) ?? .chrome {
        didSet { UserDefaults.standard.set(browserCookieSource.rawValue, forKey: PreferenceKeys.browserCookieSource) }
    }
    @Published var browserCookieProfile = AppPreferences.string(PreferenceKeys.browserCookieProfile, default: "") {
        didSet { UserDefaults.standard.set(browserCookieProfile, forKey: PreferenceKeys.browserCookieProfile) }
    }
    @Published private(set) var supportToolsStatus = ""
    @Published private(set) var isUpdatingSupportTools = false
    @Published private(set) var supportToolsInstalled = SupportToolsInstaller.hasAvailableTools()
    @Published private(set) var supportToolsInstallPhase: SupportToolsInstallPhase?
    @Published private(set) var supportToolsLastUpdateFailed = false
    @Published private(set) var browserSessionStatus = ""
    @Published private(set) var isTestingBrowserSession = false
    @Published private(set) var isReceivingLink = false

    let maximumConcurrentDownloads = 1

    private static let folderKey = "DownloadFolder"
    private static let lastSupportToolsUpdateCheckKey = "LastSupportToolsUpdateCheck"
    private let engine = DownloadEngine()
    private let supportToolsInstaller = SupportToolsInstaller()
    private let historyStore = DownloadHistoryStore()
    private let gpuQueue = AsyncSemaphore(value: 1)
    private var server: LocalHTTPServer?
    private var supportToolsUpdateTask: Task<Void, Never>?
    private var supportToolsMaintenanceTask: Task<Void, Never>?

    init() {
        // Engine maintenance is always enabled. Remove the retired switch
        // preference so an older saved `false` value cannot disable updates.
        UserDefaults.standard.removeObject(forKey: PreferenceKeys.autoUpdateYtDlp)
        // Migration also removes a stale retired theme before the extension can sync it back.
        let normalizedTheme = AppPreferences.theme(UserDefaults.standard.string(forKey: PreferenceKeys.visualTheme))
        if UserDefaults.standard.string(forKey: PreferenceKeys.visualTheme) != normalizedTheme {
            UserDefaults.standard.set(normalizedTheme, forKey: PreferenceKeys.visualTheme)
            visualTheme = normalizedTheme
        }
        if let saved = UserDefaults.standard.string(forKey: Self.folderKey), !saved.isEmpty {
            downloadFolder = saved
        } else if FileManager.default.fileExists(atPath: "/Volumes/SDATA/GEMST/GO") {
            downloadFolder = "/Volumes/SDATA/GEMST/GO"
        } else {
            downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                ?? NSHomeDirectory() + "/Downloads"
        }
        history = historyStore.load()
        NotificationCoordinator.shared.onSessionRepairRequested = { [weak self] jobID in
            Task { @MainActor [weak self] in
                self?.presentSessionRepair(jobID: jobID)
            }
        }
    }

    var activeCount: Int { jobs.filter { $0.status.isActive }.count }
    var queuedCount: Int { jobs.filter { $0.status == .queued }.count }
    var completedCount: Int { history.count }

    func startServer() {
        guard server == nil else { return }
        let newServer = LocalHTTPServer(
            onEnqueue: { [weak self] items in Task { @MainActor in self?.enqueue(items) } },
            onPreferences: { [weak self] update in Task { @MainActor in self?.applyPreferences(update) } }
        )
        server = newServer
        do {
            try newServer.start()
            serverMessage = "Chrome connected on this Mac"
            if supportToolsInstalled { scheduleSupportToolsUpdate() }
            startSupportToolsMaintenanceLoop()
        } catch {
            serverMessage = "Local connection error: \(error.localizedDescription)"
        }
    }

    private func startSupportToolsMaintenanceLoop() {
        guard supportToolsMaintenanceTask == nil else { return }
        supportToolsMaintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 * 60))
                guard !Task.isCancelled, let self else { return }
                self.scheduleSupportToolsUpdate()
            }
        }
    }

    func scheduleSupportToolsUpdate(force: Bool = false) {
        guard force || supportToolsInstalled else {
            refreshSupportToolsState()
            return
        }
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastSupportToolsUpdateCheckKey) as? Date
        let shouldUpdate = SupportToolsUpdatePolicy.shouldStart(
            enabled: true,
            forced: force,
            taskIsRunning: supportToolsUpdateTask != nil,
            lastCheck: lastCheck
        )
        guard shouldUpdate else {
            refreshSupportToolsState()
            return
        }

        isUpdatingSupportTools = true
        supportToolsLastUpdateFailed = false
        supportToolsInstallPhase = .checking
        supportToolsStatus = ""
        supportToolsUpdateTask = Task { [weak self] in
            guard let self else { return }
            do {
                if force {
                    let snapshot = try await supportToolsInstaller.installOrUpdate { [weak self] phase in
                        Task { @MainActor [weak self] in self?.supportToolsInstallPhase = phase }
                    }
                    supportToolsInstalled = true
                    supportToolsStatus = snapshot.displayText
                } else if try await supportToolsInstaller.updateIsAvailable() {
                    // Release the task state before offering the explicit user action.
                    supportToolsInstallPhase = nil
                    isUpdatingSupportTools = false
                    supportToolsUpdateTask = nil
                    UserDefaults.standard.set(Date(), forKey: Self.lastSupportToolsUpdateCheckKey)
                    presentSupportToolsUpdatePrompt()
                    return
                }
                UserDefaults.standard.set(Date(), forKey: Self.lastSupportToolsUpdateCheckKey)
            } catch {
                supportToolsLastUpdateFailed = true
                supportToolsStatus = error.localizedDescription
                UserDefaults.standard.set(
                    SupportToolsUpdatePolicy.retryDateAfterFailure(),
                    forKey: Self.lastSupportToolsUpdateCheckKey
                )
            }
            supportToolsInstallPhase = nil
            isUpdatingSupportTools = false
            supportToolsUpdateTask = nil
        }
    }

    private func refreshSupportToolsState() {
        guard supportToolsUpdateTask == nil else { return }
        supportToolsInstalled = SupportToolsInstaller.hasAvailableTools()
        guard supportToolsInstalled, supportToolsStatus.isEmpty else { return }
        supportToolsUpdateTask = Task { [weak self] in
            guard let self else { return }
            if let snapshot = await supportToolsInstaller.installedSnapshot() {
                supportToolsStatus = snapshot.displayText
            }
            supportToolsUpdateTask = nil
        }
    }

    private func presentSupportToolsUpdatePrompt() {
        let language = interfaceLanguage
        let copy = SupportToolsPromptCopy.text(language: language)
        let alert = NSAlert()
        alert.messageText = copy.title
        alert.informativeText = copy.detail
        alert.addButton(withTitle: AppText.value("updateSupportTools", language: language, fallback: "Update tools"))
        alert.addButton(withTitle: copy.later)
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        alert.layout()
        alert.buttons[1].keyEquivalent = "\u{1b}"
        alert.window.defaultButtonCell = alert.buttons[1].cell as? NSButtonCell
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { scheduleSupportToolsUpdate(force: true) }
    }

    func testBrowserSession() {
        guard !isTestingBrowserSession else { return }
        isTestingBrowserSession = true
        browserSessionStatus = ""
        let configuration = browserSessionConfiguration
        Task { [weak self] in
            guard let self else { return }
            do {
                let browserName = try await engine.testBrowserSession(configuration)
                browserSessionStatus = "\(browserName) · session ready"
            } catch {
                browserSessionStatus = error.localizedDescription
            }
            isTestingBrowserSession = false
        }
    }

    func applyPreferences(_ update: PreferencesUpdate) {
        if let value = update.enabled { extensionEnabled = value }
        if let value = update.showOverlay { showOverlay = value }
        if let value = update.defaultQuality, ["best", "1080", "720", "480"].contains(value) { defaultQuality = value }
        if let value = update.language, ["auto", "en", "vi", "zh", "es", "fr", "de", "pt", "ja", "ko"].contains(value) { interfaceLanguage = value }
        if let value = update.theme { visualTheme = AppPreferences.theme(value) }
    }

    @discardableResult
    func enqueue(_ urls: [String]) -> Int {
        enqueue(urls.map { EnqueueItem(url: $0, maxHeight: nil) })
    }

    @discardableResult
    func enqueue(_ items: [EnqueueItem]) -> Int {
        let existing = Set(jobs.filter { $0.status == .queued || $0.status.isActive }.map {
            "\($0.normalizedURL)|\($0.kind.rawValue)|\($0.maximumHeight.map(String.init) ?? "best")"
        })
        var seen = existing
        var added = 0

        for item in items {
            let normalized = URLNormalizer.normalize(item.url)
            let key = "\(normalized)|\(item.kind.rawValue)|\(item.maxHeight.map(String.init) ?? "best")"
            guard URLNormalizer.isSupported(normalized), !seen.contains(key) else { continue }
            seen.insert(key)
            let trustedMediaURLs = URLNormalizer.trustedDouyinMediaURLs(
                item.mediaURLs ?? [],
                legacyMediaURL: item.mediaURL,
                pageURL: normalized
            )
            jobs.append(DownloadJob(
                url: item.url,
                mediaURLs: trustedMediaURLs,
                browserResolvedTitle: trustedMediaURLs.isEmpty ? nil : item.title,
                browserResolutionAttempted: item.browserResolutionAttempted,
                browserResolutionDetail: trustedMediaURLs.isEmpty && (item.mediaURL != nil || !(item.mediaURLs ?? []).isEmpty)
                    ? "source-rejected" : item.browserResolutionDetail,
                maximumHeight: item.maxHeight,
                kind: item.kind
            ))
            added += 1
        }
        scheduleDownloads()
        if added > 0 {
            isReceivingLink = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.isReceivingLink = false
            }
        }
        return added
    }

    func stop(_ job: DownloadJob) {
        guard job.status == .queued || job.status.isActive else { return }
        job.status = .stopped
        job.process?.terminate()
        job.process = nil
        scheduleDownloads()
    }

    func retry(_ job: DownloadJob) {
        guard job.status == .failed || job.status == .stopped else { return }
        job.status = .queued
        job.progress = 0
        job.speed = ""
        job.eta = ""
        job.downloadedBytes = nil
        job.totalBytes = nil
        job.resetTransferProgress()
        job.errorMessage = nil
        job.browserSessionIssue = nil
        job.filePath = nil
        scheduleDownloads()
    }

    @discardableResult
    func copyLink(_ job: DownloadJob) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(job.normalizedURL, forType: .string)
    }

    @discardableResult
    func copyErrorReport(_ job: DownloadJob) -> Bool {
        guard let error = job.errorMessage, !error.isEmpty else { return false }
        let info = Bundle.main.infoDictionary
        let report = DownloadErrorReport.text(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            build: info?["CFBundleVersion"] as? String ?? "unknown",
            title: job.title,
            url: job.normalizedURL,
            error: error
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(report, forType: .string)
    }

    func removeRetryableJob(_ job: DownloadJob) {
        guard DownloadQueueRemoval.canRemove(job.status) else { return }
        removeDownloadCache(for: job)
        jobs.removeAll { $0.id == job.id }
    }

    func hasResumableCache(for job: DownloadJob) -> Bool {
        guard let path = job.temporaryDirectoryPath,
              DownloadCachePolicy.owns(directoryPath: path, jobID: job.id),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: path)
        else { return false }
        return !contents.isEmpty
    }

    func presentSessionRepair(_ job: DownloadJob) {
        guard job.status == .failed, job.browserSessionIssue != nil else { return }
        SessionRepairCoordinator.shared.show(manager: self, job: job)
    }

    func openSelectedBrowserForSessionRepair(failedURL: String) {
        let browserPath = switch browserCookieSource {
        case .chrome: "/Applications/Google Chrome.app"
        case .brave: "/Applications/Brave Browser.app"
        case .edge: "/Applications/Microsoft Edge.app"
        case .firefox: "/Applications/Firefox.app"
        }
        guard let page = BrowserSessionRepairTarget.url(for: failedURL) else { return }
        let appURL = URL(fileURLWithPath: browserPath)
        guard FileManager.default.fileExists(atPath: browserPath) else {
            NSWorkspace.shared.open(page)
            return
        }
        NSWorkspace.shared.open(
            [page],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func historyFileExists(_ item: DownloadHistoryItem) -> Bool {
        FileManager.default.fileExists(atPath: item.filePath)
    }

    func openHistoryItem(_ item: DownloadHistoryItem) {
        guard historyFileExists(item) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath))
    }

    func revealHistoryItem(_ item: DownloadHistoryItem) {
        guard historyFileExists(item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.filePath)])
    }

    func redownload(_ item: DownloadHistoryItem) {
        _ = enqueue([EnqueueItem(url: item.originalURL, maxHeight: item.maximumHeight, kind: item.kind)])
    }

    func removeHistoryItem(_ item: DownloadHistoryItem) {
        history = historyStore.removing(id: item.id, from: history)
    }

    func clearHistory() {
        history = historyStore.clear()
    }

    func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: downloadFolder)
        if panel.runModal() == .OK, let selected = panel.url?.path {
            sessionDownloadFolder = nil
            downloadFolder = selected
        }
    }

    func reveal(_ job: DownloadJob) {
        guard let path = job.filePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func open(_ job: DownloadJob) {
        guard let path = job.filePath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openLatestCompleted() {
        guard let path = latestCompletedPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func revealLatestCompleted() {
        guard let path = latestCompletedPath else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            clearMissingLatestCompleted()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func refreshLatestCompletedFile() {
        guard let path = latestCompletedPath else { return }
        guard !FileManager.default.fileExists(atPath: path) else { return }
        clearMissingLatestCompleted()
    }

    private func clearMissingLatestCompleted() {
        latestCompletedPath = nil
        latestCompletedTitle = nil
    }

    func markCompletionsSeen() {
        unseenCompletedCount = 0
    }

    func openDownloadFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: sessionDownloadFolder ?? downloadFolder))
    }

    func installChromeCompanion() {
        CompanionInstaller.open(
            browserPath: "/Applications/Google Chrome.app",
            setupURL: "chrome://extensions/"
        )
    }

    func installFirefoxCompanion() {
        CompanionInstaller.open(
            browserPath: "/Applications/Firefox.app",
            setupURL: "about:debugging#/runtime/this-firefox"
        )
    }

    private func scheduleDownloads() {
        var available = maximumConcurrentDownloads - activeCount
        guard available > 0 else { return }

        for job in jobs where job.status == .queued {
            guard available > 0 else { break }
            job.status = .fetching
            available -= 1
            Task { await run(job) }
        }
    }

    private func run(_ job: DownloadJob) async {
        guard let targetFolder = resolveDownloadFolderForCurrentSession() else {
            job.status = .stopped
            job.errorMessage = nil
            scheduleDownloads()
            return
        }

        // Every card gets one stable private cache directory. Failed/stopped
        // yt-dlp .part files stay here so Retry can issue a Range request and
        // continue instead of starting a long download from byte zero.
        let temporaryDirectory: URL
        var downloadStageCompleted = false
        do {
            temporaryDirectory = try prepareTemporaryDirectory(for: job, in: targetFolder)
            job.temporaryDirectoryPath = temporaryDirectory.path
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            scheduleDownloads()
            return
        }
        defer {
            if downloadStageCompleted {
                removeDownloadCache(for: job, expectedPath: temporaryDirectory.path)
            }
        }

        do {
            let filePath = try await engine.download(
                url: job.normalizedURL,
                directMediaURLs: job.mediaURLs,
                browserResolvedTitle: job.browserResolvedTitle,
                folder: targetFolder,
                temporaryFolder: temporaryDirectory.path,
                maximumHeight: job.maximumHeight,
                kind: job.kind,
                browserSession: browserSessionConfiguration,
                onProcess: { process in
                    Task { @MainActor in
                        if job.status == .stopped { process.terminate() } else { job.process = process }
                    }
                },
                onTitle: { title in
                    Task { @MainActor in
                        guard job.browserResolvedTitle == nil else { return }
                        let detail = switch job.kind {
                        case .audio: " · Audio"
                        case .image: " · Original image"
                        case .video: job.maximumHeight.map { " · up to \($0)p" } ?? ""
                        }
                        job.title = title + detail
                    }
                },
                onProgress: { progress in
                    Task { @MainActor in
                        guard job.status != .stopped else { return }
                        job.status = .downloading
                        job.speed = progress.speed
                        job.eta = progress.eta
                        job.downloadedBytes = progress.downloadedBytes
                        job.totalBytes = progress.totalBytes
                        if let fraction = job.transferProgress.fraction(for: progress) {
                            job.progress = fraction
                        }
                    }
                }
            )
            downloadStageCompleted = true
            job.process = nil
            job.filePath = filePath
            guard job.status != .stopped else { throw CancellationError() }

            if job.kind == .audio, engine.needsAudioConversion(filePath) {
                job.status = .convertingAudio
                let convertedPath = try await engine.convertToMP3(filePath) { process in
                    Task { @MainActor in
                        if job.status == .stopped { process.terminate() } else { job.process = process }
                    }
                }
                job.filePath = convertedPath
            } else if job.kind == .video, try await engine.needsConversion(filePath) {
                job.status = .waitingForGPU
                await gpuQueue.wait()
                do {
                    guard job.status != .stopped else { throw CancellationError() }
                    job.status = .converting
                    let convertedPath = try await engine.convertToCompatibleMP4(filePath) { process in
                        Task { @MainActor in
                            if job.status == .stopped { process.terminate() } else { job.process = process }
                        }
                    }
                    await gpuQueue.signal()
                    job.filePath = convertedPath
                } catch {
                    await gpuQueue.signal()
                    throw error
                }
            }

            guard job.status != .stopped else { throw CancellationError() }
            job.process = nil
            job.progress = 1
            job.status = .completed
            latestCompletedTitle = job.title
            latestCompletedPath = job.filePath
            unseenCompletedCount += 1
            if let filePath = job.filePath {
                NotificationCoordinator.shared.notifyDownloadCompleted(title: job.title, filePath: filePath)
                recordCompletion(job, filePath: filePath)
            }
            if !DownloadQueueRetention.shouldRetain(job.status) {
                jobs.removeAll { $0.id == job.id }
            }
        } catch {
            job.process = nil
            removeIncompleteOutput(for: job, expectedFolder: targetFolder)
            if job.status != .stopped {
                job.status = .failed
                let fallbackError = error.localizedDescription
                let errorText: String
                if job.browserResolutionAttempted && URLNormalizer.isDouyin(job.normalizedURL) && job.mediaURLs.isEmpty {
                    let explanation = AppText.value(
                        "douyinDirectSourceUnavailable",
                        language: interfaceLanguage,
                        fallback: "The browser could not provide a verified source for this Douyin video. yt-dlp fallback:"
                    )
                    let detail = job.browserResolutionDetail.map { " [\($0)]" } ?? ""
                    errorText = "\(explanation)\(detail) \(fallbackError)"
                } else {
                    errorText = fallbackError
                }
                job.errorMessage = errorText
                let sessionIssue = BrowserSessionIssueClassifier.classify(
                    url: job.normalizedURL,
                    processOutput: errorText
                )
                job.browserSessionIssue = sessionIssue
                if sessionIssue != nil {
                    let title = AppText.value(
                        "sessionNeedsAttention",
                        language: interfaceLanguage,
                        fallback: "Browser session needs attention"
                    )
                    let body = AppText.value(
                        "sessionNeedsAttentionDetail",
                        language: interfaceLanguage,
                        fallback: "Check the browser profile, refresh your sign-in, then retry."
                    )
                    NotificationCoordinator.shared.notifyBrowserSessionIssue(
                        title: title,
                        body: body,
                        jobID: job.id
                    )
                }
            }
        }
        scheduleDownloads()
    }

    private func removeIncompleteOutput(for job: DownloadJob, expectedFolder: String) {
        defer { job.filePath = nil }
        guard let path = job.filePath else { return }
        let output = URL(fileURLWithPath: path).standardizedFileURL
        let folder = URL(fileURLWithPath: expectedFolder, isDirectory: true).standardizedFileURL
        guard output.deletingLastPathComponent() == folder else { return }
        try? FileManager.default.removeItem(at: output)
    }

    private func prepareTemporaryDirectory(for job: DownloadJob, in downloadFolder: String) throws -> URL {
        if let existingPath = job.temporaryDirectoryPath,
           DownloadCachePolicy.owns(directoryPath: existingPath, jobID: job.id) {
            let existing = URL(fileURLWithPath: existingPath, isDirectory: true).standardizedFileURL
            try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
            return existing
        }
        let directory = DownloadCachePolicy.directory(downloadFolder: downloadFolder, jobID: job.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeDownloadCache(for job: DownloadJob, expectedPath: String? = nil) {
        guard let path = expectedPath ?? job.temporaryDirectoryPath,
              DownloadCachePolicy.owns(directoryPath: path, jobID: job.id)
        else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let parent = directory.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directory)
        if job.temporaryDirectoryPath == path {
            job.temporaryDirectoryPath = nil
        }

        // Remove the hidden container too once its final child is gone, but
        // only when it is empty. Other active jobs may still be using it.
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: parent.path), contents.isEmpty {
            try? FileManager.default.removeItem(at: parent)
        }
    }

    private func resolveDownloadFolderForCurrentSession() -> String? {
        let fileManager = FileManager.default
        let isAvailableDirectory: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        if let effective = DownloadFolderPolicy.effectiveFolder(
            configured: downloadFolder,
            sessionOverride: sessionDownloadFolder,
            isAvailableDirectory: isAvailableDirectory
        ) {
            return effective
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = AppText.value(
            "temporaryDownloadFolder",
            language: interfaceLanguage,
            fallback: "Choose a Temporary Download Folder"
        )
        panel.message = AppText.value(
            "downloadFolderUnavailable",
            language: interfaceLanguage,
            fallback: "The default download folder is unavailable. Choose another folder for this app session. Your default location will not be changed."
        )
        panel.prompt = AppText.value(
            "useForThisSession",
            language: interfaceLanguage,
            fallback: "Use for This Session"
        )
        panel.directoryURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let selected = panel.url?.standardizedFileURL.path else {
            return nil
        }
        sessionDownloadFolder = selected
        return selected
    }

    private var browserSessionConfiguration: BrowserSessionConfiguration {
        BrowserSessionConfiguration(
            policy: browserCookiePolicy,
            source: browserCookieSource,
            profile: browserCookieProfile
        )
    }

    private func presentSessionRepair(jobID: UUID) {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        presentSessionRepair(job)
    }

    private func recordCompletion(_ job: DownloadJob, filePath: String) {
        let item = DownloadHistoryItem(
            id: UUID(),
            originalURL: job.originalURL,
            normalizedURL: job.normalizedURL,
            maximumHeight: job.maximumHeight,
            kind: job.kind,
            title: job.title,
            filePath: filePath,
            completedAt: Date()
        )
        history = historyStore.recording(item, in: history)
    }
}
