import Foundation

enum DownloadCachePolicy {
    static let containerName = ".VideoBatchDownloader-cache"

    static func directory(downloadFolder: String, jobID: UUID) -> URL {
        URL(fileURLWithPath: downloadFolder, isDirectory: true)
            .appendingPathComponent(containerName, isDirectory: true)
            .appendingPathComponent(jobID.uuidString, isDirectory: true)
            .standardizedFileURL
    }

    static func owns(directoryPath: String, jobID: UUID) -> Bool {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true).standardizedFileURL
        return directory.lastPathComponent == jobID.uuidString
            && directory.deletingLastPathComponent().lastPathComponent == containerName
    }
}

struct DownloadHistoryStore {
    private let defaults: UserDefaults
    private let key: String
    private let maximumItems: Int

    init(
        defaults: UserDefaults = .standard,
        key: String = "DownloadHistory.v1",
        maximumItems: Int = 300
    ) {
        self.defaults = defaults
        self.key = key
        self.maximumItems = maximumItems
    }

    func load() -> [DownloadHistoryItem] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([DownloadHistoryItem].self, from: data)
        else { return [] }
        return Array(items.sorted { $0.completedAt > $1.completedAt }.prefix(maximumItems))
    }

    func recording(_ item: DownloadHistoryItem, in current: [DownloadHistoryItem]) -> [DownloadHistoryItem] {
        var updated = current.filter {
            !($0.normalizedURL == item.normalizedURL
                && $0.kind == item.kind
                && $0.maximumHeight == item.maximumHeight)
        }
        updated.insert(item, at: 0)
        if updated.count > maximumItems {
            updated.removeLast(updated.count - maximumItems)
        }
        persist(updated)
        return updated
    }

    func removing(id: UUID, from current: [DownloadHistoryItem]) -> [DownloadHistoryItem] {
        let updated = current.filter { $0.id != id }
        persist(updated)
        return updated
    }

    func clear() -> [DownloadHistoryItem] {
        persist([])
        return []
    }

    private func persist(_ items: [DownloadHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}

enum SupportToolsUpdatePolicy {
    static let interval: TimeInterval = 24 * 60 * 60

    static func hasChangedTools(current: [String?], latest: [String]) -> Bool {
        guard current.count == latest.count else { return true }
        return zip(current, latest).contains { $0 != $1 }
    }

    static func shouldStart(
        enabled: Bool,
        forced: Bool,
        taskIsRunning: Bool,
        lastCheck: Date?,
        now: Date = Date()
    ) -> Bool {
        guard (enabled || forced), !taskIsRunning else { return false }
        guard !forced, let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    static func retryDateAfterFailure(now: Date = Date()) -> Date {
        now.addingTimeInterval(-(interval - 60 * 60))
    }
}
