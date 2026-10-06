import AppKit
import Combine

struct FinderQuickActionRequest: Identifiable {
    let id = UUID()
    let kind: FinderQuickActionKind
    let urls: [URL]
}

@MainActor
final class FinderQuickActionCenter: ObservableObject {
    static let shared = FinderQuickActionCenter()

    @Published private(set) var request: FinderQuickActionRequest?

    func submit(kind: FinderQuickActionKind, urls: [URL]) {
        let accepted = urls
            .map(\.standardizedFileURL)
            .filter { $0.isFileURL && kind.accepts($0) }
        guard !accepted.isEmpty else { return }
        request = FinderQuickActionRequest(kind: kind, urls: accepted)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func consume(_ id: UUID) {
        guard request?.id == id else { return }
        request = nil
    }
}

final class FinderQuickActionService: NSObject {
    static let shared = FinderQuickActionService()

    func register() {
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc func cutVideo(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        submit(.cutVideo, from: pasteboard, error: error)
    }

    @objc func convertMedia(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        submit(.convertMedia, from: pasteboard, error: error)
    }

    @objc func masterAudio(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        submit(.masterAudio, from: pasteboard, error: error)
    }

    private func submit(
        _ kind: FinderQuickActionKind,
        from pasteboard: NSPasteboard,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let objects = (pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL]) ?? []
        let urls = objects.map { $0 as URL }
        guard !urls.isEmpty else {
            error.pointee = "No supported Finder files were provided."
            return
        }
        Task { @MainActor in
            FinderQuickActionCenter.shared.submit(kind: kind, urls: urls)
        }
    }
}

enum FinderQuickActionSetup {
    static func registerServices() {
        FinderQuickActionService.shared.register()
    }

    static func openSystemSettings() {
        NSUpdateDynamicServices()
        let candidates = [
            // KeyboardSettings declares this route as lowercase `services`.
            // The query is case-sensitive; `Services` is silently ignored.
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?services",
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts",
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.keyboard",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func openFinder() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
    }
}
