import CryptoKit
import Foundation

struct SupportToolsReleaseManifest: Equatable, Sendable {
    let ytDlpURL: URL
    let ytDlpChecksum: String
    let ffmpegURL: URL
    let ffmpegChecksum: String
    let ffmpegVersion: String
    let ffprobeURL: URL
    let ffprobeChecksum: String
    let ffprobeVersion: String
    let mediaArchiveChecksum: String
    let mediaPackageID: String
    let mediaSourceURL: URL
    let mediaSourceChecksum: String
}

struct SupportToolsMetadata: Codable, Equatable, Sendable {
    let ytDlpChecksum: String
    let ffmpegChecksum: String
    let ffprobeChecksum: String
    let installedYtDlpChecksum: String
    let installedFFmpegChecksum: String
    let installedFFprobeChecksum: String
    let ffmpegVersion: String
    let ffprobeVersion: String
    let updatedAt: Date
    let mediaPackageID: String?
    let mediaSourceURL: String?
    let mediaSourceChecksum: String?
}

struct SupportToolsSnapshot: Equatable, Sendable {
    let ytDlpVersion: String
    let ffmpegVersion: String
    let ffprobeVersion: String

    var displayText: String {
        "yt-dlp \(ytDlpVersion) · FFmpeg \(ffmpegVersion)"
    }
}

enum SupportToolsInstallPhase: Equatable, Sendable {
    case checking
    case downloadingYtDlp
    case downloadingFFmpeg
    case downloadingFFprobe
    case downloadingMediaSource
    case verifying
    case activating

    var localizationKey: String {
        switch self {
        case .checking: "supportToolsChecking"
        case .downloadingYtDlp: "supportToolsDownloadingYtDlp"
        case .downloadingFFmpeg: "supportToolsDownloadingFFmpeg"
        case .downloadingFFprobe: "supportToolsDownloadingFFprobe"
        case .downloadingMediaSource: "supportToolsDownloadingMediaSource"
        case .verifying: "supportToolsVerifying"
        case .activating: "supportToolsActivating"
        }
    }

    var fallbackText: String {
        switch self {
        case .checking: "Checking the latest versions…"
        case .downloadingYtDlp: "Downloading the video engine…"
        case .downloadingFFmpeg: "Downloading the media engine…"
        case .downloadingFFprobe: "Downloading the media inspector…"
        case .downloadingMediaSource: "Downloading the matching media source archive…"
        case .verifying: "Verifying downloaded tools…"
        case .activating: "Finishing setup…"
        }
    }
}

enum SupportToolsInstallerError: LocalizedError {
    case invalidManifest(String)
    case invalidResponse(String)
    case downloadTooLarge(String)
    case checksumMismatch(String)
    case archiveMissingTool(String)
    case unsupportedArchitecture(String)
    case toolFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifest(let name): "Không đọc được thông tin cập nhật của \(name)."
        case .invalidResponse(let name): "Không tải được \(name)."
        case .downloadTooLarge(let name): "Gói \(name) lớn bất thường nên đã bị chặn."
        case .checksumMismatch(let name): "Checksum của \(name) không khớp; app đã giữ bộ công cụ cũ."
        case .archiveMissingTool(let name): "Gói tải về không chứa \(name)."
        case .unsupportedArchitecture(let name): "\(name) tải về không hỗ trợ Apple Silicon."
        case .toolFailed(let name): "\(name) tải về không thể khởi động."
        }
    }
}

struct ReviewedMediaRelease: Decodable {
    let schema: Int
    let provider: String
    let packageID: String
    let version: String
    let archiveURL: String
    let archiveSHA256: String
    let sourceURL: String
    let sourceSHA256: String
    let ffmpegSHA256: String
    let ffprobeSHA256: String
}

enum ReviewedMediaPolicy {
    static func validChecksum(_ value: String) -> Bool {
        value.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil
    }

