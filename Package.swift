// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoBatchDownloader",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VideoBatchDownloader", targets: ["VideoBatchDownloader"]),
    ],
    targets: [
        .executableTarget(name: "VideoBatchDownloader"),
    ],
    swiftLanguageModes: [.v5]
)
