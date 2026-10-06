import AppKit
import SwiftUI

struct FinderQuickActionGuideWindowView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FinderQuickActionGuideView(manager: manager) {
            dismiss()
        }
        .background(FinderGuideWindowAccessor())
    }
}

private struct FinderGuideWindowAccessor: NSViewRepresentable {
    final class Coordinator {
        var configured = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window, !coordinator.configured else { return }
        coordinator.configured = true
        window.title = "Finder Quick Actions"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct FinderQuickActionGuideView: View {
    @ObservedObject var manager: DownloadManager
    let close: () -> Void

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(accentGradient, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("finderGuideTitle", "Enable Finder Quick Actions"))
                        .font(.title3.bold())
                    Text(t("finderGuideSub", "One macOS approval, then use the tools from any Finder window"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            FinderServicesWalkthroughAnimation()

            HStack(alignment: .top, spacing: 12) {
                guideStep(
                    number: "1",
                    title: t("openServicesList", "Click Keyboard Shortcuts… → Services"),
                    detail: t("openServicesListDetail", "System Settings opens Keyboard. Click Keyboard Shortcuts…, then choose Services in the left sidebar.")
                )
                guideStep(
                    number: "2",
                    title: t("expandFilesFolders", "Expand Files and Folders"),
                    detail: t("expandFilesFoldersDetail", "Click the disclosure arrow beside Files and Folders to reveal its service rows.")
                )
                guideStep(
                    number: "3",
                    title: t("enableBatchActions", "Enable the three VideoFetch Flow actions"),
                    detail: t("enableBatchActionsDetail", "Tick the three VideoFetch Flow rows. Their symbols also appear in Finder’s right-click Services menu.")
                )
            }

            HStack {
                Button {
                    FinderQuickActionSetup.openSystemSettings()
                } label: {
                    Label(t("openSystemSettings", "Open Keyboard Shortcuts"), systemImage: "keyboard")
                }
                .buttonStyle(.bordered)

                Button {
                    FinderQuickActionSetup.openFinder()
                } label: {
                    Label(t("openFinder", "Open Finder"), systemImage: "folder.fill")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(t("gotIt", "Got It"), action: close)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func guideStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(accentGradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A code-native, ordered walkthrough mirrors the exact System Settings route.
/// It stays sharp in every appearance mode and does not depend on a brittle GIF.
private struct FinderServicesWalkthroughAnimation: View {
    @State private var phase = 0

    var body: some View {
        Group {
            if phase == 0 {
                keyboardStep
            } else {
                servicesStep
            }
        }
        .frame(height: 192)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), Color.blue.opacity(0.08), Color.pink.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.15)))
        .task { await playChecklist() }
    }

    private var keyboardStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Label("Keyboard Shortcuts…", systemImage: "command")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.accentColor, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .offset(x: 8, y: -9)
                    }
                Spacer()
            }
            Text("1  Click Keyboard Shortcuts…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(14)
    }

    private var servicesStep: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Label("Keyboard", systemImage: "keyboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Label("Services", systemImage: "gearshape.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(alignment: .leading) {
                        if phase == 1 {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                                .offset(x: -12)
                        }
                    }
                Label("Spotlight", systemImage: "magnifyingglass")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 136)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.035))

            VStack(alignment: .leading, spacing: 4) {
                Text(phase == 1 ? "2  Choose Services" : "3  Expand Files and Folders")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 2)
                filesAndFoldersRow
                if phase >= 3 {
                    serviceRow("↻  Convert with VideoFetch Flow", isEnabled: phase >= 4)
                    serviceRow("♫  Master Audio with VideoFetch Flow", isEnabled: phase >= 5)
                    serviceRow("✂︎  Cut Video with VideoFetch Flow", isEnabled: phase >= 6)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var filesAndFoldersRow: some View {
        HStack(spacing: 8) {
            Image(systemName: phase >= 3 ? "chevron.down" : "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Image(systemName: "minus")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 19, height: 19)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 5))
            Text("Files and Folders")
                .font(.caption.weight(.bold))
            Spacer(minLength: 0)
            if phase == 2 {
                Image(systemName: "hand.tap.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 29)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func serviceRow(_ title: String, isEnabled: Bool) -> some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.17))
                if isEnabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 19, height: 19)
            .shadow(color: isEnabled ? Color.accentColor.opacity(0.25) : .clear, radius: 3, y: 1)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(height: 31)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
    }

    private func playChecklist() async {
        while !Task.isCancelled {
            updatePhase(0)
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            updatePhase(1)
            try? await Task.sleep(for: .milliseconds(1050))
            guard !Task.isCancelled else { return }
            updatePhase(2)
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            updatePhase(3)
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            updatePhase(4)
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            updatePhase(5)
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            updatePhase(6)
            try? await Task.sleep(for: .milliseconds(1500))
        }
    }

    private func updatePhase(_ value: Int) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            phase = value
        }
    }
}
