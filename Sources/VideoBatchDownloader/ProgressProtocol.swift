import Foundation

enum ProcessFailureSummary {
    static func lastUsefulLine(in output: String) -> String {
        let lines = output.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("TITLE:")
                    && !line.hasPrefix("TARGET:")
                    && !line.hasPrefix("FILE:")
                    && !line.hasPrefix("PROGRESS:")
            }
        if let explicitError = lines.last(where: { line in
            let normalized = line.lowercased()
            return normalized.contains("error:")
                || normalized.contains("error opening")
                || normalized.contains("failed")
        }) {
            return explicitError
        }
        return lines.last ?? "Unknown process error"
    }
}

enum DownloadedMediaValidation {
    static func isPlausibleVideo(fileSize: Int64, probeStatus: Int32, probeOutput: String) -> Bool {
        fileSize >= 1_024
            && probeStatus == 0
            && probeOutput.split(whereSeparator: \.isWhitespace).contains("video")
    }
}

/// One normalized progress contract for external tools. UI surfaces consume a
/// 0...1 fraction and never need to know yt-dlp or FFmpeg's text formats.
struct DownloadProgress: Equatable {
    let percent: Double?
    let speed: String
    let eta: String
    let downloadedBytes: Double?
    let totalBytes: Double?
    let bytesPerSecond: Double?

    init(percent: Double?, speed: String, eta: String, downloadedBytes: Double? = nil, totalBytes: Double? = nil, bytesPerSecond: Double? = nil) {
        self.percent = percent
        self.speed = speed
        self.eta = eta
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
    }
}

enum ProgressProtocol {
    static func fraction(percent: Double) -> Double {
        min(max(percent / 100, 0), 1)
    }

    static func fraction(elapsedSeconds: Double, durationSeconds: Double) -> Double? {
        guard elapsedSeconds.isFinite, durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        return min(max(elapsedSeconds / durationSeconds, 0), 1)
    }

    static func ytDlpProgress(from line: String) -> DownloadProgress? {
        let fields = line.hasPrefix("PROGRESS:")
            ? String(line.dropFirst("PROGRESS:".count)).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            : []
        if fields.count >= 5, let downloaded = byteCount(fields[0]) {
            let total = fields.dropFirst().prefix(2).compactMap(byteCount).first
            return DownloadProgress(
                percent: total.map { min(max(downloaded / $0 * 100, 0), 100) },
                speed: fields[3].trimmingCharacters(in: .whitespaces),
                eta: fields[4].trimmingCharacters(in: .whitespaces),
                downloadedBytes: downloaded,
                totalBytes: total,
                bytesPerSecond: fields.count > 5 ? byteCount(fields[5]) : nil
            )
        }
        let percentSource = fields.first ?? line
        guard let percent = percentage(in: percentSource) else { return nil }
        return DownloadProgress(
            percent: percent,
            speed: fields.count > 1 ? fields[1].trimmingCharacters(in: .whitespaces) : "",
            eta: fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespaces) : ""
        )
    }

    /// FFmpeg's machine protocol emits `out_time_us` / `out_time_ms` rather
    /// than the human `time=` lines used by its legacy stats output.
    static func ffmpegElapsedSeconds(from line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = value(after: "out_time_us=", in: trimmed) ?? value(after: "out_time_ms=", in: trimmed),
           let microseconds = Double(value), microseconds.isFinite {
            return max(0, microseconds / 1_000_000)
        }
        if let value = value(after: "out_time=", in: trimmed) ?? value(after: "time=", in: trimmed) {
            return clockSeconds(value)
        }
        return nil
    }

    private static func percentage(in text: String) -> Double? {
        guard let percentRange = text.range(of: "%") else { return nil }
        let prefix = text[..<percentRange.lowerBound]
        let token = prefix.split(whereSeparator: { !$0.isNumber && $0 != "." }).last
        guard let token, let value = Double(token), value.isFinite else { return nil }
        return min(max(value, 0), 100)
    }

    private static func byteCount(_ value: String) -> Double? {
        guard let value = Double(value.trimmingCharacters(in: .whitespaces)), value.isFinite, value >= 0 else { return nil }
        return value
    }

    static func displayBytes(_ bytes: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(0, bytes)), countStyle: .file)
    }

    private static func value(after marker: String, in line: String) -> String? {
        guard let range = line.range(of: marker) else { return nil }
        return String(line[range.upperBound...].split(whereSeparator: { $0.isWhitespace }).first ?? "")
    }

    private static func clockSeconds(_ value: String) -> Double? {
        let parts = value.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]),
              hours.isFinite, minutes.isFinite, seconds.isFinite else { return nil }
        return max(0, hours * 3600 + minutes * 60 + seconds)
    }
}

