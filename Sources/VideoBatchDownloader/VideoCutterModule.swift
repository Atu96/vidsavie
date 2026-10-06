import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VideoCutterModuleView: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject private var finderQuickActions = FinderQuickActionCenter.shared
    @StateObject private var runner = MediaToolRunner()
    @State private var inputURLs: [URL] = []
    @State private var outputRoot: URL?
    @State private var segmentSeconds = 8.0
    @State private var mode: VideoCutMode = .fastCopy
    @State private var arrangement: VideoSegmentArrangement = .sequential
    @State private var usesAutomaticOutputFolder = true
    @State private var filenamePrefix = ""
    @State private var errorMessage: String?

    var body: some View {
        MediaToolWindowShell(
            manager: manager,
            title: t("videoCutter", "Video Cutter"),
            subtitle: t("videoCutterSub", "Split a video into clean, reusable segments"),
            symbol: "scissors",
            color: .blue
        ) {
            VStack(spacing: 16) {
                MediaToolCard(title: t("sourceVideos", "Source videos"), symbol: "film.fill") {
                    if inputURLs.isEmpty {
                        MediaFileDropZone(
                            title: t("dropVideos", "Drop one or more videos here"),
                            detail: t("dropVideosDetail", "Drag videos from Finder, or choose them below. They are cut sequentially."),
                            symbol: "film.stack.fill",
                            color: .blue,
                            onFiles: acceptDroppedFiles
                        )
                    } else {
                        ForEach(inputURLs, id: \.standardizedFileURL.path) { url in
                            SelectedFileRow(url: url) {
                                removeInput(url)
                            }
                        }
                        Text(String(format: t("batchVideoCount", "%d videos will be cut one at a time"), inputURLs.count))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        chooseInputs()
                    } label: {
                        Label(inputURLs.isEmpty ? t("chooseVideos", "Choose Videos") : t("addVideos", "Add Videos"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                MediaToolCard(title: t("cutSettings", "Cut settings"), symbol: "slider.horizontal.3") {
                    HStack {
                        Text(t("segmentDuration", "Segment duration"))
                        Spacer()
                        TextField("8", value: $segmentSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 75)
                        Stepper("", value: $segmentSeconds, in: 1...3600, step: 1)
                            .labelsHidden()
                        Text(t("seconds", "seconds")).foregroundStyle(.secondary)
                    }

                    Picker(t("cutMode", "Cut mode"), selection: $mode) {
                        Text(t("fastCut", "Fast · keep original quality")).tag(VideoCutMode.fastCopy)
                        Text(t("preciseCut", "Precise · Apple GPU")).tag(VideoCutMode.precise)
                    }
                    .pickerStyle(.segmented)

                    Text(mode == .fastCopy
                         ? t("fastCutDetail", "Very fast; boundaries follow source keyframes.")
                         : t("preciseCutDetail", "Accurate timing with H.264 VideoToolbox encoding."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker(t("segmentArrangement", "Segment arrangement"), selection: $arrangement) {
                        Text(t("sequentialCut", "Cut in order")).tag(VideoSegmentArrangement.sequential)
                        Text(t("creativeRandomSegments", "Creative random order")).tag(VideoSegmentArrangement.creativeRandom)
                        Text(t("randomSourceMix", "Random source mix")).tag(VideoSegmentArrangement.randomSourceMix)
                    }
                    .pickerStyle(.segmented)

                    Text(arrangement == .sequential
                         ? t("sequentialCutDetail", "For a batch: A1 → B1 → C1 → A2. A–Z marks the source video.")
                         : arrangement == .creativeRandom
                            ? t("creativeRandomSegmentsDetail", "Each video’s clips are shuffled first, then arranged A → B → C in a shared batch timeline.")
                            : t("randomSourceMixDetail", "Clips and sources are mixed randomly; the same source is avoided twice in a row when possible."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("outputName", "Output name"))
                            Text(t("outputNameHint", "The app adds 0001 numbering and A–Z letters automatically."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if inputURLs.count <= 1 {
                        HStack(spacing: 7) {
                            TextField(t("beforeNumber", "Name"), text: $filenamePrefix)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                            if !filenamePrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("_").foregroundStyle(.secondary)
                            }
                            Text("0001_A")
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(previewFileName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(t("batchNameHint", "All clips go to one folder. A–Z identifies the source video; the batch alternates one clip from each source."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Picker(t("outputFolder", "Output folder"), selection: $usesAutomaticOutputFolder) {
                        Text(t("autoMixedFolder", "Auto mixed_N")).tag(true)
                        Text(t("chooseOutputFolder", "Choose folder")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(usesAutomaticOutputFolder ? t("autoMixedFolder", "Auto mixed_N") : t("outputFolder", "Output folder"))
                        Spacer()
                        Text(usesAutomaticOutputFolder ? automaticOutputFolder?.path ?? t("notSelected", "Not selected") : outputRoot?.path ?? t("notSelected", "Not selected"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if !usesAutomaticOutputFolder { Button(t("choose", "Choose")) { chooseOutput() } }
                    }
                }

                MediaToolRunPanel(
                    runner: runner,
                    actionTitle: t("startCutting", "Start Cutting"),
                    actionSymbol: "scissors",
                    actionColor: .blue,
                    canRun: !inputURLs.isEmpty && (usesAutomaticOutputFolder || outputRoot != nil) && segmentSeconds > 0,
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

    private var previewFileName: String {
        MediaFilePolicy.segmentFileName(
            prefix: filenamePrefix,
            number: "0001",
            suffix: "A"
        ) + ".mp4"
    }

    private var automaticOutputFolder: URL? {
        guard let first = inputURLs.first else { return nil }
        let parent = first.deletingLastPathComponent()
        var index = 1
        var candidate = parent.appendingPathComponent("mixed_\(index)", isDirectory: true)
        while FileManager.default.fileExists(atPath: candidate.path) {
            index += 1
            candidate = parent.appendingPathComponent("mixed_\(index)", isDirectory: true)
        }
        return candidate
    }

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    private func chooseInputs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        addInputs(panel.urls)
    }

    private func acceptDroppedFiles(_ files: [URL]) {
        guard files.contains(where: { MediaFilePolicy.accepts($0, as: .video) }) else {
            errorMessage = t("videoOnly", "Please drop a video file.")
            return
        }
        addInputs(files)
    }

    private func addInputs(_ urls: [URL], replacing: Bool = false) {
        let eligible = urls.filter { MediaFilePolicy.accepts($0, as: .video) }
        guard !eligible.isEmpty else {
            errorMessage = t("videoOnly", "Please choose video files.")
            return
        }
        if replacing {
            inputURLs = []
            outputRoot = nil
            filenamePrefix = ""
        }
        let existing = Set(inputURLs.map(\.standardizedFileURL.path))
        inputURLs += eligible.filter { !existing.contains($0.standardizedFileURL.path) }
        guard let first = inputURLs.first else { return }
        if outputRoot == nil {
            outputRoot = first.deletingLastPathComponent()
                .appendingPathComponent("\(first.deletingPathExtension().lastPathComponent)_segments")
        }
        if inputURLs.count > 1,
                  outputRoot == first.deletingLastPathComponent().appendingPathComponent("\(first.deletingPathExtension().lastPathComponent)_segments") {
            outputRoot = first.deletingLastPathComponent()
        }
    }

    private func removeInput(_ url: URL) {
        inputURLs.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        if inputURLs.isEmpty {
            outputRoot = nil
            filenamePrefix = ""
        }
    }

    private func receiveFinderQuickAction() {
        guard let request = finderQuickActions.request,
              request.kind == .cutVideo
        else { return }
        addInputs(request.urls, replacing: true)
        finderQuickActions.consume(request.id)
    }

    private func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = outputRoot ?? inputURLs.first?.deletingLastPathComponent()
        if panel.runModal() == .OK { outputRoot = panel.url }
    }

    private func run() async {
        guard let outputRoot = usesAutomaticOutputFolder ? automaticOutputFolder : outputRoot else { return }
        do {
            let plan = VideoCutBatchPlan(inputs: inputURLs, outputRoot: outputRoot)
            let batchRenamePlan: BatchSegmentRenamePlan? = inputURLs.count > 1
                ? BatchSegmentRenamePlan(
                    outputDirectory: outputRoot,
                    sources: inputURLs.enumerated().map { index, _ in
                        BatchSegmentSource(temporaryPrefix: "", sourceIndex: index)
                    },
                    arrangement: arrangement
                )
                : nil
            let commands = try inputURLs.map { input in
                let directory = plan.outputDirectory(for: input)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let command = try MediaToolCommandBuilder.videoCut(
                    input: input,
                    outputDirectory: directory,
                    seconds: segmentSeconds,
                    mode: mode,
                    filenamePrefix: plan.filenamePrefix(for: input, requestedPrefix: filenamePrefix),
                    arrangement: arrangement,
                    batchSegmentRenamePlan: batchRenamePlan
                )
                return command
            }
            if inputURLs.count > 1 {
                let sources = commands.enumerated().map { index, command in
                    BatchSegmentSource(temporaryPrefix: command.segmentRenamePlan?.temporaryPrefix ?? "", sourceIndex: index)
                }
                let finalizedPlan = BatchSegmentRenamePlan(outputDirectory: outputRoot, sources: sources, arrangement: arrangement)
                let finalizedCommands = commands.map { command in
                    MediaToolCommand(label: command.label, inputURL: command.inputURL, outputURL: command.outputURL, arguments: command.arguments, revealsDirectory: command.revealsDirectory, segmentRenamePlan: command.segmentRenamePlan, batchSegmentRenamePlan: finalizedPlan)
                }
                try await runner.execute(finalizedCommands)
                // Leave failed/stopped sources in place for retry; reset only a finished batch.
                inputURLs.removeAll()
                return
            }
            try await runner.execute(commands)
            // Leave failed/stopped sources in place for retry; reset only a finished batch.
            inputURLs.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
