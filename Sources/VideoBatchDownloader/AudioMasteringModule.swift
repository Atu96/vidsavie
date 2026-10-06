import AppKit
import SwiftUI

struct AudioMasteringModuleView: View {
    @ObservedObject var manager: DownloadManager
    @ObservedObject private var finderQuickActions = FinderQuickActionCenter.shared
    @StateObject private var runner = MediaToolRunner()
    @State private var inputURL: URL?
    @State private var moveOriginalAudioToTrash = false
    @State private var errorMessage: String?

    var body: some View {
        MediaToolWindowShell(
            manager: manager,
            title: t("audioMastering", "Audio Mastering"),
            subtitle: t("audioMasteringSub", "Balance voice loudness while preserving the original character"),
            symbol: "waveform.badge.mic",
            color: .pink
        ) {
            VStack(spacing: 16) {
                MediaToolCard(title: t("sourceMedia", "Source audio or video"), symbol: "waveform") {
                    if let inputURL {
                        SelectedFileRow(url: inputURL) { self.inputURL = nil }
                    } else {
                        MediaFileDropZone(
                            title: t("dropAudioOrVideo", "Drop audio or video here"),
                            detail: t("audioSourceHint", "Drag a file from Finder, or choose one below."),
                            symbol: "waveform.badge.plus",
                            color: .pink,
                            onFiles: acceptDroppedFiles
                        )
                    }
                    Button {
                        chooseInput()
                    } label: {
                        Label(inputURL == nil ? t("chooseFile", "Choose File") : t("replaceFile", "Replace File"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                MediaToolCard(title: t("masteringChain", "Mastering chain"), symbol: "slider.vertical.3") {
                    chainRow(t("softGate", "Soft breath/noise gate"), "waveform.path.ecg")
                    chainRow(t("youtubeLoudness", "Loudness normalized near −14 LUFS"), "speaker.wave.2.fill")
                    chainRow(t("truePeak", "True Peak limited to −1.5 dBTP"), "gauge.with.dots.needle.67percent")
                    chainRow(t("preserveVoice", "No EQ, denoise, or heavy compression"), "checkmark.shield.fill")

                    Divider()
                    Toggle(isOn: $moveOriginalAudioToTrash) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("trashOriginalAudio", "Move original audio to Trash after success"))
                                .font(.subheadline.weight(.semibold))
                            Text(t("trashOriginalAudioDetail", "Applies only to audio-only sources; video sources are always preserved."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.pink)
                }

                MediaToolRunPanel(
                    runner: runner,
                    actionTitle: t("startMastering", "Start Mastering"),
                    actionSymbol: "waveform.badge.mic",
                    actionColor: .pink,
                    canRun: inputURL != nil,
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

    private func chainRow(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { setInput(url) }
    }

    private func acceptDroppedFiles(_ files: [URL]) {
        guard let selected = files.first(where: { url in
            guard let kind = MediaFilePolicy.inputKind(for: url) else { return false }
            return kind == .audio || kind == .video
        }) else {
            errorMessage = t("audioVideoOnly", "Please drop an audio or video file.")
            return
        }
        setInput(selected)
    }

    private func setInput(_ url: URL) {
        guard let kind = MediaFilePolicy.inputKind(for: url), (kind == .audio || kind == .video) else {
            errorMessage = t("audioVideoOnly", "Please choose an audio or video file.")
            return
        }
        inputURL = url
    }

    private func receiveFinderQuickAction() {
        guard let request = finderQuickActions.request,
              request.kind == .masterAudio,
              let selected = request.urls.first
        else { return }
        setInput(selected)
        finderQuickActions.consume(request.id)
    }

    private func run() async {
        guard let inputURL else { return }
        let containsVideo = MediaFilePolicy.containsVideo(inputURL)
        let output = MediaFilePolicy.uniqueOutputURL(
            for: inputURL,
            suffix: "-audio-mastered",
            extension: containsVideo ? "mp4" : "wav"
        )
        let command = MediaToolCommandBuilder.audioMastering(
            input: inputURL,
            outputURL: output,
            containsVideo: containsVideo
        )
        do {
            try await runner.execute([command])
            if moveOriginalAudioToTrash && !containsVideo {
                NSWorkspace.shared.recycle([inputURL]) { _, error in
                    if let error {
                        Task { @MainActor in errorMessage = error.localizedDescription }
                    }
                }
            }
            // Only reset the import surface after the mastering command succeeded.
            // A failed or stopped run intentionally leaves its source available to retry.
            self.inputURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
