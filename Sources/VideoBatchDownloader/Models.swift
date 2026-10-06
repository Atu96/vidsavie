import Foundation

enum DownloadErrorReport {
    static func text(
        appVersion: String,
        build: String,
        title: String,
        url: String,
        error: String
    ) -> String {
        [
            "VidSavie \(appVersion) (\(build))",
            "Title: \(title)",
            "URL: \(url)",
            "Error: \(error)",
        ].joined(separator: "\n")
    }
}

enum BrowserResolutionDetail {
    static func safe(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value.utf8.count <= 96,
              value.utf8.allSatisfy({ byte in
                  (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
                      || byte == 45 || byte == 59 || byte == 95
              }) else { return nil }
        return value
    }
}

enum DownloadStatus: String, Codable {
    case queued
    case fetching
    case downloading
    case waitingForGPU
    case converting
    case convertingAudio
    case completed
    case failed
    case stopped

    var title: String {
        switch self {
        case .queued: "Waiting"
        case .fetching: "Reading video"
        case .downloading: "Downloading"
        case .waitingForGPU: "Waiting for GPU"
        case .converting: "Converting video with GPU"
        case .convertingAudio: "Creating MP3"
        case .completed: "Completed"
        case .failed: "Failed"
        case .stopped: "Stopped"
        }
    }

    var isActive: Bool {
        [.fetching, .downloading, .waitingForGPU, .converting, .convertingAudio].contains(self)
    }
}

enum DownloadQueueRetention {
    static func shouldRetain(_ status: DownloadStatus) -> Bool {
        status != .completed
    }
}

enum DownloadQueueRemoval {
    static func canRemove(_ status: DownloadStatus) -> Bool {
        status == .failed || status == .stopped
    }
}

enum DownloadFolderPolicy {
    static func effectiveFolder(
        configured: String,
        sessionOverride: String?,
        isAvailableDirectory: (String) -> Bool
    ) -> String? {
        if let sessionOverride, isAvailableDirectory(sessionOverride) {
            return sessionOverride
        }
        return isAvailableDirectory(configured) ? configured : nil
    }
}

enum DownloadKind: String, Codable {
    case video
    case audio
    case image
}

struct DownloadHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let originalURL: String
    let normalizedURL: String
    let maximumHeight: Int?
    let kind: DownloadKind
    let title: String
    let filePath: String
    let completedAt: Date
}

@MainActor
final class DownloadJob: ObservableObject, Identifiable {
    let id = UUID()
    let originalURL: String
    let normalizedURL: String
    /// A short-lived media URL resolved inside the active browser page. It is
    /// never persisted to history and never contains exported cookie values.
    let mediaURLs: [String]
    var mediaURL: String? { mediaURLs.first }
    let browserResolvedTitle: String?
    let browserResolutionAttempted: Bool
    let browserResolutionDetail: String?
    let maximumHeight: Int?
    let kind: DownloadKind
    let createdAt = Date()

    @Published var title: String
    @Published var status: DownloadStatus = .queued
    @Published var progress: Double = 0
    @Published var speed = ""
    @Published var eta = ""
    @Published var downloadedBytes: Double?
    @Published var totalBytes: Double?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var browserSessionIssue: BrowserSessionIssue?

    var process: Process?
    var transferProgress: DownloadTransferProgressAccumulator
    /// yt-dlp keeps incomplete fragments here. The directory is stable for the
    /// lifetime of this card so Retry can resume; completion or Delete removes it.
    var temporaryDirectoryPath: String?

    init(url: String, mediaURL: String? = nil, mediaURLs: [String] = [], browserResolvedTitle: String? = nil, browserResolutionAttempted: Bool = false, browserResolutionDetail: String? = nil, maximumHeight: Int? = nil, kind: DownloadKind = .video) {
        originalURL = url
        normalizedURL = URLNormalizer.normalize(url)
        self.mediaURLs = Array(Set(([mediaURL].compactMap { $0 } + mediaURLs))).sorted { left, right in
            let leftIndex = ([mediaURL].compactMap { $0 } + mediaURLs).firstIndex(of: left) ?? .max
            let rightIndex = ([mediaURL].compactMap { $0 } + mediaURLs).firstIndex(of: right) ?? .max
            return leftIndex < rightIndex
        }
        self.browserResolvedTitle = DownloadFileNameTemplate.browserResolvedTitle(browserResolvedTitle)
        self.browserResolutionAttempted = browserResolutionAttempted
        self.browserResolutionDetail = BrowserResolutionDetail.safe(browserResolutionDetail)
        self.maximumHeight = maximumHeight
        self.kind = kind
        transferProgress = DownloadTransferProgressAccumulator(kind: kind)
        let detail = switch kind {
        case .audio: " · Audio"
        case .image: " · Original image"
        case .video: maximumHeight.map { " · up to \($0)p" } ?? " · Best"
        }
        let baseTitle = self.browserResolvedTitle
            ?? (kind == .image ? URLNormalizer.imageDisplayName(for: normalizedURL) : URLNormalizer.displayName(for: normalizedURL))
        title = baseTitle + detail
    }

    func resetTransferProgress() {
        transferProgress = DownloadTransferProgressAccumulator(kind: kind)
    }
}

struct EnqueueItem: Decodable {
    let url: String
    let mediaURL: String?
    let mediaURLs: [String]?
    let title: String?
    let browserResolutionAttempted: Bool
    let browserResolutionDetail: String?
    let maxHeight: Int?
    let kind: DownloadKind

    init(url: String, mediaURL: String? = nil, mediaURLs: [String]? = nil, title: String? = nil, browserResolutionAttempted: Bool = false, browserResolutionDetail: String? = nil, maxHeight: Int?, kind: DownloadKind = .video) {
        self.url = url
        self.mediaURL = mediaURL
        self.mediaURLs = mediaURLs
        self.title = title
        self.browserResolutionAttempted = browserResolutionAttempted
        self.browserResolutionDetail = BrowserResolutionDetail.safe(browserResolutionDetail)
        self.maxHeight = maxHeight
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case url, mediaURL, mediaURLs, title, browserResolutionAttempted, browserResolutionDetail, maxHeight, kind }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL)
        mediaURLs = try container.decodeIfPresent([String].self, forKey: .mediaURLs)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        browserResolutionAttempted = try container.decodeIfPresent(Bool.self, forKey: .browserResolutionAttempted) ?? false
        browserResolutionDetail = BrowserResolutionDetail.safe(try container.decodeIfPresent(String.self, forKey: .browserResolutionDetail))
        maxHeight = try container.decodeIfPresent(Int.self, forKey: .maxHeight)
        kind = try container.decodeIfPresent(DownloadKind.self, forKey: .kind) ?? .video
    }
}

struct EnqueueRequest: Decodable {
    let items: [EnqueueItem]

    private enum CodingKeys: String, CodingKey { case items, urls }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedItems = try container.decodeIfPresent([EnqueueItem].self, forKey: .items) {
            items = decodedItems
        } else {
            items = try container.decodeIfPresent([String].self, forKey: .urls)?.map {
                EnqueueItem(url: $0, maxHeight: nil, kind: .video)
            } ?? []
        }
    }
}

struct EnqueueResponse: Encodable {
    let accepted: Int
    let total: Int
}
