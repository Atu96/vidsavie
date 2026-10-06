import SwiftUI

struct DownloadHistoryView: View {
    @ObservedObject var manager: DownloadManager

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label(t("downloadHistory", "Download history"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Text("\(manager.history.count)")
                    .font(.caption2.bold()).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(AppSurface(cornerRadius: 14, level: .control))
                Spacer()
                if !manager.history.isEmpty {
                    Button(role: .destructive) { manager.clearHistory() } label: {
                        Label(t("clearHistory", "Clear history"), systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            }
            .padding(.horizontal, 15).padding(.top, 4)

            if manager.history.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(accentGradient.opacity(0.11)).frame(width: 78, height: 78)
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 31)).foregroundStyle(accentGradient)
                    }
                    Text(t("historyEmpty", "No downloads yet")).font(.headline)
                    Text(t("historyEmptyHint", "Completed media will appear here."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(manager.history) { item in
                            DownloadHistoryRow(item: item, manager: manager)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct DownloadHistoryRow: View {
    let item: DownloadHistoryItem
    @ObservedObject var manager: DownloadManager

    private var fileExists: Bool { manager.historyFileExists(item) }
    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(platformColor.opacity(0.13))
                Image(systemName: item.kind == .image ? "photo.fill" : (item.kind == .audio ? "waveform" : "play.fill"))
                    .foregroundStyle(platformColor).font(.system(size: 15, weight: .bold))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Text(item.completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 3)
                    Text(fileExists ? t("fileReady", "Available") : t("fileMissing", "File missing"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(fileExists ? Color.green : Color.orange)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background((fileExists ? Color.green : Color.orange).opacity(0.11), in: Capsule())
                        .fixedSize()
                }

                HStack(spacing: 12) {
                    if fileExists {
                        SmallAction(title: t("open", "Open"), icon: "play.fill", color: .green) {
                            manager.openHistoryItem(item)
                        }
                        SmallAction(title: t("showInFinder", "Show in Finder"), icon: "folder", color: .blue) {
                            manager.revealHistoryItem(item)
                        }
                    } else {
                        SmallAction(title: t("redownload", "Download again"), icon: "arrow.clockwise", color: .orange) {
                            manager.redownload(item)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) { manager.removeHistoryItem(item) } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold)).frame(width: 25, height: 25)
                            .background(Color.red.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain).help(t("deleteHistoryItem", "Remove from history"))
                }
            }
        }
        .padding(11)
        .background(AppSurface(cornerRadius: 14, level: .raised))
    }

    private var platformColor: Color {
        if URLNormalizer.isDouyin(item.normalizedURL) { return .pink }
        if URLNormalizer.isX(item.normalizedURL) { return .primary }
        if URLNormalizer.isFacebook(item.normalizedURL) { return .blue }
        if URLNormalizer.isInstagram(item.normalizedURL) { return .purple }
        if URLNormalizer.isGoogleImage(item.normalizedURL) { return .cyan }
        return item.kind == .audio ? .purple : .red
    }
}