    static func approvedURL(_ value: String, source: Bool) -> URL? {
        guard let parts = URLComponents(string: value), parts.scheme == "https",
              parts.host == "github.com", parts.port == nil,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              let url = parts.url else { return nil }
        let suffix = source ? #"-sources\.tar\.gz$"# : #"-arm64\.zip$"#
        let pattern = #"^/Atu96/vidsavie/releases/download/media-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+/vidsavie-media-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+"# + suffix
        guard url.path.range(of: pattern, options: .regularExpression) != nil,
              !parts.percentEncodedPath.contains("%") else { return nil }
        return url
    }

    static func isReviewedDirectory(_ directory: URL) -> Bool {
        let file = directory.appendingPathComponent("versions.json")
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 16_384, let data = try? Data(contentsOf: file),
              let metadata = try? JSONDecoder().decode(SupportToolsMetadata.self, from: data),
              let packageID = metadata.mediaPackageID,
              packageID.hasPrefix("media-\(metadata.ffmpegVersion)-v"),
              metadata.ffmpegVersion == metadata.ffprobeVersion,
              let sourceURL = metadata.mediaSourceURL,
              let source = approvedURL(sourceURL, source: true),
              source.deletingLastPathComponent().lastPathComponent == packageID,
              source.lastPathComponent == "vidsavie-\(packageID)-sources.tar.gz",
              let checksum = metadata.mediaSourceChecksum, validChecksum(checksum),
              validChecksum(metadata.installedFFmpegChecksum), validChecksum(metadata.installedFFprobeChecksum)
        else { return false }
        let sourceArchive = directory.appendingPathComponent("ThirdParty/\(packageID)-sources.tar.gz")
        let values = try? sourceArchive.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        return values?.isRegularFile == true && values?.isSymbolicLink != true && (values?.fileSize ?? 0) > 0
    }
}

enum SupportToolsReleaseParser {
    static func parse(ytDlpChecksums: String, mediaJSON: Data) throws -> SupportToolsReleaseManifest {
        guard let ytDlpChecksum = ytDlpChecksums.split(separator: "\n")
            .compactMap({ line -> (String, String)? in
                let fields = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                guard fields.count >= 2 else { return nil }
                return (fields[0].lowercased(), fields[fields.count - 1])
            }).first(where: { $0.1 == "yt-dlp_macos" })?.0,
              ReviewedMediaPolicy.validChecksum(ytDlpChecksum),
              mediaJSON.count <= 16_384,
              let media = try? JSONDecoder().decode(ReviewedMediaRelease.self, from: mediaJSON),
              media.schema == 1, media.provider == "vidsavie-source-build",
              media.version.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil,
              media.packageID.hasPrefix("media-\(media.version)-v"),
              let archive = ReviewedMediaPolicy.approvedURL(media.archiveURL, source: false),
              let source = ReviewedMediaPolicy.approvedURL(media.sourceURL, source: true),
              archive.deletingLastPathComponent() == source.deletingLastPathComponent(),
              archive.deletingLastPathComponent().lastPathComponent == media.packageID,
              archive.lastPathComponent == "vidsavie-\(media.packageID)-arm64.zip",
              source.lastPathComponent == "vidsavie-\(media.packageID)-sources.tar.gz",
              [media.archiveSHA256, media.sourceSHA256, media.ffmpegSHA256, media.ffprobeSHA256]
                .allSatisfy(ReviewedMediaPolicy.validChecksum),
              let ytDlpURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")
        else { throw SupportToolsInstallerError.invalidManifest("support tools") }
        return SupportToolsReleaseManifest(
            ytDlpURL: ytDlpURL, ytDlpChecksum: ytDlpChecksum,
            ffmpegURL: archive, ffmpegChecksum: media.ffmpegSHA256, ffmpegVersion: media.version,
            ffprobeURL: archive, ffprobeChecksum: media.ffprobeSHA256, ffprobeVersion: media.version,
            mediaArchiveChecksum: media.archiveSHA256, mediaPackageID: media.packageID,
            mediaSourceURL: source, mediaSourceChecksum: media.sourceSHA256
        )
    }
}

enum MachOArchitectureInspector {
    private static let cpuTypeArm64: UInt32 = 0x0100_000C

