import AppKit
import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var manager: DownloadManager
    var body: some View {
        AppSettingsView(manager: manager)
            .frame(minWidth: 860, idealWidth: 860, minHeight: 760, idealHeight: 760)
            .background(windowBackground)
            .preferredColorScheme(preferredColorScheme)
            .environment(\.colorScheme, effectiveColorScheme)
            .background(WindowCenteringView(theme: manager.visualTheme))
    }

    private var windowBackground: some View { AppVisual.background(theme: manager.visualTheme) }

    private var preferredColorScheme: ColorScheme? {
        AppAppearance.preferredColorScheme(for: manager.visualTheme)
    }

    private var effectiveColorScheme: ColorScheme {
        AppAppearance.colorScheme(for: manager.visualTheme)
    }
}

private struct WindowCenteringView: NSViewRepresentable {
    let theme: String

    final class Coordinator {
        var centered = false
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
        configure(view.window, coordinator: context.coordinator)
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        WindowActivationCoordinator.shared.register(window)
        window.appearance = AppAppearance.windowAppearance(for: theme)
        window.title = "VidSavie"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.remove(.fullSizeContentView)
        switch AppAppearance.colorScheme(for: theme) {
        case .dark:
            window.backgroundColor = NSColor(calibratedRed: 0.045, green: 0.064, blue: 0.112, alpha: 1)
        default:
            window.backgroundColor = NSColor(calibratedRed: 0.965, green: 0.978, blue: 0.995, alpha: 1)
        }
        window.isOpaque = true
        window.toolbar?.isVisible = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 760)
        guard !coordinator.centered else { return }
        coordinator.centered = true
        window.setContentSize(NSSize(width: 860, height: 760))
        window.center()
        WindowActivationCoordinator.shared.bringToFront(window)
    }
}
