import AppKit
import SwiftUI

struct MediaConverterModuleView: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject private var finderQuickActions = FinderQuickActionCenter.shared
    @StateObject private var runner = MediaToolRunner()
    @State private var inputs: [URL] = []
    @State private var preset: MediaConversionPreset = .videoMP4
    @State private var rejectedFiles = 0
    @State private var errorMessage: String?

    private var inputKind: MediaInputKind? {
        guard let first = inputs.first else { return nil }
        return MediaFilePolicy.inputKind(for: first)
    }

    private var compatiblePresets: [MediaConversionPreset] {
        inputKind?.compatiblePresets ?? []
    }

    var body: some View {
        MediaToolWindowShell(
            manager: manager,
            title: t("mediaConverter", "Media Converter"),
            subtitle: t("mediaConverterSub", "Convert video, audio, and images with optimized presets"),
            symbol: "arrow.triangle.2.circlepath",
            color: .purple
        ) {
            VStack(spacing: 16) {
                MediaToolCard(title: t("sourceFiles", "Source files"), symbol: "doc.on.doc.fill") {
                    if inputs.isEmpty {
                        MediaFileDropZone(
                            title: t("dropMedia", "Drop media files here"),
                            detail: t("dropMediaDetail", "Add one media type at a time. Outputs are saved beside each source."),
                            symbol: "square.and.arrow.down.fill",
                            color: .purple,
                            onFiles: addInputs
                        )
                    } else {
                        ForEach(inputs, id: \.path) { url in
                            SelectedFileRow(url: url) {
                                inputs.removeAll { $0 == url }
                                syncPresetToInputs()
                            }
                        }
                        Text(kindDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        chooseInputs()
                    } label: {
                        Label(t("addFiles", "Add Files"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                MediaToolCard(title: t("conversionPreset", "Conversion preset"), symbol: "dial.medium.fill") {
                    if compatiblePresets.isEmpty {
                        Text(t("addFilesToChoosePreset", "Add media files to see matching conversion formats."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("", selection: $preset) {
                            ForEach(compatiblePresets, id: \.self) { preset in
                                presetLabel(preset).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                    }
                }

                MediaToolRunPanel(
                    runner: runner,
                    actionTitle: t("startConverting", "Start Converting"),
                    actionSymbol: "arrow.triangle.2.circlepath",
                    actionColor: .purple,
                    canRun: !inputs.isEmpty,
                    run: { Task { await run() } }
                )
            }
        }
        .alert(t("error", "Error"), isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: receiveFinderQuickAction)
        .onChange(of: finderQuickActions.request?.id) { _ in
            receiveFinderQuickAction()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    private func chooseInputs() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        addInputs(panel.urls)
    }

    private func addInputs(_ urls: [URL]) {
        let acceptedKind = inputKind ?? urls.compactMap(MediaFilePolicy.inputKind(for:)).first
        guard let acceptedKind else {
            errorMessage = t("supportedMediaOnly", "Please add supported video, audio, or image files.")
            return
        }
        let existing = Set(inputs.map(\.standardizedFileURL.path))
        let eligible = urls.filter {
            MediaFilePolicy.inputKind(for: $0) == acceptedKind && !existing.contains($0.standardizedFileURL.path)
        }
        rejectedFiles = urls.count - eligible.count
        inputs += eligible
        syncPresetToInputs()
        if rejectedFiles > 0 {
            errorMessage = t("oneMediaType", "Convert one media type at a time. Files of other types were not added.")
        }
    }

    private func receiveFinderQuickAction() {
        guard let request = finderQuickActions.request,
              request.kind == .convertMedia
        else { return }
        addInputs(request.urls)
        finderQuickActions.consume(request.id)
    }

    private func syncPresetToInputs() {
        guard let first = compatiblePresets.first else { return }
        if !compatiblePresets.contains(preset) { preset = first }
    }

    @ViewBuilder private func presetLabel(_ preset: MediaConversionPreset) -> some View {
        switch preset {
        case .videoMP4:
            Label(t("videoMP4Preset", "Video → MP4 H.264 · Hardware accelerated"), systemImage: "film.fill")
        case .audioMP3:
            Label(t("audioMP3Preset", "Audio → MP3 · 320 kbps"), systemImage: "waveform")
        case .imageJPG:
            Label(t("imageJPGPreset", "Image → JPG · High quality"), systemImage: "photo.fill")
        case .imagePNG:
            Label(t("imagePNGPreset", "Image → PNG · Lossless"), systemImage: "photo.on.rectangle")
        }
    }

    private var kindDescription: String {
        switch inputKind {
        case .video: t("videoFilesOnly", "Video files · compatible formats shown below")
        case .audio: t("audioFilesOnly", "Audio files · compatible formats shown below")
        case .image: t("imageFilesOnly", "Image files · compatible formats shown below")
        case nil: ""
        }
    }

    private func run() async {
        let descriptor = MediaFilePolicy.outputDescriptor(for: preset)
        var reservedOutputs = Set<String>()
        let commands = inputs.map { input in
            let output = MediaFilePolicy.uniqueOutputURL(
                for: input,
                suffix: descriptor.suffix,
                extension: descriptor.extension,
                fileExists: {
                    FileManager.default.fileExists(atPath: $0) || reservedOutputs.contains($0)
                }
            )
            reservedOutputs.insert(output.path)
            return MediaToolCommandBuilder.conversion(input: input, preset: preset, outputURL: output)
        }
        do {
            try await runner.execute(commands)
            // A completed conversion has produced every requested output. Keep inputs on
            // failure/cancellation, but clear this import queue for the next task.
            inputs.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