    static func containsArm64(at url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return containsArm64(in: try handle.read(upToCount: 4096) ?? Data())
    }

    static func containsArm64(in data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        let bytes = [UInt8](data)
        let magic = Array(bytes.prefix(4))

        if magic == [0xCF, 0xFA, 0xED, 0xFE] || magic == [0xCE, 0xFA, 0xED, 0xFE] {
            return readUInt32(bytes, at: 4, littleEndian: true) == cpuTypeArm64
        }
        if magic == [0xFE, 0xED, 0xFA, 0xCF] || magic == [0xFE, 0xED, 0xFA, 0xCE] {
            return readUInt32(bytes, at: 4, littleEndian: false) == cpuTypeArm64
        }

        let fatLayout: (littleEndian: Bool, entrySize: Int)?
        switch magic {
        case [0xCA, 0xFE, 0xBA, 0xBE]: fatLayout = (false, 20)
        case [0xBE, 0xBA, 0xFE, 0xCA]: fatLayout = (true, 20)
        case [0xCA, 0xFE, 0xBA, 0xBF]: fatLayout = (false, 32)
        case [0xBF, 0xBA, 0xFE, 0xCA]: fatLayout = (true, 32)
        default: fatLayout = nil
        }
        guard let fatLayout,
              let architectureCount = readUInt32(bytes, at: 4, littleEndian: fatLayout.littleEndian)
        else { return false }

        let maximumEntries = max(0, (bytes.count - 8) / fatLayout.entrySize)
        let safeCount = min(Int(architectureCount), maximumEntries, 64)
        for index in 0..<safeCount {
            let offset = 8 + index * fatLayout.entrySize
            if readUInt32(bytes, at: offset, littleEndian: fatLayout.littleEndian) == cpuTypeArm64 {
                return true
            }
        }
        return false
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int, littleEndian: Bool) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        if littleEndian {
            return UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24
        }
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }
}

