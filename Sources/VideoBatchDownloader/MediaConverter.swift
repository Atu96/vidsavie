import Foundation

final class MediaConverter {
    private let runner: ProcessRunner
    private let fileManager: FileManager
    private let ffmpegPath: String
    private let ffprobePath: String

    init(
        runner: ProcessRunner,
        fileManager: FileManager = .default,
        ffmpegPath: String,
        ffprobePath: String
    ) {
        self.runner = runner
        self.fileManager = fileManager
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
    }

    func needsAudioConversion(_ filePath: String) -> Bool {
        let compatible = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac"]
        return !compatible.contains(URL(fileURLWithPath: filePath).pathExtension.lowercased())
    }

    func convertToMP3(
        _ sourcePath: String,
        onProcess: @escaping (Process) -> Void
    ) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let outputURL = uniqueURL(for: sourceURL, extension: "mp3")
        let result = try await runner.run(executable: ffmpegPath, arguments: [
            "-hide_banner", "-stats", "-y", "-i", sourcePath,
            "-map", "0:a:0", "-map_metadata", "0", "-vn",
            "-c:a", "libmp3lame", "-q:a", "2", outputURL.path,
        ], onProcess: onProcess)
        guard result.status == 0 else {
            try? fileManager.removeItem(at: outputURL)
            throw DownloadEngineError.processFailed(lastUsefulLine(in: result.output))
        }
        try fileManager.removeItem(at: sourceURL)
        return outputURL.path
    }

    func needsVideoConversion(_ filePath: String) async throws -> Bool {
        let probe = try await probe(filePath)
        let video = probe.streams.first(where: { $0.codecType == "video" })
        let audio = probe.streams.first(where: { $0.codecType == "audio" })
        let isMP4 = URL(fileURLWithPath: filePath).pathExtension.lowercased() == "mp4"
        let macCompatibleVideoCodecs = ["h264", "hevc", "h265"]
        return !(isMP4 && macCompatibleVideoCodecs.contains(video?.codecName ?? "") && (audio == nil || audio?.codecName == "aac"))
    }

    func convertToCompatibleMP4(
        _ sourcePath: String,
        onProcess: @escaping (Process) -> Void
    ) async throws -> String {
        let probe = try await probe(sourcePath)
        let copyAAC = probe.streams.first(where: { $0.codecType == "audio" })?.codecName == "aac"
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let sourceIsMP4 = sourceURL.pathExtension.lowercased() == "mp4"
        let outputURL = sourceIsMP4
            ? sourceURL.deletingLastPathComponent().appendingPathComponent(".\(sourceURL.lastPathComponent).h264-vt-\(UUID().uuidString).mp4")
            : uniqueMP4URL(for: sourceURL)

        do {
            var result = try await runConversion(
                sourcePath: sourcePath,
                outputPath: outputURL.path,
                copyAAC: copyAAC,
                hardwareDecode: true,
                onProcess: onProcess
            )
            if result.status != 0 {
                try? fileManager.removeItem(at: outputURL)
                result = try await runConversion(
                    sourcePath: sourcePath,
                    outputPath: outputURL.path,
                    copyAAC: copyAAC,
                    hardwareDecode: false,
                    onProcess: onProcess
                )
            }
            guard result.status == 0 else {
                throw DownloadEngineError.processFailed(lastUsefulLine(in: result.output))
            }

            if sourceIsMP4 {
                _ = try fileManager.replaceItemAt(sourceURL, withItemAt: outputURL)
                return sourcePath
            }
            try fileManager.removeItem(at: sourceURL)
            return outputURL.path
        } catch {
            try? fileManager.removeItem(at: outputURL)
            throw error
        }
    }

    private func runConversion(
        sourcePath: String,
        outputPath: String,
        copyAAC: Bool,
        hardwareDecode: Bool,
        onProcess: @escaping (Process) -> Void
    ) async throws -> ProcessResult {
        var arguments = ["-hide_banner", "-stats", "-y"]
        if hardwareDecode {
            arguments.append(contentsOf: ["-hwaccel", "videotoolbox", "-hwaccel_output_format", "videotoolbox_vld"])
        }
        arguments.append(contentsOf: [
            "-i", sourcePath,
            "-map", "0:v:0",
            "-map", "0:a?",
            "-map_metadata", "0",
            "-c:v", "h264_videotoolbox",
            "-b:v", "10M",
        ])
        arguments.append(contentsOf: copyAAC ? ["-c:a", "copy"] : ["-c:a", "aac", "-b:a", "192k"])
        arguments.append(contentsOf: ["-movflags", "+faststart", outputPath])
        return try await runner.run(executable: ffmpegPath, arguments: arguments, onProcess: onProcess)
    }

    private func probe(_ filePath: String) async throws -> ProbeResult {
        let result = try await runner.run(executable: ffprobePath, arguments: [
            "-v", "error",
            "-show_entries", "format=format_name:stream=codec_type,codec_name",
            "-of", "json",
            filePath,
        ])
        guard result.status == 0, let data = result.output.data(using: .utf8) else {
            throw DownloadEngineError.processFailed(lastUsefulLine(in: result.output))
        }
        return try JSONDecoder().decode(ProbeResult.self, from: data)
    }

    private func uniqueMP4URL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(stem).mp4")
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-h264-vt-\(index).mp4")
            index += 1
        }
        return candidate
    }

    private func uniqueURL(for sourceURL: URL, extension fileExtension: String) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(stem).\(fileExtension)")
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-\(index).\(fileExtension)")
            index += 1
        }
        return candidate
    }

    private func lastUsefulLine(in output: String) -> String {
        ProcessFailureSummary.lastUsefulLine(in: output)
    }
}

private struct ProbeResult: Decodable {
    let streams: [ProbeStream]
}

private struct ProbeStream: Decodable {
    let codecName: String?
    let codecType: String?

    enum CodingKeys: String, CodingKey {
        case codecName = "codec_name"
        case codecType = "codec_type"
    }
}
