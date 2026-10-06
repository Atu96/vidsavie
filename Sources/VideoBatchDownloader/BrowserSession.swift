import Foundation

enum BrowserCookiePolicy: String, Codable, CaseIterable {
    case smart
    case always
    case never
}

enum BrowserCookieSource: String, Codable, CaseIterable {
    case chrome
    case brave
    case edge
    case firefox

    var ytDlpName: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: "Google Chrome"
        case .brave: "Brave"
        case .edge: "Microsoft Edge"
        case .firefox: "Mozilla Firefox"
        }
    }
}

enum BrowserSessionIssue: String, Codable, Equatable {
    case forbidden
    case verificationRequired
    case cookieAccess
}

enum BrowserSessionIssueClassifier {
    static func needsFreshCookies(_ processOutput: String) -> Bool {
        processOutput.localizedCaseInsensitiveContains("fresh cookies")
    }

    static func classify(url: String, processOutput: String) -> BrowserSessionIssue? {
        let normalized = processOutput.lowercased()

        let cookieAccessSignals = [
            "unable to extract cookies",
            "could not copy chrome cookie database",
            "failed to decrypt",
            "cookie database",
            "keyring",
            "cookies-from-browser",
        ]
        if cookieAccessSignals.contains(where: normalized.contains) {
            return .cookieAccess
        }

        // Douyin's extractor explicitly asks for a new browser cookie set
        // when its anti-bot token has rotated. It is a session issue even
        // though the user may not need to sign in again.
        if URLNormalizer.isDouyin(url), needsFreshCookies(processOutput) {
            return .verificationRequired
        }

        guard URLNormalizer.isYouTube(url) else { return nil }
        if normalized.contains("private video")
            || normalized.contains("video unavailable")
            || normalized.contains("not available in your country") {
            return nil
        }

        let verificationSignals = [
            "sign in",
            "login required",
            "confirm you’re not a bot",
            "confirm you're not a bot",
            "not a bot",
            "authentication",
            "age-restricted",
            "fresh cookies",
        ]
        if verificationSignals.contains(where: normalized.contains) {
            return .verificationRequired
        }

        let forbiddenSignals = [
            "http error 403",
            "403: forbidden",
            "403 forbidden",
            "unable to download video data",
        ]
        if forbiddenSignals.contains(where: normalized.contains) {
            return .forbidden
        }
        return nil
    }
}

struct BrowserSessionConfiguration: Equatable {
    let policy: BrowserCookiePolicy
    let source: BrowserCookieSource
    let profile: String

    var cookieSpecification: String {
        let trimmedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProfile.isEmpty ? source.ytDlpName : "\(source.ytDlpName):\(trimmedProfile)"
    }

    func shouldUseCookiesInitially(for url: String) -> Bool {
        switch policy {
        case .always:
            true
        case .never:
            false
        case .smart:
            URLNormalizer.isDouyin(url)
                || URLNormalizer.isX(url)
                || URLNormalizer.isFacebook(url)
                || URLNormalizer.isInstagram(url)
                || URLNormalizer.isBilibili(url)
        }
    }

    func shouldRetryWithCookies(url: String, processOutput: String, alreadyUsedCookies: Bool) -> Bool {
        guard policy == .smart, !alreadyUsedCookies else { return false }
        return BrowserSessionIssueClassifier.classify(url: url, processOutput: processOutput) != nil
    }

    /// A Douyin request may fail while its short-lived browser token rotates.
    /// Start one new yt-dlp process so `--cookies-from-browser` reads the
    /// current database again. This is intentionally bounded to one retry.
    func shouldRefreshCookiesAndRetry(url: String, processOutput: String, alreadyUsedCookies: Bool) -> Bool {
        guard policy != .never, alreadyUsedCookies, URLNormalizer.isDouyin(url) else { return false }
        return BrowserSessionIssueClassifier.needsFreshCookies(processOutput)
    }
}

/// Keeps each browser-resolved media attempt isolated from cookie handling.
/// DownloadEngine may later run an explicit page-extractor fallback, but that
/// is a separate tier whose failure is reported alongside the direct result.
enum DownloadSessionPlan {
    static func shouldUseCookiesInitially(
        directMediaURL: String?,
        pageURL: String,
        browserSession: BrowserSessionConfiguration
    ) -> Bool {
        directMediaURL == nil && browserSession.shouldUseCookiesInitially(for: pageURL)
    }

    static func shouldRetryWithCookies(
        directMediaURL: String?,
        pageURL: String,
        processOutput: String,
        alreadyUsedCookies: Bool,
        browserSession: BrowserSessionConfiguration
    ) -> Bool {
        directMediaURL == nil && browserSession.shouldRetryWithCookies(
            url: pageURL,
            processOutput: processOutput,
            alreadyUsedCookies: alreadyUsedCookies
        )
    }

    static func shouldRefreshCookiesAndRetry(
        directMediaURL: String?,
        pageURL: String,
        processOutput: String,
        alreadyUsedCookies: Bool,
        browserSession: BrowserSessionConfiguration
    ) -> Bool {
        directMediaURL == nil && browserSession.shouldRefreshCookiesAndRetry(
            url: pageURL,
            processOutput: processOutput,
            alreadyUsedCookies: alreadyUsedCookies
        )
    }
}

enum BrowserSessionRepairTarget {
    static func url(for failedURL: String) -> URL? {
        if URLNormalizer.isDouyin(failedURL) {
            return URL(string: failedURL)
        }
        return URL(string: "https://www.youtube.com/")
    }
}