actor SupportToolsInstaller {
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    private let fileManager = FileManager.default
    private let runner = ProcessRunner()
    private let destinationToolsDirectory: URL?
    private let ytDlpChecksumsURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS")!
    private let ffmpegManifestURL = URL(string: "https://raw.githubusercontent.com/Atu96/vidsavie/main/Resources/Toolchain/media-release.json")!
    private let maximumBinaryBytes: Int64 = 120 * 1024 * 1024
    private let maximumArchiveBytes: Int64 = 220 * 1024 * 1024

    init(toolsDirectory: URL? = SupportToolsInstaller.defaultToolsDirectory) {
        destinationToolsDirectory = toolsDirectory
    }

    static var defaultToolsDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Video Batch Downloader", isDirectory: true)
            .appendingPathComponent("Tools", isDirectory: true)
    }

    static func hasManagedTools(fileManager: FileManager = .default, toolsDirectory: URL? = defaultToolsDirectory) -> Bool {
        guard let toolsDirectory, ReviewedMediaPolicy.isReviewedDirectory(toolsDirectory) else { return false }
        return ["yt-dlp", "ffmpeg", "ffprobe"].allSatisfy {
            fileManager.isExecutableFile(atPath: toolsDirectory.appendingPathComponent($0).path)
        }
    }

    func installedSnapshot() async -> SupportToolsSnapshot? {
        guard let destinationToolsDirectory,
              Self.hasManagedTools(toolsDirectory: destinationToolsDirectory)
        else { return nil }
        return try? await snapshot(in: destinationToolsDirectory)
    }

    static func hasAvailableTools() -> Bool {
        MediaBinaryLocator.ytDlp() != nil && MediaBinaryLocator.ffmpeg() != nil && MediaBinaryLocator.ffprobe() != nil
    }

    /// Reads release metadata only. Never installs tools or modifies the signed bundle.
    func updateIsAvailable() async throws -> Bool {
        let latest = try await fetchManifest()
        let resources = Bundle.main.resourceURL
        let bundledMedia = resources.flatMap { try? Data(contentsOf: $0.appendingPathComponent("Toolchain/media-release.json")) }
            .flatMap { try? JSONDecoder().decode(ReviewedMediaRelease.self, from: $0) }
        let bundledYt = resources.flatMap { try? String(contentsOf: $0.appendingPathComponent("Toolchain/bundled-yt-dlp.sha256"), encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = destinationToolsDirectory.flatMap { try? Data(contentsOf: $0.appendingPathComponent("versions.json")) }
            .flatMap { try? JSONDecoder().decode(SupportToolsMetadata.self, from: $0) }
        func checksum(name: String, path: String?, bundled: String?, original: String?, installed: String?) throws -> String? {
            guard let path else { return nil }
            if let directory = destinationToolsDirectory,
               path == directory.appendingPathComponent(name).path,
               let installed, try sha256(of: URL(fileURLWithPath: path)) == installed {
                return original
            }
            if let resources, path == resources.appendingPathComponent("Tools/\(name)").path { return bundled }
            return nil
        }
        let yt = try checksum(name: "yt-dlp", path: MediaBinaryLocator.ytDlp(), bundled: bundledYt,
                              original: metadata?.ytDlpChecksum, installed: metadata?.installedYtDlpChecksum)
        let ff = try checksum(name: "ffmpeg", path: MediaBinaryLocator.ffmpeg(), bundled: bundledMedia?.ffmpegSHA256,
                              original: metadata?.ffmpegChecksum, installed: metadata?.installedFFmpegChecksum)
        let fp = try checksum(name: "ffprobe", path: MediaBinaryLocator.ffprobe(), bundled: bundledMedia?.ffprobeSHA256,
                              original: metadata?.ffprobeChecksum, installed: metadata?.installedFFprobeChecksum)
        return SupportToolsUpdatePolicy.hasChangedTools(current: [yt, ff, fp],
            latest: [latest.ytDlpChecksum, latest.ffmpegChecksum, latest.ffprobeChecksum])
    }

    func installOrUpdate(
        onPhase: @escaping @Sendable (SupportToolsInstallPhase) -> Void = { _ in }
    ) async throws -> SupportToolsSnapshot {
        onPhase(.checking)
        let manifest = try await fetchManifest()
        guard let toolsDirectory = destinationToolsDirectory else {
            throw SupportToolsInstallerError.toolFailed("Application Support")
        }
        let applicationDirectory = toolsDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: applicationDirectory, withIntermediateDirectories: true)

        let metadataURL = toolsDirectory.appendingPathComponent("versions.json")
        let currentMetadata: SupportToolsMetadata?
        if let metadataData = try? Data(contentsOf: metadataURL) {
            currentMetadata = try? JSONDecoder().decode(SupportToolsMetadata.self, from: metadataData)
        } else {
            currentMetadata = nil
        }
        let currentIsComplete = Self.hasManagedTools(toolsDirectory: toolsDirectory)
        let currentYtDlpIsTrusted = installedBinaryMatches(
            named: "yt-dlp", expected: currentMetadata?.installedYtDlpChecksum, in: toolsDirectory
        )
        let currentFFmpegIsTrusted = currentIsComplete && installedBinaryMatches(
            named: "ffmpeg", expected: currentMetadata?.installedFFmpegChecksum, in: toolsDirectory
        )
        let currentFFprobeIsTrusted = currentIsComplete && installedBinaryMatches(
            named: "ffprobe", expected: currentMetadata?.installedFFprobeChecksum, in: toolsDirectory
        )
        let sourceName = "\(manifest.mediaPackageID)-sources.tar.gz"
        let existingSource = toolsDirectory.appendingPathComponent("ThirdParty/\(sourceName)")
        let sameMediaProfile = currentMetadata?.mediaPackageID == manifest.mediaPackageID && currentMetadata?.mediaSourceChecksum == manifest.mediaSourceChecksum
        let currentSourceIsTrusted = sameMediaProfile && (try? sha256(of: existingSource)) == manifest.mediaSourceChecksum
        if currentYtDlpIsTrusted, currentFFmpegIsTrusted, currentFFprobeIsTrusted,
           currentSourceIsTrusted,
           currentMetadata?.ytDlpChecksum == manifest.ytDlpChecksum,
           currentMetadata?.ffmpegChecksum == manifest.ffmpegChecksum,
           currentMetadata?.ffprobeChecksum == manifest.ffprobeChecksum {
            return try await snapshot(in: toolsDirectory)
        }

        let stagingRoot = applicationDirectory.appendingPathComponent("Install-\(UUID().uuidString)", isDirectory: true)
        let stagingTools = stagingRoot.appendingPathComponent("Tools", isDirectory: true)
        try fileManager.createDirectory(at: stagingTools, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        try await stageBinary(
            name: "yt-dlp",
            sourceURL: manifest.ytDlpURL,
            expectedChecksum: manifest.ytDlpChecksum,
            archive: false,
            archiveChecksum: nil,
            reuse: currentYtDlpIsTrusted && currentMetadata?.ytDlpChecksum == manifest.ytDlpChecksum,
            currentTools: toolsDirectory,
            stagingTools: stagingTools,
            onDownload: { onPhase(.downloadingYtDlp) }
        )
        try await stageBinary(
            name: "ffmpeg",
            sourceURL: manifest.ffmpegURL,
            expectedChecksum: manifest.ffmpegChecksum,
            archive: true,
            archiveChecksum: manifest.mediaArchiveChecksum,
            reuse: currentFFmpegIsTrusted && sameMediaProfile && currentMetadata?.ffmpegChecksum == manifest.ffmpegChecksum,
            currentTools: toolsDirectory,
            stagingTools: stagingTools,
            onDownload: { onPhase(.downloadingFFmpeg) }
        )
        try await stageBinary(
            name: "ffprobe",
            sourceURL: manifest.ffprobeURL,
            expectedChecksum: manifest.ffprobeChecksum,
            archive: true,
            archiveChecksum: manifest.mediaArchiveChecksum,
            reuse: currentFFprobeIsTrusted && sameMediaProfile && currentMetadata?.ffprobeChecksum == manifest.ffprobeChecksum,
            currentTools: toolsDirectory,
            stagingTools: stagingTools,
            onDownload: { onPhase(.downloadingFFprobe) }
        )

        let stagedSource = stagingTools.appendingPathComponent("ThirdParty/\(sourceName)")
        if (try? sha256(of: stagedSource)) != manifest.mediaSourceChecksum {
            onPhase(.downloadingMediaSource)
            if fileManager.fileExists(atPath: stagedSource.path) {
                try fileManager.removeItem(at: stagedSource) // UUID-owned staging copy only; current tools are untouched.
            }
            try await download(manifest.mediaSourceURL, to: stagedSource, name: "media source", maximumBytes: maximumArchiveBytes)
            guard try sha256(of: stagedSource) == manifest.mediaSourceChecksum else {
                throw SupportToolsInstallerError.checksumMismatch("media source")
            }
        }
        onPhase(.verifying)
        for name in ["yt-dlp", "ffmpeg", "ffprobe"] {
            let path = stagingTools.appendingPathComponent(name).path
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            try await requireSuccess("xattr", executable: "/usr/bin/xattr", arguments: ["-cr", path])
            try await requireSuccess(name, executable: "/usr/bin/codesign", arguments: ["--force", "--sign", "-", path])
            guard try MachOArchitectureInspector.containsArm64(at: URL(fileURLWithPath: path)) else {
                throw SupportToolsInstallerError.unsupportedArchitecture(name)
            }
        }

        let stagedSnapshot = try await snapshot(in: stagingTools)
        guard stagedSnapshot.ffmpegVersion == manifest.ffmpegVersion,
              stagedSnapshot.ffprobeVersion == manifest.ffprobeVersion else {
            throw SupportToolsInstallerError.toolFailed("media version")
        }
        let metadata = SupportToolsMetadata(
            ytDlpChecksum: manifest.ytDlpChecksum,
            ffmpegChecksum: manifest.ffmpegChecksum,
            ffprobeChecksum: manifest.ffprobeChecksum,
            installedYtDlpChecksum: try sha256(of: stagingTools.appendingPathComponent("yt-dlp")),
            installedFFmpegChecksum: try sha256(of: stagingTools.appendingPathComponent("ffmpeg")),
            installedFFprobeChecksum: try sha256(of: stagingTools.appendingPathComponent("ffprobe")),
            ffmpegVersion: manifest.ffmpegVersion,
            ffprobeVersion: manifest.ffprobeVersion,
            updatedAt: Date(),
            mediaPackageID: manifest.mediaPackageID,
            mediaSourceURL: manifest.mediaSourceURL.absoluteString,
            mediaSourceChecksum: manifest.mediaSourceChecksum
        )
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: stagingTools.appendingPathComponent("versions.json"), options: .atomic)

        onPhase(.activating)
        let backupDirectory = applicationDirectory.appendingPathComponent("Tools.previous-\(UUID().uuidString)", isDirectory: true)
        if fileManager.fileExists(atPath: toolsDirectory.path) {
            try fileManager.moveItem(at: toolsDirectory, to: backupDirectory)
        }
        do {
            try fileManager.moveItem(at: stagingTools, to: toolsDirectory)
            try? fileManager.removeItem(at: backupDirectory)
        } catch {
            if !fileManager.fileExists(atPath: toolsDirectory.path), fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: toolsDirectory)
            }
            throw error
        }
        return stagedSnapshot
    }

    private func fetchManifest() async throws -> SupportToolsReleaseManifest {
        async let ytDlpData = fetchData(from: ytDlpChecksumsURL, name: "yt-dlp")
        async let ffmpegData = fetchData(from: ffmpegManifestURL, name: "FFmpeg")
        guard let ytDlpText = String(data: try await ytDlpData, encoding: .utf8)
        else { throw SupportToolsInstallerError.invalidManifest("support tools") }
        return try SupportToolsReleaseParser.parse(ytDlpChecksums: ytDlpText, mediaJSON: try await ffmpegData)
    }

    private func fetchData(from url: URL, name: String) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SupportToolsInstallerError.invalidResponse(name)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              http.url?.scheme == "https" else {
            throw SupportToolsInstallerError.invalidResponse(name)
        }
        return data
    }

    private func stageBinary(
        name: String,
        sourceURL: URL,
        expectedChecksum: String,
        archive: Bool,
        archiveChecksum: String?,
        reuse: Bool,
        currentTools: URL,
        stagingTools: URL,
        onDownload: () -> Void
    ) async throws {
        let destination = stagingTools.appendingPathComponent(name)
        if reuse {
            try fileManager.copyItem(at: currentTools.appendingPathComponent(name), to: destination)
            if name == "ffmpeg", fileManager.fileExists(atPath: currentTools.appendingPathComponent("ThirdParty").path) {
                try fileManager.copyItem(at: currentTools.appendingPathComponent("ThirdParty"), to: stagingTools.appendingPathComponent("ThirdParty"))
            }
            return
        }

        onDownload()
        let payload = stagingTools.deletingLastPathComponent().appendingPathComponent(archive ? "media.download" : "\(name).download")
        if !archive || !fileManager.fileExists(atPath: payload.path) {
            try await download(sourceURL, to: payload, name: name, maximumBytes: archive ? maximumArchiveBytes : maximumBinaryBytes)
        }
        if archive {
            guard let archiveChecksum, try sha256(of: payload) == archiveChecksum else {
                throw SupportToolsInstallerError.checksumMismatch(name)
            }
            let unpacked = stagingTools.deletingLastPathComponent().appendingPathComponent("\(name)-unpacked", isDirectory: true)
            try fileManager.createDirectory(at: unpacked, withIntermediateDirectories: true)
            try await requireSuccess(name, executable: "/usr/bin/ditto", arguments: ["-x", "-k", payload.path, unpacked.path])
            guard let extracted = findRegularFile(named: name, under: unpacked) else {
                throw SupportToolsInstallerError.archiveMissingTool(name)
            }
            guard try sha256(of: extracted) == expectedChecksum else {
                throw SupportToolsInstallerError.checksumMismatch(name)
            }
            try fileManager.copyItem(at: extracted, to: destination)
            if name == "ffmpeg" {
                let notices = unpacked.appendingPathComponent("licenses", isDirectory: true)
                for file in ["FFMPEG-LGPL-2.1.txt", "LAME-LGPL-2.0.txt", "DAV1D-BSD-2-Clause.txt", "MEDIA-TOOLCHAIN.md"] {
                    let url = notices.appendingPathComponent(file)
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else {
                        throw SupportToolsInstallerError.archiveMissingTool("license notices")
                    }
                }
                try fileManager.copyItem(at: notices, to: stagingTools.appendingPathComponent("ThirdParty", isDirectory: true))
            }
        } else {
            guard try sha256(of: payload) == expectedChecksum else {
                throw SupportToolsInstallerError.checksumMismatch(name)
            }
            try fileManager.copyItem(at: payload, to: destination)
        }
    }

    private func download(_ url: URL, to destination: URL, name: String, maximumBytes: Int64) async throws {
        let temporaryURL: URL
        let response: URLResponse
        do {
            (temporaryURL, response) = try await session.download(from: url)
        } catch {
            throw SupportToolsInstallerError.invalidResponse(name)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              http.url?.scheme == "https" else {
            throw SupportToolsInstallerError.invalidResponse(name)
        }
        let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, Int64(size) <= maximumBytes else {
            throw SupportToolsInstallerError.downloadTooLarge(name)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
    }

    private func findRegularFile(named name: String, under directory: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == name {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values?.isRegularFile == true, values?.isSymbolicLink != true { return url }
        }
        return nil
    }

    private func installedBinaryMatches(named name: String, expected: String?, in directory: URL) -> Bool {
        guard let expected else { return false }
        return (try? sha256(of: directory.appendingPathComponent(name))) == expected
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func snapshot(in directory: URL) async throws -> SupportToolsSnapshot {
        let ytDlp = try await runner.run(
            executable: directory.appendingPathComponent("yt-dlp").path,
            arguments: ["--version"],
            environmentOverrides: ["PYTHONDONTWRITEBYTECODE": "1"]
        )
        let ffmpeg = try await runner.run(executable: directory.appendingPathComponent("ffmpeg").path, arguments: ["-version"])
        let ffprobe = try await runner.run(executable: directory.appendingPathComponent("ffprobe").path, arguments: ["-version"])
        guard ytDlp.status == 0 else { throw SupportToolsInstallerError.toolFailed("yt-dlp") }
        guard ffmpeg.status == 0 else { throw SupportToolsInstallerError.toolFailed("ffmpeg") }
        guard ffprobe.status == 0 else { throw SupportToolsInstallerError.toolFailed("ffprobe") }
        return SupportToolsSnapshot(
            ytDlpVersion: firstVersion(in: ytDlp.output, tool: "yt-dlp"),
            ffmpegVersion: firstVersion(in: ffmpeg.output, tool: "ffmpeg"),
            ffprobeVersion: firstVersion(in: ffprobe.output, tool: "ffprobe")
        )
    }

    private func firstVersion(in output: String, tool: String) -> String {
        let firstLine = output.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? output
        if tool == "yt-dlp" { return firstLine.trimmingCharacters(in: .whitespacesAndNewlines) }
        let fields = firstLine.split(whereSeparator: { $0.isWhitespace })
        if let versionIndex = fields.firstIndex(of: "version"), fields.indices.contains(versionIndex + 1) {
            return String(fields[versionIndex + 1])
        }
        return firstLine
    }

    private func requireSuccess(_ name: String, executable: String, arguments: [String]) async throws {
        let result = try await runner.run(executable: executable, arguments: arguments)
        guard result.status == 0 else { throw SupportToolsInstallerError.toolFailed(name) }
    }
}
