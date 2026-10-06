import AppKit
import SwiftUI

private let menuBarStatusIcon: NSImage = {
    let image: NSImage
    if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
       let bundled = NSImage(contentsOf: url) {
        image = bundled
    } else {
        image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "VideoFetch Flow") ?? NSImage()
    }
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true
    return image
}()

@main
struct VideoBatchDownloaderApp: App {
    @NSApplicationDelegateAdaptor(QuitConfirmationDelegate.self) private var quitDelegate
    @StateObject private var manager: DownloadManager

    init() {
        NotificationCoordinator.shared.activate()
        let manager = DownloadManager()
        _manager = StateObject(wrappedValue: manager)
        manager.startServer()
        DispatchQueue.main.async {
            FinderQuickActionSetup.registerServices()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(manager: manager)
        } label: {
            MenuBarStatusLabel(manager: manager)
        }
        .menuBarExtraStyle(.window)

        Window("VideoFetch Flow", id: "settings") {
            SettingsWindowView(manager: manager)
        }
        .defaultSize(width: 820, height: 610)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)

        Window("Install Chrome Companion", id: "chrome-install-guide") {
            CompanionInstallGuideWindowView(manager: manager)
        }
        .defaultSize(width: 480, height: 390)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Finder Quick Actions", id: "finder-quick-actions-guide") {
            FinderQuickActionGuideWindowView(manager: manager)
        }
        .defaultSize(width: 540, height: 430)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Video Cutter", id: "video-cutter") {
            VideoCutterModuleView(manager: manager)
        }
        .defaultSize(width: 728, height: 688)
        .windowResizability(.contentMinSize)

        Window("Media Converter", id: "media-converter") {
            MediaConverterModuleView(manager: manager)
        }
        .defaultSize(width: 728, height: 688)
        .windowResizability(.contentMinSize)

        Window("Audio Mastering", id: "audio-mastering") {
            AudioMasteringModuleView(manager: manager)
        }
        .defaultSize(width: 728, height: 688)
        .windowResizability(.contentMinSize)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject private var quickActions = FinderQuickActionCenter.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: menuBarStatusIcon)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                if manager.isReceivingLink {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange, radius: 3)
                        .offset(x: 5, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
                if manager.activeCount == 0, manager.unseenCompletedCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.green)
                        .offset(x: 3, y: -2)
                }
            }
            if manager.activeCount > 0 {
                Text("\(manager.activeCount)")
                    .font(.caption2.monospacedDigit())
            } else if manager.unseenCompletedCount > 0 {
                Text("\(manager.unseenCompletedCount)")
                    .font(.caption2.monospacedDigit())
            }
        }
        .onAppear(perform: routeQuickAction)
        .onChange(of: quickActions.request?.id) { _ in
            routeQuickAction()
        }
    }

    private func routeQuickAction() {
        guard let request = quickActions.request else { return }
        openWindow(id: request.kind.windowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
