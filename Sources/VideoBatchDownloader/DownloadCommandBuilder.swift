import Foundation

struct DownloadCommandBuilder {
    static let smartSelector = "bestvideo[ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4][vcodec^=avc1][acodec^=mp4a]/best"
    /// Prefer YouTube's native M4A/AAC stream. It downloads directly and can
    /// be played on macOS without the extra MP3 conversion step. Sites that
    /// offer only another audio container still fall back to their best audio.
    static let audioSelector = "bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]/bestaudio/best"

    static func selector(maximumHeight: Int?) -> String {
        guard let height = maximumHeight else { return smartSelector }
        return "bestvideo[ext=mp4][height<=\(height)][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[ext=mp4][height<=\(height)]+bestaudio[ext=m4a]/bestvideo[height<=\(height)]+bestaudio/best[ext=mp4][height<=\(height)][vcodec^=avc1][acodec^=mp4a]/best[height<=\(height)]/worst"
    }

    static func arguments(
        url: String,
        folder: String,
        ffmpegPath: String,
        maximumHeight: Int?,
        kind: DownloadKind,
        cookieSpecification: String?,
        temporaryFolder: String? = nil,
        refererURL: String? = nil,
        browserResolvedTitle: String? = nil,
        pluginDirectory: String? = nil
    ) -> [String] {
        var arguments = [
            "--newline",
            // yt-dlp suppresses progress when its streams are pipes (as they
            // are inside this app). Force it back on, but cap updates to a
            // smooth, lightweight cadence for the menu-bar UI.
            "--progress",
            "--progress-delta", "0.2",
            "--no-playlist",
            "--windows-filenames",
            "--continue",
            "--part",
            "-P", folder,
            "-o", DownloadFileNameTemplate.outputTemplate(browserTitle: browserResolvedTitle),
            "--ffmpeg-location", ffmpegPath,
            "--format", kind == .audio ? audioSelector : selector(maximumHeight: maximumHeight),
            "--progress-template", "download:PROGRESS:%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress.speed)s",
            "--print", "before_dl:TITLE:%(title)s",
            "--print", "before_dl:TARGET:%(filepath)s",
            "--print", "after_move:FILE:%(filepath)s",
        ]
        // Keep .part files and fragment downloads away from the user's chosen
        // download folder. `folder` remains yt-dlp's final "home" location.
        if let temporaryFolder, !temporaryFolder.isEmpty {
            arguments.append(contentsOf: ["-P", "temp:\(temporaryFolder)"])
        }
        if URLNormalizer.isBilibili(url) {
            // Long Bilibili DASH streams can slow down or close a connection
            // after an initially fast burst. Smaller HTTP ranges limit the
            // amount repeated after a disconnect; the stable .part cache lets
            // a later card retry continue from the last completed byte.
            arguments.append(contentsOf: [
                "--http-chunk-size", "10M",
                "--socket-timeout", "30",
                "--retries", "30",
                "--fragment-retries", "30",
                "--file-access-retries", "5",
                "--retry-sleep", "http:exp=1:15",
                "--retry-sleep", "fragment:exp=1:15",
            ])
            if let pluginDirectory, !pluginDirectory.isEmpty {
                arguments.append(contentsOf: ["--plugin-dirs", pluginDirectory])
            }
        }
        if kind == .video {
            arguments.append(contentsOf: ["--merge-output-format", "mp4"])
        }
        if let cookieSpecification, !cookieSpecification.isEmpty {
            arguments.append(contentsOf: ["--cookies-from-browser", cookieSpecification])
        }
        if let refererURL, !refererURL.isEmpty {
            arguments.append(contentsOf: [
                "--force-generic-extractor",
                "--remux-video", "mp4",
                "--referer", refererURL,
                "--add-header", "Origin:https://www.douyin.com",
            ])
        }
        arguments.append(url)
        return arguments
    }
}
