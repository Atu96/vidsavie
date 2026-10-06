import AppKit
import SwiftUI

let brandedAppIcon: NSImage = {
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let image = NSImage(contentsOf: url) { return image }
    return NSImage(named: NSImage.applicationIconName) ?? NSImage()
}()

struct ContentView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.openWindow) private var openWindow
    @State private var pastedLinks = ""
    @State private var quickAddMessage: String?
    @State private var showingHistory = false
    @FocusState private var pasteFieldFocused: Bool

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if showingHistory {
                DownloadHistoryView(manager: manager)
            } else {
                if !manager.supportToolsInstalled { supportToolsBanner }
                if manager.latestCompletedPath != nil { completionBanner }
                if manager.jobs.isEmpty {
                    readyWorkspace
                } else {
                    quickAdd
                    content
                }
            }
            Divider()
            mediaToolDock
        }
        .frame(width: 470, height: 640)
        .background(appBackground)
        .preferredColorScheme(preferredColorScheme)
        .environment(\.colorScheme, effectiveColorScheme)
        .foregroundStyle(Color.primary)
        .onAppear {
            manager.markCompletionsSeen()
            manager.refreshLatestCompletedFile()
            pasteFieldFocused = true
        }
        .task(id: manager.latestCompletedPath) {
            while !Task.isCancelled, manager.latestCompletedPath != nil {
                manager.refreshLatestCompletedFile()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onChange(of: showingHistory) { isShowing in
            if !isShowing { pasteFieldFocused = true }
        }
    }

    private var appBackground: some View { MenuBarGlassCanvas(theme: manager.visualTheme) }

    private var preferredColorScheme: ColorScheme? {
        AppAppearance.preferredColorScheme(for: manager.visualTheme)
    }

    private var effectiveColorScheme: ColorScheme {
        AppAppearance.colorScheme(for: manager.visualTheme)
    }

    private var quickAdd: some View {
        quickAddContent
            .padding(12)
            .background(AppSurface(cornerRadius: 14, level: .control))
            .padding(.horizontal, 14).padding(.bottom, 6)
    }

    private var quickAddContent: some View {
        let isDark = effectiveColorScheme == .dark
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(t("quickAdd", "Quick Add"), systemImage: "link.badge.plus")
                    .font(.caption.weight(.bold))
                Spacer()
                Text(t("pasteAuto", "⌘V one or many links · downloads automatically"))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            TextField(t("bulkLinkPlaceholder", "Paste links here, one per line…"), text: $pastedLinks, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color.primary)
                .lineLimit(2...5)
                .focused($pasteFieldFocused)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(AppSurface(cornerRadius: 12, level: .inset))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            pasteFieldFocused ? VBDDesign.brandBlue.opacity(0.85) : Color.clear,
                            lineWidth: 1.4
                        )
                }
                .shadow(color: Color.black.opacity(isDark ? 0.24 : 0.08), radius: 5, y: 2)
                .overlay(alignment: .topTrailing) {
                    Text("⌘V")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isDark ? Color.white.opacity(0.54) : Color.secondary.opacity(0.70))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.045), in: Capsule())
                        .padding(7)
                }
                .onSubmit(submitPastedLinks)
                .onChange(of: pastedLinks, perform: autoSubmitPastedLinks)

            if let quickAddMessage {
                Text(quickAddMessage).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func autoSubmitPastedLinks(_ value: String) {
        let pastedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipboardValue = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pastedValue.isEmpty, pastedValue == clipboardValue else { return }
        DispatchQueue.main.async {
            guard pastedLinks.trimmingCharacters(in: .whitespacesAndNewlines) == pastedValue else { return }
            submitPastedLinks()
        }
    }

    private func submitPastedLinks() {
        let candidates = pastedLinks
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            .filter { !$0.isEmpty }
        let kind = manager.defaultDownloadKind
        let height = kind == .video ? Int(manager.defaultQuality) : nil
        let accepted = manager.enqueue(candidates.map { EnqueueItem(url: $0, maxHeight: height, kind: kind) })
        let template = t("added", "Added %d items to the queue")
        quickAddMessage = accepted > 0 ? String(format: template, accepted) : t("noLinks", "No new supported links found")
        if accepted > 0 { pastedLinks = "" }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: brandedAppIcon)
                    .resizable().scaledToFit()
                    .frame(width: 42, height: 42)
                    .shadow(color: VBDDesign.brandViolet.opacity(0.18), radius: 7, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("VideoFetch Flow").font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.85)
                    HStack(spacing: 7) {
                        Text("YouTube · Douyin · X · Social")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        connectionBadge
                    }
                }
                .layoutPriority(1)
                Spacer()
                headerIconButton(
                    symbol: showingHistory ? "xmark" : "clock.arrow.circlepath",
                    label: showingHistory ? t("close", "Close") : t("downloadHistory", "Download history"),
                    tint: .cyan
                ) {
                    showingHistory.toggle()
                }
                .overlay(alignment: .topTrailing) {
                    if !showingHistory && !manager.history.isEmpty {
                        Text("\(min(manager.history.count, 99))")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 13, minHeight: 13)
                            .background(accentGradient, in: Circle())
                            .offset(x: 3, y: -2)
                    }
                }
                headerIconButton(symbol: "gearshape", label: t("settings", "Settings"), tint: .indigo) {
                    let menuBarWindow = NSApplication.shared.keyWindow
                    openWindow(id: "settings")
                    menuBarWindow?.orderOut(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                headerIconButton(symbol: "power", label: t("quitApp", "Quit App"), tint: .red, isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }

            if !showingHistory {
                HStack(spacing: 0) {
                    MetricCard(value: manager.activeCount, label: t("active", "Active"), icon: "bolt.fill", color: .blue, compact: true)
                    Divider().frame(height: 24).opacity(0.55)
                    MetricCard(value: manager.queuedCount, label: t("waiting", "Waiting"), icon: "clock.fill", color: .orange, compact: true)
                    Divider().frame(height: 24).opacity(0.55)
                    MetricCard(value: manager.completedCount, label: t("done", "Done"), icon: "checkmark.circle.fill", color: .green, compact: true)
                    Divider().frame(height: 24).opacity(0.55)
                    tipsButton.padding(.horizontal, 8)
                }
                .background(AppSurface(cornerRadius: 12, level: .control))
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.018))
    }

    private var tipsButton: some View {
                Button {
                    NSApplication.shared.keyWindow?.orderOut(nil)
                    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/atu1202")!)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text(t("supportAction", "Support")).foregroundStyle(.primary)
                            .lineLimit(1).fixedSize()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 3).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .help("\(t("supportAction", "Support")) · Ko-fi")
                .accessibilityLabel(t("donateAccessibility", "Donate on Ko-fi (opens in browser)"))
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(manager.serverMessage.contains("connected") ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(manager.serverMessage.contains("connected") ? t("ready", "Ready") : t("starting", "Starting"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(AppSurface(cornerRadius: 12, level: .inset))
        .accessibilityElement(children: .combine)
    }

    private var completionBanner: some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(t("downloadComplete", "Download complete")).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(manager.latestCompletedTitle ?? t("mediaReady", "Your media is ready"))
                    .font(.caption).foregroundStyle(.white.opacity(0.82)).lineLimit(1)
            }
            Spacer()
            Button(t("openFolder", "Open Folder")) {
                NSApplication.shared.keyWindow?.orderOut(nil)
                DispatchQueue.main.async {
                    manager.revealLatestCompleted()
                }
            }
                .buttonStyle(WhiteCapsuleButtonStyle())
        }
        .padding(12)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.65, blue: 0.42), Color(red: 0.06, green: 0.48, blue: 0.68)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 13)
        )
        .padding(.horizontal, 14).padding(.bottom, 8)
    }

    private var supportToolsBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: manager.supportToolsLastUpdateFailed ? "exclamationmark.arrow.triangle.2.circlepath" : "shippingbox.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(manager.supportToolsLastUpdateFailed ? Color.orange : VBDDesign.brandBlue)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(t("supportToolsNeeded", "Keep the downloader up to date"))
                    .font(.caption.weight(.bold))
                if let phase = manager.supportToolsInstallPhase {
                    Text(t(phase.localizationKey, phase.fallbackText))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if manager.supportToolsLastUpdateFailed {
                    Text(t("supportToolsFallback", "The built-in fallback still works; try again when the network is stable."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(t("supportToolsNeededDetail", "One click and the app handles everything"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                manager.scheduleSupportToolsUpdate(force: true)
            } label: {
                if manager.isUpdatingSupportTools {
                    ProgressView().controlSize(.small)
                } else {
                    Text(manager.supportToolsLastUpdateFailed
                        ? t("retrySupportTools", "Try again")
                        : t("installSupportTools", "Install tools"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .buttonStyle(AppCompactPrimaryButtonStyle(tint: manager.supportToolsLastUpdateFailed ? .orange : .blue))
            .disabled(manager.isUpdatingSupportTools)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppSurface(cornerRadius: 13, level: .control))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var content: some View {
        if manager.jobs.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(displayJobs) { job in JobRow(job: job, manager: manager) }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var displayJobs: [DownloadJob] {
        manager.jobs.sorted {
            let left = displayPriority($0.status)
            let right = displayPriority($1.status)
            return left == right ? $0.createdAt < $1.createdAt : left < right
        }
    }

    private func displayPriority(_ status: DownloadStatus) -> Int {
        switch status {
        case .fetching, .downloading, .waitingForGPU, .converting, .convertingAudio: 0
        case .queued: 1
        case .failed, .stopped: 2
        case .completed: 3
        }
    }

    private var readyWorkspace: some View {
        VStack(spacing: 0) {
            quickAddContent
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Divider().opacity(0.42)
            emptyState
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(accentGradient.opacity(0.16)).frame(width: 86, height: 86)
                Image(systemName: "play.square.stack.fill").font(.system(size: 36)).foregroundStyle(accentGradient)
            }
            Text(t("readyWhen", "Ready when you are")).font(.title3.weight(.bold))
            Text(t("emptyHint", "Paste links above or use the floating download button on YouTube, Douyin or X."))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediaToolDock: some View {
        HStack(spacing: 8) {
            mediaToolButton(
                title: t("videoCutter", "Video Cutter"),
                symbol: "scissors",
                color: .blue,
                windowID: "video-cutter"
            )
            mediaToolButton(
                title: t("mediaConverter", "Converter"),
                symbol: "arrow.triangle.2.circlepath",
                color: .purple,
                windowID: "media-converter"
            )
            mediaToolButton(
                title: t("audioMastering", "Audio"),
                symbol: "waveform.badge.mic",
                color: .pink,
                windowID: "audio-mastering"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.018))
    }

    private func mediaToolButton(
        title: String,
        symbol: String,
        color: Color,
        windowID: String
    ) -> some View {
        return Button {
            let menuBarWindow = NSApplication.shared.keyWindow
            openWindow(id: windowID)
            menuBarWindow?.orderOut(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 27, height: 27)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 42)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(AppSurface(cornerRadius: 11, level: .control, tint: color))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func headerIconButton(
        symbol: String,
        label: String,
        tint: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isDestructive ? Color.red : tint)
                .frame(width: VBDDesign.iconButtonSize, height: VBDDesign.iconButtonSize)
                .background(AppSurface(cornerRadius: 19, level: .control, tint: isDestructive ? .red : tint))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

}
