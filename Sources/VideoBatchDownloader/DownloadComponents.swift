import SwiftUI

struct MetricCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 5 : 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label).font(.system(size: compact ? 10 : 12, weight: .medium)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 7 : 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct JobRow: View {
    @ObservedObject var job: DownloadJob
    @ObservedObject var manager: DownloadManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copiedLink = false
    @State private var copiedError = false

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            platformIcon
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(job.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 4)
                    statusPill
                }
                progressArea
                if let error = job.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.red).lineLimit(2)
                }
                actionRow
            }
        }
        .padding(12)
        .background { progressGlassBackground }
    }

    private var platformIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(platformColor.opacity(0.14))
            Image(systemName: platformSymbol).foregroundStyle(platformColor).font(.system(size: 16, weight: .bold))
        }
        .frame(width: 38, height: 38)
    }

    private var statusPill: some View {
        Text(statusPillText)
            .font(.system(size: job.status == .downloading && !progressDetail.isEmpty ? 9 : 10, weight: .bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(statusColor.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(statusColor.opacity(0.20), lineWidth: 0.6))
            .fixedSize()
    }

    @ViewBuilder private var progressArea: some View {
        if job.status == .converting || job.status == .waitingForGPU || job.status == .convertingAudio {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(job.status == .converting ? t("gpuOptimizing", "Apple GPU is optimizing compatibility") : (job.status == .convertingAudio ? t("convertingAudio", "Creating MP3") : t("gpuQueue", "GPU queue")))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var progressDetail: String {
        let transferred: String
        if let downloaded = job.downloadedBytes, let total = job.totalBytes {
            transferred = "\(ProgressProtocol.displayBytes(downloaded)) / \(ProgressProtocol.displayBytes(total))"
        } else if let downloaded = job.downloadedBytes {
            transferred = ProgressProtocol.displayBytes(downloaded)
        } else {
            transferred = ""
        }
        return [transferred, job.speed, job.eta.isEmpty ? "" : "ETA \(job.eta)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var statusPillText: String {
        job.status == .downloading && !progressDetail.isEmpty ? progressDetail : localizedStatus
    }

    private var progressGlassBackground: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                AppSurface(cornerRadius: 14, level: .raised)
                if job.status == .downloading || job.status == .fetching {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentGradient.opacity(0.18))
                        .frame(width: max(0, geometry.size.width * job.progress))
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.38))
                                .frame(width: 1)
                                .blur(radius: 1.5)
                        }
                        .animation(VBDDesign.motion(reduceMotion: reduceMotion), value: job.progress)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder private var actionRow: some View {
        if job.status == .failed || job.status == .stopped {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                retryAction
                copyLinkAction
                if job.status == .failed {
                    copyErrorAction
                    if job.browserSessionIssue != nil {
                        SmallAction(title: t("fixSession", "Fix Session"), icon: "person.badge.key.fill", color: .blue, fillsWidth: true) {
                            manager.presentSessionRepair(job)
                        }
                    }
                }
                SmallAction(title: t("delete", "Delete"), icon: "trash.fill", color: .red, fillsWidth: true) {
                    manager.removeRetryableJob(job)
                }
            }
        } else {
            HStack(spacing: 8) {
                if job.status == .queued || job.status.isActive {
                SmallAction(title: t("stop", "Stop"), icon: "stop.fill", color: .red) { manager.stop(job) }
                } else if job.status == .completed {
                    SmallAction(title: t("open", "Open"), icon: "play.fill", color: .green) { manager.open(job) }
                    SmallAction(title: t("show", "Show"), icon: "folder", color: .blue) { manager.reveal(job) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var retryAction: some View {
        let canResume = manager.hasResumableCache(for: job)
        return SmallAction(
            title: canResume ? t("continueDownload", "Continue") : t("retry", "Retry"),
            icon: canResume ? "play.fill" : "arrow.clockwise",
            color: .orange,
            fillsWidth: true
        ) { manager.retry(job) }
    }

    private var copyLinkAction: some View {
        SmallAction(
            title: copiedLink ? t("linkCopied", "Copied") : t("copyLink", "Copy link"),
            icon: copiedLink ? "checkmark" : "link",
            color: copiedLink ? .green : .blue,
            fillsWidth: true
        ) {
            copiedLink = manager.copyLink(job)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                copiedLink = false
            }
        }
    }

    private var copyErrorAction: some View {
        SmallAction(
            title: copiedError ? t("errorCopied", "Error copied") : t("copyError", "Copy error"),
            icon: copiedError ? "checkmark" : "doc.on.doc",
            color: copiedError ? .green : .red,
            fillsWidth: true
        ) {
            copiedError = manager.copyErrorReport(job)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                copiedError = false
            }
        }
    }

    private var platformColor: Color {
        if URLNormalizer.isDouyin(job.normalizedURL) { return .pink }
        if URLNormalizer.isX(job.normalizedURL) { return .primary }
        if URLNormalizer.isFacebook(job.normalizedURL) { return .blue }
        if URLNormalizer.isInstagram(job.normalizedURL) { return .purple }
        if URLNormalizer.isGoogleImage(job.normalizedURL) { return .cyan }
        return .red
    }

    private var platformSymbol: String {
        if URLNormalizer.isDouyin(job.normalizedURL) { return "music.note" }
        if URLNormalizer.isX(job.normalizedURL) { return "xmark" }
        if URLNormalizer.isFacebook(job.normalizedURL) { return "f.circle.fill" }
        if URLNormalizer.isInstagram(job.normalizedURL) { return "camera.fill" }
        if job.kind == .image { return "photo.fill" }
        return "play.fill"
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: .green
        case .failed: .red
        case .stopped: .secondary
        case .waitingForGPU, .converting: .purple
        case .queued: .orange
        default: .blue
        }
    }

    private var localizedStatus: String {
        switch job.status {
        case .queued: t("queued", "Waiting")
        case .fetching: t("downloading", "Downloading") + "..."
        case .downloading: t("downloading", "Downloading")
        case .waitingForGPU: t("gpuQueue", "Waiting for GPU")
        case .converting: t("convertingVideo", "Converting video with GPU")
        case .convertingAudio: t("convertingAudio", "Creating MP3")
        case .completed: t("completed", "Completed")
        case .failed: t("failed", "Failed")
        case .stopped: t("stopped", "Stopped")
        }
    }
}

struct SmallAction: View {
    let title: String
    let icon: String
    let color: Color
    var fillsWidth = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
            .buttonStyle(AppSecondaryButtonStyle(tint: color))
            .help(title)
            .accessibilityLabel(title)
    }
}

struct WhiteCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold)).foregroundStyle(Color.black.opacity(0.78))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.75 : 0.95), in: Capsule())
    }
}
