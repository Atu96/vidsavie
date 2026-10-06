import Foundation

enum FinderQuickActionKind: String, CaseIterable {
    case cutVideo
    case convertMedia
    case masterAudio

    var windowID: String {
        switch self {
        case .cutVideo: "video-cutter"
        case .convertMedia: "media-converter"
        case .masterAudio: "audio-mastering"
        }
    }

    func accepts(_ url: URL) -> Bool {
        guard let kind = MediaFilePolicy.inputKind(for: url) else { return false }
        switch self {
        case .cutVideo:
            return kind == .video
        case .convertMedia:
            return true
        case .masterAudio:
            return kind == .audio || kind == .video
        }
    }
}

enum MediaToolError: LocalizedError {
    case ffmpegMissing
    case invalidSegmentDuration
    case noInput
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            "FFmpeg was not found in the app bundle or on this Mac."
        case .invalidSegmentDuration:
            "Segment duration must be greater than zero."
        case .noInput:
            "Choose at least one source file."
        case .processFailed(let message):
            message
        }
    }
}

enum MediaBinaryLocator {
    private static func candidates(
        named name: String,
        managedToolsURL: URL?,
        resourceURL: URL?,
        external: [String]
    ) -> [String] {
        let managed = managedToolsURL?.appendingPathComponent(name).path
        let bundled = resourceURL?
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent(name)
            .path
        return [managed, bundled].compactMap { $0 } + external
    }

    static var managedToolsURL: URL? { SupportToolsInstaller.defaultToolsDirectory }

    static func ytDlp(
        fileManager: FileManager = .default,
        managedToolsURL: URL? = MediaBinaryLocator.managedToolsURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> String? {
        candidates(
            named: "yt-dlp",
            managedToolsURL: managedToolsURL,
            resourceURL: resourceURL,
            external: ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]
        ).first(where: fileManager.isExecutableFile(atPath:))
    }

