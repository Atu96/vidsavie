import AppKit
import Foundation

@MainActor
final class MediaToolRunner: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progress = 0.0
    @Published private(set) var status = ""
    @Published private(set) var logLines: [String] = []
    @Published private(set) var outputs: [URL] = []

    private let runner = ProcessRunner()
    private var process: Process?
    private var wasCancelled = false
    private var revealOutputAsDirectory = false

    func execute(_ commands: [MediaToolCommand]) async throws {
        guard !commands.isEmpty else { throw MediaToolError.noInput }
        guard let ffmpeg = MediaBinaryLocator.ffmpeg() else { throw MediaToolError.ffmpegMissing }

        isRunning = true
        wasCancelled = false
        progress = 0
        logLines = []
        outputs = []
        revealOutputAsDirectory = false
        defer {
            process = nil
            isRunning = false
        }

        let batchPlan = commands.compactMap(\.batchSegmentRenamePlan).first
        for (index, command) in commands.enumerated() {
            guard !wasCancelled else { break }
            status = command.label
            appendLog("[\(index + 1)/\(commands.count)] \(command.label)")
            let duration = await probeDuration(command.inputURL)
            let result = try await runner.run(
                executable: ffmpeg,
                arguments: command.arguments,
                onProcess: { [weak self] process in
                    Task { @MainActor in self?.process = process }
                },
                onLine: { [weak self] line in
                    Task { @MainActor in
                        guard let self else { return }
                        self.appendLog(line)
                        guard let elapsed = ProgressProtocol.ffmpegElapsedSeconds(from: line),
                              let localProgress = ProgressProtocol.fraction(elapsedSeconds: elapsed, durationSeconds: duration) else { return }
                        self.progress = (Double(index) + localProgress) / Double(commands.count)
                    }
                }
            )
            guard !wasCancelled else { break }
            guard result.status == 0 else {
                throw MediaToolError.processFailed(Self.lastUsefulLine(result.output))
            }
            if let plan = command.segmentRenamePlan, batchPlan == nil {
                try finalizeSegments(using: plan)
            }
            outputs.append(command.outputURL)
            revealOutputAsDirectory = command.revealsDirectory
            progress = Double(index + 1) / Double(commands.count)
        }
        if !wasCancelled, let batchPlan {
            try finalizeBatchSegments(using: batchPlan)
        }
        status = wasCancelled ? "Stopped" : "Completed"
    }

    func cancel() {
        wasCancelled = true
        process?.terminate()
        process = nil
        status = "Stopped"
    }

    func revealLastOutput() {
        guard let output = outputs.last else { return }
        if revealOutputAsDirectory {
            NSWorkspace.shared.open(output)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }
    }

    private func probeDuration(_ url: URL) async -> Double {
        guard let ffprobe = MediaBinaryLocator.ffprobe() else { return 0 }
        guard let result = try? await runner.run(executable: ffprobe, arguments: [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path,
        ]), result.status == 0 else { return 0 }
        return Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func appendLog(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logLines.append(trimmed)
        if logLines.count > 300 {
            logLines.removeFirst(logLines.count - 300)
        }
    }

    private func finalizeSegments(using plan: SegmentRenamePlan) throws {
        let fileManager = FileManager.default
        let temporaryFiles = try fileManager.contentsOfDirectory(
            at: plan.outputDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix(plan.temporaryPrefix) && $0.pathExtension.lowercased() == "mp4" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !temporaryFiles.isEmpty else {
            throw MediaToolError.processFailed("Video segments were not created.")
        }

        let orderedFiles = plan.arrangement == .creativeRandom ? temporaryFiles.shuffled() : temporaryFiles
        for (index, source) in orderedFiles.enumerated() {
            let baseName = plan.filename(for: index, totalSegments: temporaryFiles.count)
            var destination = plan.outputDirectory.appendingPathComponent("\(baseName).mp4")
            var collision = 2
            while fileManager.fileExists(atPath: destination.path) {
                destination = plan.outputDirectory.appendingPathComponent("\(baseName)-\(collision).mp4")
                collision += 1
            }
            try fileManager.moveItem(at: source, to: destination)
            appendLog("Created: \(destination.lastPathComponent)")
        }
    }

    private func finalizeBatchSegments(using plan: BatchSegmentRenamePlan) throws {
        let fileManager = FileManager.default
        var perSource: [[URL]] = []
        for source in plan.sources {
            let clips = try fileManager.contentsOfDirectory(at: plan.outputDirectory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix(source.temporaryPrefix) && $0.pathExtension.lowercased() == "mp4" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !clips.isEmpty else { throw MediaToolError.processFailed("Video segments were not created.") }
            perSource.append(plan.arrangement == .sequential ? clips : clips.shuffled())
        }
        if plan.arrangement == .randomSourceMix {
            try finalizeRandomSourceMix(perSource, using: plan, fileManager: fileManager)
            return
        }
        var globalIndex = 0
        var clipIndex = 0
        while perSource.contains(where: { clipIndex < $0.count }) {
            for sourceIndex in perSource.indices where clipIndex < perSource[sourceIndex].count {
                let source = perSource[sourceIndex][clipIndex]
                let baseName = plan.fileName(for: globalIndex, sourceIndex: sourceIndex)
                var destination = plan.outputDirectory.appendingPathComponent("\(baseName).mp4")
                var collision = 2
                while fileManager.fileExists(atPath: destination.path) {
                    destination = plan.outputDirectory.appendingPathComponent("\(baseName)-\(collision).mp4")
                    collision += 1
                }
                try fileManager.moveItem(at: source, to: destination)
                appendLog("Created: \(destination.lastPathComponent)")
                globalIndex += 1
            }
            clipIndex += 1
        }
    }

    private func finalizeRandomSourceMix(_ queues: [[URL]], using plan: BatchSegmentRenamePlan, fileManager: FileManager) throws {
        var queues = queues
        var lastSource: Int?
        var globalIndex = 0
        while queues.contains(where: { !$0.isEmpty }) {
            let available = queues.indices.filter { !queues[$0].isEmpty }
            let candidates = available.filter { $0 != lastSource }
            guard let sourceIndex = (candidates.isEmpty ? available : candidates).randomElement() else { break }
            let source = queues[sourceIndex].removeFirst()
            let baseName = plan.fileName(for: globalIndex, sourceIndex: sourceIndex)
            var destination = plan.outputDirectory.appendingPathComponent("\(baseName).mp4")
            var collision = 2
            while fileManager.fileExists(atPath: destination.path) {
                destination = plan.outputDirectory.appendingPathComponent("\(baseName)-\(collision).mp4")
                collision += 1
            }
            try fileManager.moveItem(at: source, to: destination)
            appendLog("Created: \(destination.lastPathComponent)")
            lastSource = sourceIndex
            globalIndex += 1
        }
    }

    private static func lastUsefulLine(_ output: String) -> String {
        output.split(separator: "\n")
            .map(String.init)
            .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? "FFmpeg failed."
    }
}
