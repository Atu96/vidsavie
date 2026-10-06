import Foundation

enum LocalAPIOriginPolicy {
    static func isAllowed(_ origin: String?) -> Bool {
        guard let origin, !origin.isEmpty else { return true }
        return origin.hasPrefix("chrome-extension://") || origin.hasPrefix("moz-extension://")
    }

    static func corsValue(for origin: String?) -> String? {
        guard let origin, isAllowed(origin) else { return nil }
        return origin
    }
}
