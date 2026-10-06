import SwiftUI

struct StorageSettingsCard: View {
    @ObservedObject var manager: DownloadManager

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        SettingsCard(
            title: t("downloadLocation", "Download location"),
            subtitle: t("downloadLocationSub", "Where downloaded video, audio, and images are saved")
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentGradient)
                        .frame(width: 34, height: 34)
                        .background(AppSurface(cornerRadius: 10, level: .control))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("currentLocation", "Current location"))
                            .font(.caption.weight(.semibold))
                        Text(manager.downloadFolder)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        if let temporaryFolder = manager.sessionDownloadFolder {
                            Label(
                                t("temporaryForSession", "Temporary for this session") + " · " + temporaryFolder,
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Button {
                        manager.openDownloadFolder()
                    } label: {
                        Label(t("openFolder", "Open Folder"), systemImage: "folder.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        manager.chooseDownloadFolder()
                    } label: {
                        Label(t("changeLocation", "Change Location"), systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
