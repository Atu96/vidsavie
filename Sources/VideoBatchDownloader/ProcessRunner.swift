import Foundation

struct ProcessResult {
    let status: Int32
    let output: String
}

private final class ProcessOutputCollector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "VideoBatchDownloader.ProcessOutput")
    private var buffer = ""
    private var completeOutput = ""
    private let onLine: ((String) -> Void)?

    init(onLine: ((String) -> Void)?) {
        self.onLine = onLine
    }

    func consume(_ text: String, flush: Bool = false) {
        queue.sync {
            completeOutput += text
            // yt-dlp frequently redraws progress with carriage returns, while
            // FFmpeg's machine protocol uses newlines. Normalize both so live
            // callbacks are delivered before the process exits.
            buffer += text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            var parts = buffer.components(separatedBy: "\n")
            buffer = flush ? "" : parts.removeLast()
            for line in parts where !line.isEmpty { onLine?(line) }
            if flush, !buffer.isEmpty {
                onLine?(buffer)
                buffer = ""
            }
        }
    }

    var output: String { queue.sync { completeOutput } }
}

final class ProcessRunner {
    func run(
        executable: String,
        arguments: [String],
        environmentOverrides: [String: String] = [:],
        onProcess: ((Process) -> Void)? = nil,
        onLine: ((String) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            let outputCollector = ProcessOutputCollector(onLine: onLine)
            let errorCollector = ProcessOutputCollector(onLine: onLine)

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            environment.merge(environmentOverrides) { _, override in override }
            process.environment = environment

            standardOutput.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                outputCollector.consume(text)
            }
            standardError.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                errorCollector.consume(text)
            }

            process.terminationHandler = { terminated in
                standardOutput.fileHandleForReading.readabilityHandler = nil
                standardError.fileHandleForReading.readabilityHandler = nil
                let remainingOutputs = [
                    (standardOutput.fileHandleForReading.readDataToEndOfFile(), outputCollector),
                    (standardError.fileHandleForReading.readDataToEndOfFile(), errorCollector),
                ]
                for (data, collector) in remainingOutputs {
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        collector.consume(text)
                    }
                    collector.consume("", flush: true)
                }
                continuation.resume(
                    returning: ProcessResult(
                        status: terminated.terminationStatus,
                        output: [outputCollector.output, errorCollector.output]
                            .filter { !$0.isEmpty }
                            .joined(separator: "\n")
                    )
                )
            }

            do {
                try process.run()
                onProcess?(process)
            } catch {
                standardOutput.fileHandleForReading.readabilityHandler = nil
                standardError.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
