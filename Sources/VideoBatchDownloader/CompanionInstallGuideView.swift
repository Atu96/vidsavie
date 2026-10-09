import AppKit
import SwiftUI

struct CompanionInstallGuideWindowView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CompanionInstallGuideView(manager: manager) {
            dismiss()
        }
        .background(CompanionGuideWindowAccessor())
    }
}

private struct CompanionGuideWindowAccessor: NSViewRepresentable {
    final class Coordinator {
        var configured = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        if let window { WindowActivationCoordinator.shared.register(window) }
        guard let window, !coordinator.configured else { return }
        coordinator.configured = true
        window.title = "Install Chrome Companion"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        WindowActivationCoordinator.shared.bringToFront(window)
    }
}

struct CompanionInstallGuideView: View {
    @ObservedObject var manager: DownloadManager
    let close: () -> Void

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(accentGradient, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("installChromeGuide", "Install Chrome Companion"))
                        .font(.title3.bold())
                    Text(t("installChromeGuideSub", "Two quick steps — no command line required"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            InstallGuideAnimation()

            HStack(alignment: .top, spacing: 18) {
                guideStep(
                    number: "1",
                    title: t("enableDeveloperMode", "Enable Developer mode"),
                    detail: t("enableDeveloperModeDetail", "Use the switch at the top-right of Chrome Extensions")
                )
                guideStep(
                    number: "2",
                    title: t("dragExtensionFolder", "Drag the extension folder"),
                    detail: t("dragExtensionFolderDetail", "Drag ChromeExtension from Finder into the Extensions tab")
                )
            }

            HStack {
                Button {
                    manager.installChromeCompanion()
                } label: {
                    Label(t("openAgain", "Open Chrome & Finder Again"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(t("gotIt", "Got It"), action: close)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 390)
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

private struct InstallGuideAnimation: View {
    @State private var phase = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.20),
                            Color(red: 0.13, green: 0.08, blue: 0.24),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            browserWindow
                .frame(width: 300, height: 142)
                .offset(x: 140, y: 15)

            finderFolder
                .offset(
                    x: phase >= 2 ? 282 : 32,
                    y: phase >= 2 ? 70 : 108
                )
                .scaleEffect(phase == 2 ? 1.08 : 1)
                .opacity(phase == 3 ? 0 : 1)
                .shadow(color: .blue.opacity(0.4), radius: phase >= 2 ? 10 : 3, y: 4)

            if phase == 3 {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.green)
                    .offset(x: 323, y: 72)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10)))
        .animation(.spring(response: 0.62, dampingFraction: 0.78), value: phase)
        .task {
            while !Task.isCancelled {
                await setPhase(0, after: 250_000_000)
                await setPhase(1, after: 900_000_000)
                await setPhase(2, after: 900_000_000)
                await setPhase(3, after: 850_000_000)
                try? await Task.sleep(nanoseconds: 1_100_000_000)
            }
        }
    }

    private var browserWindow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 7, height: 7)
                Circle().fill(.yellow).frame(width: 7, height: 7)
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("chrome://extensions")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 9).frame(height: 25)
            .background(Color.white.opacity(0.09))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Extensions")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Developer mode")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Capsule()
                        .fill(phase >= 1 ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 29, height: 16)
                        .overlay(alignment: phase >= 1 ? .trailing : .leading) {
                            Circle().fill(.white).frame(width: 12, height: 12).padding(2)
                        }
                        .shadow(color: phase >= 1 ? .blue.opacity(0.7) : .clear, radius: 7)
                }

                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        phase >= 2 ? Color.blue : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: phase >= 2 ? 2 : 1, dash: [5])
                    )
                    .frame(height: 65)
                    .overlay {
                        Text(phase >= 2 ? "Drop to install" : "Extension area")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(phase >= 2 ? Color.blue : Color.white.opacity(0.4))
                    }
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.12)))
    }

    private var finderFolder: some View {
        VStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.system(size: 34))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                )
            Text("ChromeExtension")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func setPhase(_ newPhase: Int, after nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
        guard !Task.isCancelled else { return }
        phase = newPhase
    }
}
