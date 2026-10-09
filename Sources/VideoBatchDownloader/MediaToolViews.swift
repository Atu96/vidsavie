import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaToolWindowShell<Content: View>: View {
    @ObservedObject var manager: DownloadManager
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                ZStack {
                    AppSurface(cornerRadius: 13, level: .control, tint: color)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("FFmpeg · Apple Silicon")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppSurface(cornerRadius: 16, level: .control))
            }
            .padding(18)
            .background(Color.primary.opacity(0.018))

            Divider()
            ScrollView {
                content
                    .padding(20)
            }
        }
        .frame(minWidth: 668, idealWidth: 728, minHeight: 608, idealHeight: 688)
        .background(windowBackground)
        .preferredColorScheme(preferredColorScheme)
        .environment(\.colorScheme, effectiveColorScheme)
        .background(MediaToolWindowCenteringView(title: title, theme: manager.visualTheme))
    }

    private var windowBackground: some View { AppVisual.background(theme: manager.visualTheme) }

    private var preferredColorScheme: ColorScheme? {
        AppAppearance.preferredColorScheme(for: manager.visualTheme)
    }

    private var effectiveColorScheme: ColorScheme {
        AppAppearance.colorScheme(for: manager.visualTheme)
    }
}

struct MediaToolCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppSurface(cornerRadius: VBDDesign.radiusCard, level: .raised))
    }
}

struct MediaFileDropZone: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    let onFiles: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppSurface(cornerRadius: 13, level: .inset, tint: isTargeted ? color : nil))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(color.opacity(isTargeted ? 0.78 : 0.30), style: StrokeStyle(lineWidth: 1.1, dash: [5, 4]))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { onFiles([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
}

struct MediaToolRunPanel: View {
    @ObservedObject var runner: MediaToolRunner
    let actionTitle: String
    let actionSymbol: String
    let actionColor: Color
    let canRun: Bool
    let run: () -> Void

    var body: some View {
        VStack(spacing: 11) {
            if runner.isRunning {
                HStack {
                    ProgressView(value: runner.progress)
                        .tint(actionColor)
                    Text("\(Int(runner.progress * 100))%")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .frame(width: 42)
                    Button("Stop", role: .destructive) { runner.cancel() }
                        .buttonStyle(AppSecondaryButtonStyle(tint: .red))
                }
                Text(runner.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    Button(action: run) {
                        Label(actionTitle, systemImage: actionSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle(tint: actionColor))
                    .disabled(!canRun)

                    if !runner.outputs.isEmpty {
                        Button {
                            runner.revealLastOutput()
                        } label: {
                            Label("Show Output", systemImage: "folder.fill")
                        }
                        .buttonStyle(AppSecondaryButtonStyle(tint: .blue))
                    }
                }
            }

            if !runner.logLines.isEmpty {
                DisclosureGroup("Activity") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(runner.logLines.suffix(80).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 130)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}

struct SelectedFileRow: View {
    let url: URL
    var remove: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(accentGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let remove {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
                .accessibilityLabel("Remove \(url.lastPathComponent)")
            }
        }
        .padding(10)
        .background(AppSurface(cornerRadius: 11, level: .inset))
    }
}

private struct MediaToolWindowCenteringView: NSViewRepresentable {
    let title: String
    let theme: String

    final class Coordinator {
        var centered = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(view.window, coordinator: context.coordinator)
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        WindowActivationCoordinator.shared.register(window)
        window.appearance = AppAppearance.windowAppearance(for: theme)
        window.title = title
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 668, height: 608)
        guard !coordinator.centered else { return }
        coordinator.centered = true
        window.center()
        WindowActivationCoordinator.shared.bringToFront(window)
    }
}
