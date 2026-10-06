import Foundation

enum URLNormalizer {
    static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let host = components.host?.lowercased()
        else { return trimmed }

        if host == "douyin.com" || host.hasSuffix(".douyin.com") {
            if let modalID = components.queryItems?.first(where: { $0.name == "modal_id" })?.value,
               modalID.allSatisfy(\.isNumber), !modalID.isEmpty {
                return "https://www.douyin.com/video/\(modalID)"
            }
            components.fragment = nil
            return components.url?.absoluteString ?? trimmed
        }

        if host == "youtu.be" {
            let id = components.path.split(separator: "/").first.map(String.init) ?? ""
            return id.isEmpty ? trimmed : "https://www.youtube.com/watch?v=\(id)"
        }

        if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                return "https://www.youtube.com/watch?v=\(id)"
            }
            let parts = components.path.split(separator: "/")
            if parts.count >= 2, ["shorts", "live"].contains(String(parts[0])) {
                return "https://www.youtube.com/watch?v=\(parts[1])"
            }
        }

        if isXHost(host) {
            let parts = components.path.split(separator: "/")
            if let statusIndex = parts.firstIndex(of: "status"), parts.count > statusIndex + 1 {
                let id = String(parts[statusIndex + 1])
                if !id.isEmpty, id.allSatisfy(\.isNumber) {
                    return "https://x.com/i/status/\(id)"
                }
            }
        }

        if isBilibiliHost(host) {
            components.fragment = nil
            return components.url?.absoluteString ?? trimmed
        }

        return trimmed
    }

    static func isDouyin(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return host == "douyin.com" || host.hasSuffix(".douyin.com")
    }

    static func trustedDouyinMediaURL(_ mediaURL: String, pageURL: String) -> Bool {
        guard isDouyin(pageURL), let url = URL(string: mediaURL), url.scheme == "https",
              let host = url.host?.lowercased()
        else { return false }
        let trustedSuffixes = [
            "douyinvod.com",
            "douyin.com",
            "bytecdn.cn",
            "zjcdn.com",
            "bytedance.com",
            "snssdk.com",
            "volccdn.com",
        ]
        return trustedSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    static func trustedDouyinMediaURLs(_ mediaURLs: [String], legacyMediaURL: String?, pageURL: String) -> [String] {
        var seen = Set<String>()
        return ([legacyMediaURL].compactMap { $0 } + mediaURLs).filter { mediaURL in
            guard seen.insert(mediaURL).inserted else { return false }
            return trustedDouyinMediaURL(mediaURL, pageURL: pageURL)
        }.prefix(12).map { $0 }
    }

    static func isYouTube(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    static func isX(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return isXHost(host)
    }

    static func isXImage(_ input: String) -> Bool {
        guard let components = URLComponents(string: input), let host = components.host?.lowercased() else { return false }
        return host == "pbs.twimg.com" && components.path.hasPrefix("/media/")
    }

    static func isFacebook(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return host == "facebook.com" || host.hasSuffix(".facebook.com") || host.hasSuffix(".fbcdn.net")
    }

    static func isInstagram(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return host == "instagram.com" || host.hasSuffix(".instagram.com") || host.hasSuffix(".cdninstagram.com")
    }

    static func isBilibili(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return isBilibiliHost(host)
    }

    static func isGoogleImage(_ input: String) -> Bool {
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return false }
        return host.contains("googleusercontent.com") || host.contains("gstatic.com") || host.hasPrefix("images.google.")
    }

    static func isSupported(_ input: String) -> Bool {
        guard let scheme = URLComponents(string: input)?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    static func displayName(for input: String) -> String {
        if isXImage(input) { return "X image" }
        if isDouyin(input) { return "Douyin video" }
        if isYouTube(input) { return "YouTube video" }
        if isX(input) { return "X video" }
        if isFacebook(input) { return "Facebook video" }
        if isInstagram(input) { return "Instagram video" }
        if isBilibili(input) { return "Bilibili video" }
        return input
    }

    static func imageDisplayName(for input: String) -> String {
        if isXImage(input) { return "X image" }
        if isInstagram(input) { return "Instagram image" }
        if isFacebook(input) { return "Facebook image" }
        if isGoogleImage(input) { return "Google image" }
        guard let host = URLComponents(string: input)?.host?.lowercased() else { return "Website image" }
        return "Image · \(host.replacingOccurrences(of: "www.", with: ""))"
    }

    private static func isXHost(_ host: String) -> Bool {
        host == "x.com" || host.hasSuffix(".x.com") || host == "twitter.com" || host.hasSuffix(".twitter.com") || host == "pbs.twimg.com"
    }

    private static func isBilibiliHost(_ host: String) -> Bool {
        host == "b23.tv"
            || host.hasSuffix(".b23.tv")
            || host == "bilibili.com"
            || host.hasSuffix(".bilibili.com")
    }
}
