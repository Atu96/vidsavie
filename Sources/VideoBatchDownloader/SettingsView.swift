import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.openWindow) private var openWindow
    @State private var section: String? = "general"
    @AppStorage(DownloadFileNameTemplate.titleKey) private var nameTitle = true
    @AppStorage(DownloadFileNameTemplate.authorKey) private var nameAuthor = false
    @AppStorage(DownloadFileNameTemplate.dateKey) private var nameDate = false

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Image(nsImage: brandedAppIcon)
                        .resizable().scaledToFit()
                        .frame(width: 42, height: 42)
                        .shadow(color: VBDDesign.brandViolet.opacity(0.16), radius: 6, y: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VideoFetch Flow")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(t("settingsTitle", "Settings"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 16)

                List(selection: $section) {
                    settingsLink("general", title: t("general", "General"), icon: "gearshape.fill")
                    settingsLink("browser", title: t("browserCompanion", "Browser Companion"), icon: "puzzlepiece.extension.fill")
                    settingsLink("finder", title: t("finderQuickActions", "Finder Quick Actions"), icon: "cursorarrow.click.2")
                    settingsLink("appearance", title: t("appearance", "Appearance"), icon: "paintpalette.fill")
                    settingsLink("about", title: t("about", "About"), icon: "info.circle.fill")
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                VStack(spacing: 0) {
                    Label(t("localConnection", "Private local connection"), systemImage: "lock.shield.fill")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 235)
            .background(sidebarCanvas)
            .environment(\.colorScheme, settingsColorScheme)
            .foregroundStyle(settingsPrimaryText)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.white.opacity(usesDarkTheme ? 0.13 : 0.48)).frame(width: 1)
            }
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sectionTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(sectionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 18)

                Group {
                    switch section {
                    case "browser": browser
                    case "finder": finder
                    case "appearance": appearance
                    case "about": about
                    default: general
                    }
                }
                .frame(maxWidth: 680, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(detailCanvas)
            .environment(\.colorScheme, settingsColorScheme)
            .foregroundStyle(settingsPrimaryText)
        }
        .navigationSplitViewStyle(.balanced)
        .background(AppGlassCanvas(theme: manager.visualTheme))
        .tint(VBDDesign.brandBlue)
    }

    private var settingsColorScheme: ColorScheme {
        AppAppearance.colorScheme(for: manager.visualTheme)
    }

    private var usesDarkTheme: Bool {
        settingsColorScheme == .dark
    }

    private var settingsPrimaryText: Color {
        usesDarkTheme ? Color.white.opacity(0.94) : Color(red: 0.08, green: 0.10, blue: 0.14)
    }

    private var sidebarCanvas: some View {
        Group {
            if usesDarkTheme {
                LinearGradient(
                    colors: [
                        Color(red: 0.070, green: 0.095, blue: 0.155),
                        Color(red: 0.050, green: 0.070, blue: 0.125),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.white.opacity(0.70)
            }
        }
    }

    private var detailCanvas: some View {
        Group {
            if usesDarkTheme {
                LinearGradient(
                    colors: [
                        Color(red: 0.040, green: 0.060, blue: 0.110),
                        Color(red: 0.052, green: 0.062, blue: 0.115),
                        Color(red: 0.060, green: 0.048, blue: 0.100),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.white.opacity(0.16)
            }
        }
    }

    private func settingsLink(_ id: String, title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 5)
            .tag(id)
    }

    private var sectionTitle: String {
        switch section {
        case "browser": t("browserCompanion", "Browser Companion")
        case "finder": t("finderQuickActions", "Finder Quick Actions")
        case "appearance": t("appearance", "Appearance")
        case "about": t("about", "About")
        default: t("general", "General")
        }
    }

    private var sectionSubtitle: String {
        switch section {
        case "browser": t("browserSettingsSub", "Browser companions and signed-in sessions")
        case "finder": t("finderQuickActionsSub", "Send selected Finder files directly to the app’s media tools")
        case "appearance": t("appearanceSettingsSub", "Language and visual style across the app")
        case "about": t("aboutSettingsSub", "Product information and privacy")
        default: t("generalSettingsSub", "Storage, download defaults, and background app controls")
        }
    }

    private var general: some View {
        VStack(spacing: 14) {
            StorageSettingsCard(manager: manager)

            SettingsCard(title: t("downloadDefaults", "Download defaults"), subtitle: t("downloadsSub", "Applied to menu-bar pastes and quick browser downloads")) {
                        HStack {
                            SettingsLabel(icon: "film.stack.fill", title: t("defaultMediaType", "Default media type"), detail: t("defaultMediaTypeDetail", "Used when pasting links in the menu bar"))
                            Spacer()
                            Picker(t("type", "Type"), selection: $manager.defaultDownloadKind) {
                                Text(t("video", "Video")).tag(DownloadKind.video)
                                Text(t("audio", "Audio")).tag(DownloadKind.audio)
                            }
                            .labelsHidden().frame(width: 120)
                        }
                        Divider().opacity(0.45)
                        HStack {
                            SettingsLabel(icon: "sparkles.tv.fill", title: t("defaultQuality", "Default quality"), detail: t("defaultQualityDetail", "Used for video downloads and browser quick download"))
                            Spacer()
                            Picker("Default quality", selection: $manager.defaultQuality) {
                                Text(t("best", "Best")).tag("best")
                                Text("1080p").tag("1080")
                                Text("720p").tag("720")
                                Text("480p").tag("480")
                            }
                            .labelsHidden().frame(width: 120)
                            .disabled(manager.defaultDownloadKind == .audio)
                        }
                        Divider().opacity(0.45)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Thành phần").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                nameChip("Tiêu đề", enabled: nameTitle) { nameTitle.toggle() }
                                nameChip("Tác giả", enabled: nameAuthor) { nameAuthor.toggle() }
                                nameChip("Ngày đăng", enabled: nameDate) { nameDate.toggle() }
                            }
                        }
            }

            SettingsCard(title: t("supportTools", "Support tools"), subtitle: "yt-dlp · FFmpeg · FFprobe") {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(VBDDesign.brandBlue)
                        .font(.title3.weight(.medium))
                        .frame(width: 28, height: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(manager.supportToolsInstalled
                            ? t("supportToolsReady", "Support tools are ready")
                            : t("supportToolsNeeded", "Install the updateable tool set"))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(manager.supportToolsInstalled
                            ? t("supportToolsReadyDetail", "Automatically checks for updates every 24 hours")
                            : t("supportToolsNeededDetail", "One click · no Homebrew or Terminal required"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 20)

                    VStack(alignment: .center, spacing: 6) {
                        Button {
                            manager.scheduleSupportToolsUpdate(force: true)
                        } label: {
                            if manager.isUpdatingSupportTools {
                                ProgressView().controlSize(.small)
                            } else {
                                Label(
                                    manager.supportToolsLastUpdateFailed
                                        ? t("retrySupportTools", "Try again")
                                        : manager.supportToolsInstalled
                                        ? t("updateSupportTools", "Update tools")
                                        : t("installSupportTools", "Install tools"),
                                    systemImage: manager.supportToolsLastUpdateFailed
                                        ? "arrow.clockwise"
                                        : manager.supportToolsInstalled ? "arrow.clockwise" : "square.and.arrow.down"
                                )
                            }
                        }
                        .buttonStyle(AppCompactPrimaryButtonStyle(tint: .blue))
                        .disabled(manager.isUpdatingSupportTools)

                        if let phase = manager.supportToolsInstallPhase {
                            Text(t(phase.localizationKey, phase.fallbackText))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if !manager.supportToolsStatus.isEmpty {
                            Text(manager.supportToolsStatus)
                                .font(.caption2.weight(.medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: 172, alignment: .center)
                }
                .frame(minHeight: 44)
            }

            SettingsCard(title: t("localWorkflow", "Local workflow"), subtitle: t("localWorkflowSub", "The app and companion communicate only on this Mac")) {
                SettingsLabel(icon: "lock.shield.fill", title: t("localSync", "Changes synchronize locally"), detail: t("localSyncDetail", "No account or cloud connection is required"))
                Divider().opacity(0.45)
                SettingsLabel(icon: "bolt.horizontal.circle.fill", title: t("backgroundReady", "Ready in the background"), detail: t("backgroundReadyDetail", "The download engine remains available from the menu bar"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func nameChip(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(enabled ? VBDDesign.brandBlue : Color.secondary)
            .padding(.horizontal, 10)
            .frame(minHeight: VBDDesign.compactControlHeight)
            .background(AppSurface(cornerRadius: 9, level: .control, tint: enabled ? VBDDesign.brandBlue : nil))
        }
        .buttonStyle(.plain)
        .accessibilityValue(enabled ? "Selected" : "Not selected")
    }

    private var browser: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsCard(title: t("installCompanion", "Install browser companion"), subtitle: t("included", "The companion is included with this Mac app")) {
                    BrowserInstallRow(name: "Google Chrome", detail: t("chromeDetail", "Enable Developer mode, then drag the included folder into Extensions"), buttonTitle: t("setup", "Set Up"), symbol: "globe", color: .blue) {
                        beginChromeSetup()
                    }
                    Divider().opacity(0.45)
                    BrowserInstallRow(name: "Mozilla Firefox", detail: t("firefoxDetail", "Open Add-on debugging and reveal the package"), buttonTitle: t("setup", "Set Up"), symbol: "flame.fill", color: .orange) {
                        manager.installFirefoxCompanion()
                    }
                }

                BrowserSessionSettingsCard(manager: manager)

                Label(t("localSync", "Changes are synchronized locally. No account or cloud connection is required."), systemImage: "lock.shield.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func beginChromeSetup() {
        let settingsWindow = NSApplication.shared.keyWindow
        manager.installChromeCompanion()
        settingsWindow?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            openWindow(id: "chrome-install-guide")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private var finder: some View {
        VStack(spacing: 14) {
            SettingsCard(
                title: t("finderQuickActions", "Finder Quick Actions"),
                subtitle: t("finderQuickActionsDetail", "Right-click supported files and open the matching VideoFetch Flow tool")
            ) {
                SettingsLabel(
                    icon: "scissors",
                    title: t("quickCutVideo", "Cut Video"),
                    detail: t("quickCutVideoDetail", "Available for video files")
                )
                Divider().opacity(0.45)
                SettingsLabel(
                    icon: "arrow.triangle.2.circlepath",
                    title: t("quickConvert", "Convert Media"),
                    detail: t("quickConvertDetail", "Available for video, audio, and image files")
                )
                Divider().opacity(0.45)
                SettingsLabel(
                    icon: "waveform.badge.mic",
                    title: t("quickMasterAudio", "Master Audio"),
                    detail: t("quickMasterAudioDetail", "Available for audio and video files")
                )
            }

            SettingsCard(
                title: t("enableFinderActions", "Enable in Finder"),
                subtitle: t("enableFinderActionsDetail", "macOS requires one manual approval for contextual services")
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "cursorarrow.motionlines.click")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentGradient)
                        .frame(width: 42, height: 42)
                        .background(AppSurface(cornerRadius: 12, level: .control))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("quickActionsIncluded", "Quick Actions are included with this app"))
                            .font(.caption.weight(.semibold))
                        Text(t("quickActionsApproval", "Press Setup, enable the VideoFetch Flow services, then use Finder’s right-click menu."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        beginFinderQuickActionSetup()
                    } label: {
                        Label(t("setup", "Set Up"), systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(AppPrimaryButtonStyle(tint: .blue))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func beginFinderQuickActionSetup() {
        let settingsWindow = NSApplication.shared.keyWindow
        FinderQuickActionSetup.registerServices()
        FinderQuickActionSetup.openSystemSettings()
        settingsWindow?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            openWindow(id: "finder-quick-actions-guide")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private var appearance: some View {
        ScrollView {
            VStack(spacing: 11) {
                SettingsCard(title: t("language", "Language"), subtitle: t("languageSub", "App and Chrome video controls")) {
                    HStack {
                        SettingsLabel(icon: "globe", title: t("interfaceLanguage", "Interface language"), detail: t("interfaceLanguageDetail", "Choose a market or follow the system"))
                        Spacer()
                        Picker("Language", selection: $manager.interfaceLanguage) {
                            Text("Auto").tag("auto")
                            Text("English").tag("en")
                            Text("Tiếng Việt").tag("vi")
                            Text("简体中文").tag("zh")
                            Text("Español").tag("es")
                            Text("Français").tag("fr")
                            Text("Deutsch").tag("de")
                            Text("Português").tag("pt")
                            Text("日本語").tag("ja")
                            Text("한국어").tag("ko")
                        }
                        .labelsHidden().frame(width: 125)
                    }
                }

                SettingsCard(title: t("glassTheme", "Glass theme"), subtitle: t("glassThemeSub", "Also changes the floating Chrome button")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ThemeChoice(name: t("system", "System"), detail: t("followMac", "Follow macOS"), colors: [.gray, .primary], selected: manager.visualTheme == "auto") { manager.visualTheme = "auto" }
                        ThemeChoice(name: t("darkGlass", "Dark glass"), detail: t("darkGlass", "Dark glass"), colors: [.gray, .black], selected: manager.visualTheme == "dark") { manager.visualTheme = "dark" }
                        ThemeChoice(name: t("lightGlass", "Light glass"), detail: t("lightGlass", "Light glass"), colors: [.white, .blue.opacity(0.55)], selected: manager.visualTheme == "light") { manager.visualTheme = "light" }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var about: some View {
        VStack(spacing: 13) {
            Image(nsImage: brandedAppIcon)
                .resizable().scaledToFit().frame(width: 96, height: 96)
                .shadow(color: .purple.opacity(0.28), radius: 16, y: 8)
            VStack(spacing: 3) {
                Text("VideoFetch Flow").font(.title3.bold())
                Text("\(t("version", "Version")) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.6.0")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 7) {
                PlatformCapsule(name: "YouTube", color: .red)
                PlatformCapsule(name: "Douyin", color: .pink)
                PlatformCapsule(name: "X", color: .primary)
            }
            SettingsCard(title: t("workflow", "Local-first media workflow"), subtitle: t("workflowSub", "Built as a lightweight Mac menu bar app")) {
                SettingsLabel(icon: "lock.fill", title: t("private", "Private by design"), detail: t("privateDetail", "Links and browser cookies remain on this Mac"))
                Divider().opacity(0.45)
                SettingsLabel(icon: "bolt.fill", title: t("performance", "Stable performance"), detail: t("performanceDetail", "Sequential downloads and Apple GPU conversion"))
                Divider().opacity(0.45)
                SettingsLabel(icon: "puzzlepiece.extension.fill", title: t("replaceable", "Replaceable companion"), detail: t("replaceableDetail", "The Mac app keeps working without Chrome"))
            }
            SettingsCard(title: t("donateTitle", "Enjoying the app?"), subtitle: t("donateDetail", "Your support helps keep VideoFetch Flow improving. Thank you!")) {
                HStack {
                    Text("Ko-fi · atu1202")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Link(destination: URL(string: "https://ko-fi.com/atu1202")!) {
                        HStack(spacing: 7) {
                            Image(systemName: "heart.fill").foregroundStyle(.red)
                            Text("Donate").fontWeight(.semibold)
                            Image(systemName: "arrow.up.right").font(.caption)
                        }
                        .padding(.horizontal, 5).padding(.vertical, 3)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityLabel(t("donateAccessibility", "Donate on Ko-fi (opens in browser)"))
                    .help("https://ko-fi.com/atu1202")
                }
            }
        }
        .padding(.top, 12)
    }
}

private struct BrowserSessionSettingsCard: View {
    @ObservedObject var manager: DownloadManager
    @State private var isExpanded = false

    private func t(_ key: String, _ fallback: String) -> String {
        AppText.value(key, language: manager.interfaceLanguage, fallback: fallback)
    }

    private var policyLabel: String {
        switch manager.browserCookiePolicy {
        case .smart: t("cookieSmart", "Automatic")
        case .always: t("cookieAlways", "Always")
        case .never: t("cookieNever", "Never")
        }
    }

    private var summary: String {
        guard manager.browserCookiePolicy != .never else { return policyLabel }
        let profile = manager.browserCookieProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        let browser = profile.isEmpty
            ? manager.browserCookieSource.displayName
            : "\(manager.browserCookieSource.displayName) · \(profile)"
        return "\(policyLabel) · \(browser)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundStyle(accentGradient)
                        .frame(width: 34, height: 34)
                        .background(AppSurface(cornerRadius: 10, level: .control))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("browserSession", "Browser sign-in session"))
                            .font(.subheadline.weight(.semibold))
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(t("advancedOptions", "Options"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().opacity(0.45).padding(.vertical, 11)
                VStack(spacing: 11) {
                    HStack {
                        SettingsLabel(
                            icon: "switch.2",
                            title: t("cookiePolicy", "Usage"),
                            detail: t("browserSessionSub", "Use local cookies only when required")
                        )
                        Spacer()
                        Picker(t("cookiePolicy", "Usage"), selection: $manager.browserCookiePolicy) {
                            Text(t("cookieSmart", "Automatic")).tag(BrowserCookiePolicy.smart)
                            Text(t("cookieAlways", "Always")).tag(BrowserCookiePolicy.always)
                            Text(t("cookieNever", "Never")).tag(BrowserCookiePolicy.never)
                        }
                        .labelsHidden().frame(width: 105)
                    }

                    if manager.browserCookiePolicy != .never {
                        Divider().opacity(0.45)
                        HStack {
                            SettingsLabel(
                                icon: "globe",
                                title: t("cookieBrowser", "Browser"),
                                detail: t("cookieProfileHint", "Blank uses the default profile")
                            )
                            Spacer()
                            Picker(t("cookieBrowser", "Browser"), selection: $manager.browserCookieSource) {
                                ForEach(BrowserCookieSource.allCases, id: \.self) { source in
                                    Text(source.displayName).tag(source)
                                }
                            }
                            .labelsHidden().frame(width: 125)
                        }
                        HStack {
                            TextField(t("cookieProfile", "Profile"), text: $manager.browserCookieProfile)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                manager.testBrowserSession()
                            } label: {
                                if manager.isTestingBrowserSession {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(t("testSession", "Test session"))
                                }
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                            .disabled(manager.isTestingBrowserSession)
                        }
                    }

                    if !manager.browserSessionStatus.isEmpty {
                        Text(manager.browserSessionStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Label(
                        t("cookiePrivacy", "Cookies are never displayed, exported, or uploaded."),
                        systemImage: "lock.shield.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(13)
        .background(AppSurface(cornerRadius: 14, level: .raised))
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            content
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurface(cornerRadius: VBDDesign.radiusCard, level: .raised))
    }
}

private struct SettingsLabel: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(VBDDesign.brandBlue)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThemeChoice: View {
    let name: String
    let detail: String
    let colors: [Color]
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: selected ? "checkmark" : "circle.lefthalf.filled").foregroundStyle(.white).font(.caption.bold()))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.caption.bold())
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(AppSurface(cornerRadius: 10, level: selected ? .raised : .control, tint: selected ? VBDDesign.brandBlue : nil))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

private struct PlatformCapsule: View {
    let name: String
    let color: Color
    var body: some View {
        Text(name).font(.caption2.bold()).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }
}

private struct BrowserInstallRow: View {
    let name: String
    let detail: String
    let buttonTitle: String
    let symbol: String
    let color: Color
    let action: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered).controlSize(.small)
        }
    }
}
