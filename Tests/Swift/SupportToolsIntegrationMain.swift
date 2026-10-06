import Foundation

// Opt-in integration experiment: network/tool downloads only, no media or cookies.
// Always uses an explicitly supplied isolated directory, never user tools.
@main
struct SupportToolsIntegrationMain {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Supply an isolated temporary root") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        guard root.path.hasPrefix("/private/tmp/VidSavieInstallerTest."), !FileManager.default.fileExists(atPath: root.appendingPathComponent("Tools").path) else {
            fatalError("Refusing a non-isolated or existing tool directory")
        }
        let tools = root.appendingPathComponent("Tools", isDirectory: true)
        let installer = SupportToolsInstaller(toolsDirectory: tools)
        let first = try await installer.installOrUpdate { print($0.fallbackText); fflush(stdout) }
        guard first.ffmpegVersion == "9.0.2", first.ffprobeVersion == "9.0.2",
              SupportToolsInstaller.hasManagedTools(toolsDirectory: tools),
              ReviewedMediaPolicy.isReviewedDirectory(tools) else { fatalError("Activation did not match reviewed profile") }
        let second = try await installer.installOrUpdate()
        guard first == second else { fatalError("Idempotent update changed installed tools") }
        let source = tools.appendingPathComponent("ThirdParty/media-9.0.2-v1-sources.tar.gz")
        try Data([0]).write(to: source) // Corrupt only this generated, isolated fixture.
        let recovered = try await installer.installOrUpdate { print($0.fallbackText); fflush(stdout) }
        guard recovered == first, (try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 1 else {
            fatalError("Corrupted source archive did not recover safely")
        }
        print("Isolated managed install, source retention, version check, reuse and corrupt-source recovery: OK")
        print("Fixture: \(root.path)")
    }
}
