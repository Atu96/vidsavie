import Foundation

enum BrowserProfileProbeError: LocalizedError, Equatable {
    case denied, missing, unreadable
    var errorDescription: String? {
        switch self {
        case .denied: "Browser cookie database access denied (profile folder cannot be listed)"
        case .missing: "Browser cookie database not found in the selected profile"
        case .unreadable: "Browser profile folder could not be inspected"
        }
    }
}

/// Metadata-only preflight. It never opens a cookie database, copies it, or
/// examines Local State, Preferences, tokens, account names or history.
enum BrowserProfileProbe {
    static func root(source: BrowserCookieSource, home: URL) -> URL {
        let relative: String
        switch source {
        case .chrome: relative = "Google/Chrome"
        case .brave: relative = "BraveSoftware/Brave-Browser"
        case .edge: relative = "Microsoft Edge"
        case .firefox: relative = "Firefox/Profiles"
        }
        return home.appendingPathComponent("Library/Application Support").appendingPathComponent(relative)
    }

    static func searchRoot(configuration: BrowserSessionConfiguration, home: URL) -> URL {
        let profile = configuration.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = root(source: configuration.source, home: home)
        guard !profile.isEmpty else { return base }
        if profile.hasPrefix("/") || profile.hasPrefix("~") {
            return URL(fileURLWithPath: (profile as NSString).expandingTildeInPath)
        }
        return base.appendingPathComponent(profile)
    }

    static func diagnostic(for error: Error) -> BrowserProfileProbeError {
        let ns = error as NSError
        if (ns.domain == NSPOSIXErrorDomain && [1, 13].contains(ns.code))
            || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoPermissionError) {
            return .denied
        }
        if (ns.domain == NSPOSIXErrorDomain && ns.code == 2)
            || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoSuchFileError) {
            return .missing
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return diagnostic(for: underlying)
        }
        return .unreadable
    }

    static func check(_ configuration: BrowserSessionConfiguration, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let root = searchRoot(configuration: configuration, home: home)
        let database = configuration.source == .firefox ? "cookies.sqlite" : "Cookies"
        var pending: [(URL, Int)] = [(root, 0)]
        var inspected = 0
        var denied = false
        var unreadable = false
        while !pending.isEmpty, inspected < 128 {
            let (directory, depth) = pending.removeFirst()
            inspected += 1
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            } catch {
                switch diagnostic(for: error) {
                case .denied: denied = true
                case .unreadable: unreadable = true
                case .missing: break
                }
                continue
            }
            if children.contains(where: { $0.lastPathComponent == database }) { return }
            guard depth < 2 else { continue }
            // Only browser profile containers and the modern Network directory;
            // do not traverse arbitrary browser caches or user-chosen trees.
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = child.lastPathComponent
                let eligible = configuration.source == .firefox
                    ? depth == 0
                    : name == "Default" || name.hasPrefix("Profile ") || name == "Network"
                guard eligible, let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isDirectory == true, values.isSymbolicLink != true else { continue }
                pending.append((child, depth + 1))
            }
        }
        if denied { throw BrowserProfileProbeError.denied }
        if unreadable || !pending.isEmpty { throw BrowserProfileProbeError.unreadable }
        throw BrowserProfileProbeError.missing
    }
}
