import AppKit

enum CompanionInstaller {
    static func open(browserPath: String, setupURL: String) {
        guard let resourcesFolder = Bundle.main.resourceURL else { return }
        let extensionFolder = resourcesFolder.appendingPathComponent("ChromeExtension")
        guard FileManager.default.fileExists(atPath: extensionFolder.path) else { return }

        let showResourcesFolder = {
            _ = NSWorkspace.shared.open(resourcesFolder)
        }
        guard FileManager.default.fileExists(atPath: browserPath),
              let page = URL(string: setupURL)
        else {
            showResourcesFolder()
            return
        }

        NSWorkspace.shared.open(
            [page],
            withApplicationAt: URL(fileURLWithPath: browserPath),
            configuration: NSWorkspace.OpenConfiguration()
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showResourcesFolder()
        }
    }
}