    static func ffmpeg(
        fileManager: FileManager = .default,
        managedToolsURL: URL? = MediaBinaryLocator.managedToolsURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> String? {
        candidates(
            named: "ffmpeg",
            managedToolsURL: managedToolsURL,
            resourceURL: resourceURL,
            external: ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        ).first(where: fileManager.isExecutableFile(atPath:))
    }

    static func ffprobe(
        fileManager: FileManager = .default,
        managedToolsURL: URL? = MediaBinaryLocator.managedToolsURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> String? {
        candidates(
            named: "ffprobe",
            managedToolsURL: managedToolsURL,
            resourceURL: resourceURL,
            external: ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"]
        ).first(where: fileManager.isExecutableFile(atPath:))
    }

    static func isBundled(_ path: String, resourceURL: URL? = Bundle.main.resourceURL) -> Bool {
        guard let toolsPath = resourceURL?.appendingPathComponent("Tools", isDirectory: true).path else {
            return false
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(
            URL(fileURLWithPath: toolsPath).standardizedFileURL.path + "/"
        )
    }

    static func isManaged(_ path: String, managedToolsURL: URL? = MediaBinaryLocator.managedToolsURL) -> Bool {
        guard let toolsPath = managedToolsURL?.path else { return false }
        return URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(
            URL(fileURLWithPath: toolsPath).standardizedFileURL.path + "/"
        )
    }
}

enum VideoCutMode: String, CaseIterable, Identifiable {
    case fastCopy
    case precise

    var id: String { rawValue }
}

/// Editing-only output sequencing. This affects the order in which the
/// generated clips appear in Finder; it never changes the source media.
enum VideoSegmentArrangement: String, CaseIterable, Identifiable {
    case sequential
    case creativeRandom
    case randomSourceMix

    var id: String { rawValue }
}

enum MediaConversionPreset: String, CaseIterable, Identifiable {
    case videoMP4
    case audioMP3
    case imageJPG
    case imagePNG

    var id: String { rawValue }
}

enum MediaInputKind: String, CaseIterable {
    case video
    case audio
    case image

    var compatiblePresets: [MediaConversionPreset] {
        switch self {
        case .video: [.videoMP4, .audioMP3]
        case .audio: [.audioMP3]
        case .image: [.imageJPG, .imagePNG]
        }
    }
}

struct SegmentRenamePlan {
    let outputDirectory: URL
    let temporaryPrefix: String
    let filenamePrefix: String
    let arrangement: VideoSegmentArrangement

    func filename(for sourceIndex: Int, totalSegments: Int) -> String {
        let index: Int
        switch arrangement {
        case .sequential:
            index = sourceIndex
        case .creativeRandom, .randomSourceMix:
            index = sourceIndex
        }
        return MediaFilePolicy.segmentFileName(
            prefix: filenamePrefix,
            number: String(format: "%04d", index + 1),
            suffix: "A"
        )
    }
}

struct BatchSegmentSource {
    let temporaryPrefix: String
    let sourceIndex: Int
}

struct BatchSegmentRenamePlan {
    let outputDirectory: URL
    let sources: [BatchSegmentSource]
    let arrangement: VideoSegmentArrangement

    func fileName(for globalIndex: Int, sourceIndex: Int) -> String {
        MediaFilePolicy.segmentFileName(
            prefix: "",
            number: String(format: "%04d", globalIndex + 1),
            suffix: MediaFilePolicy.alphabeticSegmentSuffix(for: sourceIndex)
        )
    }
}

struct VideoCutBatchPlan {
    let inputs: [URL]
    let outputRoot: URL

    func outputDirectory(for input: URL) -> URL {
        outputRoot
    }

    func filenamePrefix(for input: URL, requestedPrefix: String) -> String {
        guard inputs.count > 1 else { return requestedPrefix }
        return input.deletingPathExtension().lastPathComponent
    }
}

struct MediaToolCommand {
    let label: String
    let inputURL: URL
    let outputURL: URL
    let arguments: [String]
    let revealsDirectory: Bool
    let segmentRenamePlan: SegmentRenamePlan?
    let batchSegmentRenamePlan: BatchSegmentRenamePlan?
}

enum MediaToolCommandBuilder {
    static let masteringFilter = "agate=threshold=0.012:ratio=1.5:attack=15:release=220:range=0.18,loudnorm=I=-14:TP=-1.5:LRA=11"

    static func videoCut(
        input: URL,
        outputDirectory: URL,
        seconds: Double,
        mode: VideoCutMode,
        filenamePrefix: String,
        arrangement: VideoSegmentArrangement = .sequential,
        batchSegmentRenamePlan: BatchSegmentRenamePlan? = nil
    ) throws -> MediaToolCommand {
        guard seconds > 0 else { throw MediaToolError.invalidSegmentDuration }
        let temporaryPrefix = ".videobatch-cut-\(UUID().uuidString)"
        let template = outputDirectory.appendingPathComponent("\(temporaryPrefix)_%08d.mp4").path
        var arguments = ["-hide_banner", "-progress", "pipe:2", "-nostats", "-y", "-i", input.path]
        switch mode {
        case .fastCopy:
            arguments += ["-c", "copy", "-map", "0"]
        case .precise:
            arguments += [
                "-c:v", "h264_videotoolbox", "-b:v", "8M",
                "-c:a", "aac", "-b:a", "192k", "-map", "0",
            ]
        }
        arguments += [
            "-f", "segment",
            "-segment_time", String(seconds),
            "-start_number", "0",
            "-reset_timestamps", "1",
            "-segment_format", "mp4",
            template,
        ]
        return MediaToolCommand(
            label: input.lastPathComponent,
            inputURL: input,
            outputURL: outputDirectory,
            arguments: arguments,
            revealsDirectory: true,
            segmentRenamePlan: SegmentRenamePlan(
                outputDirectory: outputDirectory,
                temporaryPrefix: temporaryPrefix,
                filenamePrefix: filenamePrefix,
                arrangement: arrangement
            ),
            batchSegmentRenamePlan: batchSegmentRenamePlan
        )
    }

    static func conversion(
        input: URL,
        preset: MediaConversionPreset,
        outputURL: URL
    ) -> MediaToolCommand {
        var arguments = ["-hide_banner", "-progress", "pipe:2", "-nostats", "-y"]
        switch preset {
        case .videoMP4:
            arguments += [
                "-hwaccel", "videotoolbox",
                "-i", input.path,
                "-map", "0:v:0", "-map", "0:a?", "-map_metadata", "0",
                "-c:v", "h264_videotoolbox", "-b:v", "10M",
                "-c:a", "aac", "-b:a", "192k",
                "-movflags", "+faststart",
                outputURL.path,
            ]
        case .audioMP3:
            arguments += [
                "-i", input.path, "-map", "0:a:0", "-vn",
                "-c:a", "libmp3lame", "-b:a", "320k", outputURL.path,
            ]
        case .imageJPG:
            arguments += [
                "-i", input.path, "-frames:v", "1", "-q:v", "2",
                "-update", "1", outputURL.path,
            ]
        case .imagePNG:
            arguments += [
                "-i", input.path, "-frames:v", "1", "-compression_level", "6",
                "-update", "1", outputURL.path,
            ]
        }
        return MediaToolCommand(
            label: input.lastPathComponent,
            inputURL: input,
            outputURL: outputURL,
            arguments: arguments,
            revealsDirectory: false,
            segmentRenamePlan: nil,
            batchSegmentRenamePlan: nil
        )
    }

    static func audioMastering(input: URL, outputURL: URL, containsVideo: Bool) -> MediaToolCommand {
        var arguments = ["-hide_banner", "-progress", "pipe:2", "-nostats", "-y", "-i", input.path]
        if containsVideo {
            arguments += [
                "-map", "0:v:0?", "-map", "0:a:0",
                "-c:v", "copy",
                "-af", masteringFilter,
                "-c:a", "aac", "-b:a", "192k",
                "-movflags", "+faststart",
                outputURL.path,
            ]
        } else {
            arguments += [
                "-map", "0:a:0", "-vn",
                "-af", masteringFilter,
                "-c:a", "pcm_s24le", "-ar", "48000",
                outputURL.path,
            ]
        }
        return MediaToolCommand(
            label: input.lastPathComponent,
            inputURL: input,
            outputURL: outputURL,
            arguments: arguments,
            revealsDirectory: false,
            segmentRenamePlan: nil,
            batchSegmentRenamePlan: nil
        )
    }
}

enum MediaFilePolicy {
    static let videoExtensions = Set(["mp4", "mov", "mkv", "webm", "avi", "m4v", "ts", "mts", "m2ts", "flv", "wmv"])
    static let audioExtensions = Set(["mp3", "wav", "m4a", "aac", "flac", "ogg", "opus", "aiff", "aif", "caf"])
    static let imageExtensions = Set(["jpg", "jpeg", "png", "webp", "heic", "heif", "tif", "tiff", "bmp", "gif", "avif"])

    static func containsVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    static func inputKind(for url: URL) -> MediaInputKind? {
        let fileExtension = url.pathExtension.lowercased()
        if videoExtensions.contains(fileExtension) { return .video }
        if audioExtensions.contains(fileExtension) { return .audio }
        if imageExtensions.contains(fileExtension) { return .image }
        return nil
    }

    static func accepts(_ url: URL, as kind: MediaInputKind) -> Bool {
        inputKind(for: url) == kind
    }

    static func outputDescriptor(for preset: MediaConversionPreset) -> (suffix: String, extension: String) {
        switch preset {
        case .videoMP4: ("-h264-vt", "mp4")
        case .audioMP3: ("-mp3-320", "mp3")
        case .imageJPG: ("-jpg", "jpg")
        case .imagePNG: ("-png", "png")
        }
    }

    static func uniqueOutputURL(
        for input: URL,
        suffix: String,
        extension fileExtension: String,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> URL {
        let directory = input.deletingLastPathComponent()
        let stem = input.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(stem)\(suffix).\(fileExtension)")
        var index = 1
        while fileExists(candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)\(suffix)-\(index).\(fileExtension)")
            index += 1
        }
        return candidate
    }

    static func sanitizedSegmentComponent(_ component: String) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = trimmed.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result
    }

    static func segmentFileName(prefix: String, number: String, suffix: String) -> String {
        [sanitizedSegmentComponent(prefix), number, sanitizedSegmentComponent(suffix)]
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    static func alphabeticSegmentSuffix(for index: Int) -> String {
        let letter = Character(UnicodeScalar(65 + (index % 26))!)
        let cycle = index / 26
        return cycle == 0 ? String(letter) : "\(letter)\(cycle)"
    }

}
