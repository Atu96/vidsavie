import Foundation

enum PreferenceKeys {
    static let extensionEnabled = "ExtensionEnabled"
    static let showOverlay = "ShowOverlay"
    static let defaultQuality = "DefaultQuality"
    static let scanRegion = "BrowserScanRegion"
    static let defaultDownloadKind = "DefaultDownloadKind"
    static let interfaceLanguage = "InterfaceLanguage"
    static let visualTheme = "VisualTheme"
    static let autoUpdateYtDlp = "AutoUpdateYtDlp"
    static let browserCookiePolicy = "BrowserCookiePolicy"
    static let browserCookieSource = "BrowserCookieSource"
    static let browserCookieProfile = "BrowserCookieProfile"
}

enum AppPreferences {
    static let defaultLanguage = "en"
    static func language(_ stored: String?) -> String {
        guard let stored, ["auto", "en", "vi", "zh", "es", "fr", "de", "pt", "ja", "ko"].contains(stored) else { return defaultLanguage }
        return stored
    }
    static let supportedThemes = Set(["auto", "dark", "light"])

    static func theme(_ value: String?) -> String {
        guard let value, supportedThemes.contains(value) else { return "auto" }
        return value
    }

    static func bool(_ key: String, default fallback: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func string(_ key: String, default fallback: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? fallback
    }

    static var response: [String: Any] {
        [
            "enabled": bool(PreferenceKeys.extensionEnabled, default: true),
            "showOverlay": bool(PreferenceKeys.showOverlay, default: true),
            "defaultQuality": string(PreferenceKeys.defaultQuality, default: "best"),
            "scanRegion": string(PreferenceKeys.scanRegion, default: "middle"),
            "language": language(UserDefaults.standard.string(forKey: PreferenceKeys.interfaceLanguage)),
            "theme": theme(UserDefaults.standard.string(forKey: PreferenceKeys.visualTheme)),
        ]
    }

    static func apply(_ update: PreferencesUpdate) {
        if let value = update.enabled { UserDefaults.standard.set(value, forKey: PreferenceKeys.extensionEnabled) }
        if let value = update.showOverlay { UserDefaults.standard.set(value, forKey: PreferenceKeys.showOverlay) }
        if let value = update.defaultQuality, ["best", "1080", "720", "480"].contains(value) { UserDefaults.standard.set(value, forKey: PreferenceKeys.defaultQuality) }
        if let value = update.scanRegion, ["middle", "full"].contains(value) { UserDefaults.standard.set(value, forKey: PreferenceKeys.scanRegion) }
        if let value = update.language, ["auto", "en", "vi", "zh", "es", "fr", "de", "pt", "ja", "ko"].contains(value) { UserDefaults.standard.set(value, forKey: PreferenceKeys.interfaceLanguage) }
        if let value = update.theme { UserDefaults.standard.set(theme(value), forKey: PreferenceKeys.visualTheme) }
    }
}

struct PreferencesUpdate: Decodable {
    let enabled: Bool?
    let showOverlay: Bool?
    let defaultQuality: String?
    let scanRegion: String?
    let language: String?
    let theme: String?
}
