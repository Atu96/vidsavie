import Foundation

enum DownloadFileNameTemplate {
    static let titleKey = "FileNameIncludeTitle"
    static let authorKey = "FileNameIncludeAuthor"
    static let dateKey = "FileNameIncludeUploadDate"
    private static let browserTitleMaximumUTF8Bytes = 160

    static func browserResolvedTitle(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let singleLine = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let forbidden = CharacterSet(charactersIn: "<>:\"/\\|?*")
        let portable = singleLine.unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.controlCharacters.contains(scalar) {
                return
            }
            result.append(forbidden.contains(scalar) ? "-" : String(scalar))
        }
        let safe = portable
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !safe.isEmpty else { return nil }

        // Filesystems limit one filename component by bytes, not Swift
        // Character count. Leave room for the extension, yt-dlp temporary
        // suffixes, and Unicode normalization by bounding the title itself.
        var bounded = ""
        var byteCount = 0
        for character in safe {
            let bytes = String(character).utf8.count
            guard byteCount + bytes <= browserTitleMaximumUTF8Bytes else { break }
            bounded.append(character)
            byteCount += bytes
        }
        let result = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    static func outputTemplate(browserTitle: String? = nil) -> String {
        if let title = browserResolvedTitle(browserTitle) {
            // A literal percent must be escaped inside a yt-dlp output template.
            return title.replacingOccurrences(of: "%", with: "%%") + ".%(ext)s"
        }
        var fields: [String] = []
        if UserDefaults.standard.object(forKey: titleKey) == nil || UserDefaults.standard.bool(forKey: titleKey) { fields.append("%(title)s") }
        if UserDefaults.standard.bool(forKey: authorKey) { fields.append("%(uploader)s") }
        if UserDefaults.standard.bool(forKey: dateKey) { fields.append("%(upload_date>%d-%m-%Y)s") }
        return (fields.isEmpty ? ["%(title)s"] : fields).joined(separator: " — ") + ".%(ext)s"
    }
}