/// Measures the effective transfer rate over the most recent full window.
/// This deliberately ignores yt-dlp's lifetime-average speed: a fast initial
/// CDN burst must not hide a later minute of near-stalled transfers.
struct RollingLowSpeedDetector {
    private struct Sample {
        let date: Date
        let downloadedBytes: Double
    }

    let thresholdBytesPerSecond: Double
    let requiredDuration: TimeInterval
    private var samples: [Sample] = []

    init(thresholdBytesPerSecond: Double, requiredDuration: TimeInterval) {
        self.thresholdBytesPerSecond = thresholdBytesPerSecond
        self.requiredDuration = requiredDuration
    }

    mutating func shouldRefresh(downloadedBytes: Double?, now: Date) -> Bool {
        guard let downloadedBytes, downloadedBytes.isFinite, downloadedBytes >= 0 else {
            return false
        }
        if let latest = samples.last, downloadedBytes < latest.downloadedBytes {
            // yt-dlp has moved from the video stream to the audio stream.
            samples.removeAll(keepingCapacity: true)
        }
        samples.append(Sample(date: now, downloadedBytes: downloadedBytes))

        let cutoff = now.addingTimeInterval(-requiredDuration)
        while samples.count > 2, samples[1].date <= cutoff {
            samples.removeFirst()
        }
        guard let oldest = samples.first else { return false }
        let elapsed = now.timeIntervalSince(oldest.date)
        guard elapsed >= requiredDuration else {
            return false
        }
        let transferred = max(0, downloadedBytes - oldest.downloadedBytes)
        return transferred / elapsed < thresholdBytesPerSecond
    }
}

/// yt-dlp downloads the selected high-quality video and audio streams
/// separately. This preserves their real per-stream fraction while presenting
/// one monotonic, whole-job fraction to the menu UI.
struct DownloadTransferProgressAccumulator {
    private let expectedStreamCount: Int
    private var streamIndex = 0
    private var previousFraction: Double = 0
    private var previousDownloadedBytes: Double?

    init(kind: DownloadKind) {
        // The preferred video selector is `bestvideo + bestaudio`; audio and
        // image jobs transfer one source. Fallback progressive video may jump
        // from the first stage to completion, but it never moves backwards.
        expectedStreamCount = kind == .video ? 2 : 1
    }

    mutating func fraction(for update: DownloadProgress) -> Double? {
        let rawFraction = update.percent.map(ProgressProtocol.fraction)
        if shouldAdvanceStream(with: update, rawFraction: rawFraction) {
            streamIndex = min(streamIndex + 1, expectedStreamCount - 1)
            previousFraction = 0
            previousDownloadedBytes = nil
        }

        if let rawFraction {
            previousFraction = rawFraction
        }
        if let downloaded = update.downloadedBytes {
            previousDownloadedBytes = downloaded
        }
        guard let rawFraction else { return nil }
        return min(max((Double(streamIndex) + rawFraction) / Double(expectedStreamCount), 0), 1)
    }

    private func shouldAdvanceStream(with update: DownloadProgress, rawFraction: Double?) -> Bool {
        guard streamIndex < expectedStreamCount - 1 else { return false }
        let resetByFraction = previousFraction >= 0.98 && (rawFraction ?? 0) < 0.35
        let resetByBytes: Bool
        if let previousDownloadedBytes, let downloaded = update.downloadedBytes {
            resetByBytes = previousFraction >= 0.98 && downloaded < previousDownloadedBytes
        } else {
            resetByBytes = false
        }
        return resetByFraction || resetByBytes
    }
}
