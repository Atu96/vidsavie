import AppKit

/// Visible working windows participate in Dock/Cmd-Tab; the menu-bar panel
/// alone does not. Never quit, stop work, or steal focus on a theme update.
@MainActor
final class WindowActivationCoordinator {
    static let shared = WindowActivationCoordinator()
    @MainActor private final class Entry {
        weak var window: NSWindow?
        var closed = false
        var visibility: NSKeyValueObservation?
        init(_ window: NSWindow) { self.window = window }
    }
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let window = notification.object as? NSWindow else { return }
                MainActor.assumeIsolated {
                    guard let self, let entry = self.entries[ObjectIdentifier(window)] else { return }
                    if name == NSWindow.willCloseNotification { entry.closed = true }
                    if name == NSWindow.didBecomeKeyNotification {
                        entry.closed = false
                        if NSApp.activationPolicy() != .regular {
                            self.bringToFront(window)
                            return
                        }
                    }
                    self.reconcile()
                }
            })
        }
    }

    func register(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard entries[id] == nil else { return }
        let entry = Entry(window)
        entries[id] = entry
        entry.visibility = window.observe(\.isVisible, options: [.new]) { [weak self, weak entry] window, _ in
            DispatchQueue.main.async {
                if window.isVisible { entry?.closed = false }
                self?.reconcile()
            }
        }
    }

    func bringToFront(_ window: NSWindow) {
        register(window)
        entries[ObjectIdentifier(window)]?.closed = false
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Activation-policy registration can complete on the next run loop.
        DispatchQueue.main.async { [weak window] in
            guard let window, window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func reconcile() {
        entries = entries.filter { $0.value.window != nil }
        let hasWorkingWindow = entries.values.contains { entry in
            guard let window = entry.window, !entry.closed else { return false }
            return window.isVisible || window.isMiniaturized
        }
        let desired: NSApplication.ActivationPolicy = hasWorkingWindow ? .regular : .accessory
        if NSApp.activationPolicy() != desired { NSApp.setActivationPolicy(desired) }
    }
}
