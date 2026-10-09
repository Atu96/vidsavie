# Architecture

## Product boundary

The visible product name is VidSavie from 2.2.43 (previously VideoFetch Flow from 2.2.33). Technical identity remains `com.gemst.VideoBatchDownloader` with the existing executable, URL scheme, preference keys, tool-storage and resumable-cache paths. Renaming those persistence boundaries is not part of a visual rebrand. App and companion artwork is reproducible through `Scripts/render-brand.swift`.

The macOS menu bar app is the product and download engine. The browser extension is a replaceable companion that detects focused media and sends normalized requests to the app. No Raycast component is part of the runtime.

## Layers and dependency direction

### Build boundary and artifact retention

Packaging replaces generated resource directories before copying; in particular Toolchain must not nest within an older Toolchain directory on repeated builds. Deployment replaces the signed app bundle wholesale, not by merging over an older installation, since unsealed leftover files invalidate the signature. Keep recoverable backups and verify after replacement; user data lives separately and must not be cleared to fix bundle signing.

Ordinary app builds compile Swift only and package prebuilt checksum-verified tools from `.build/portable-tools`, downloading the pinned release when the cache is absent. The separate media source-build recipe is not invoked by `build-app.sh` or `build-dmg.sh`. Keep this separation: rebuilding the app does not mean rebuilding FFmpeg, and end users never compile it. The current media update feed is maintainer-published; automatic upstream/provider version discovery is not implemented.

For cleanup retain the incremental Swift cache, current app build, portable binaries, exact media source inputs/output, rollback backup and current distribution binary/source assets. Obsolete isolated compiler work directories, old branded app build copies and old DMGs may be removed after inspecting exact targets. Never include installed apps, Application Support, browser data or resumable user downloads in build-cache cleanup. Documentation-only edits do not require a new app build/version.

Media profile from 2.2.45: both bootstrap and managed updater use `Resources/Toolchain/media-release.json`, a reviewed pair with exact executable/archive/source hashes. The updater only accepts matching owned GitHub release assets, keeps component notices and verified corresponding-source archive, checks executable versions, then activates atomically. Legacy managed FFmpeg/probe without this provenance are bypassed for the new bundle, not removed; yt-dlp precedence is unchanged. FFmpeg is compiled from pinned sources with LAME/dav1d and system VideoToolbox/SecureTransport, without autodetection/GPL/nonfree add-ons. Source/build recipe and generated-media checks are separate from real platform/hardware verification.

### macOS presentation

Working-window activation (2.2.52): WindowActivationCoordinator registers Settings, media tools, repair and setup windows without replacing their delegates. Opening a working window promotes NSApplication to regular (Dock/Cmd-Tab) and activates it. Closing the last registered window or deliberately ordering it out returns to accessory; minimized windows still count, and switching focus never hides the icon. Closing windows does not terminate the menu-bar app or its downloads. LSUIElement remains the startup default. Theme changes do not repeatedly activate windows. Source-contract/build validation is distinct from native visual verification.

Browser session setup (2.2.51): Settings has a dedicated sidebar destination, separate from companion installation and support-tool updates. BrowserProfileControl shares an explicit NSOpenPanel directory chooser with SessionRepairView; it stores only the selected profile path and reads no cookie contents. Automatic selection remains available, and manual paths remain supported. Choosing a folder is not a persistent privacy grant to yt-dlp. Session tests contact YouTube without downloading media; typed diagnostics distinguish missing database, access/decryption denial and other failures, with nine-language safe copy and no raw test error shown. Success does not guarantee sign-in or all-video access. Results for a changed configuration are discarded.

BrowserProfileProbe (2.2.52) performs bounded metadata-only directory enumeration before cookie-using page attempts/tests, after any verified direct-media path has been attempted. POSIX EPERM/EACCES and Cocoa read-permission errors are preserved as access denial, not discarded as missing profiles. It searches only profile containers/Network directories to depth two, at most 128 directories, and never reads database values, Local State, preferences or history. Default is an explicit user shortcut, not an automatic persisted choice. Privacy navigation appears for access failures and does not grant permissions or edit TCC; Full Disk Access is explained as broad and optional, not a requirement for all users. These checks cannot prove child-process access, successful decryption or platform downloads. Session results clear when configuration changes.

Main header/Support/media launchers use AppHoverButtonStyle from 2.2.50: tint-aware overlays and glow only, stable geometry, no scale/offset, no overlay hit interception. Disabled controls suppress feedback; Reduce Motion avoids animation. Keep these semantics when revising visual chrome.

Settings split-column hosts are keyed by effective `settingsColorScheme` from 2.2.48, to refresh AppKit-backed environment snapshots during theme transitions. Keep section and filename-toggle state in enclosing AppSettingsView; do not key the entire settings owner or generate random identities. Root and column environments share one resolved scheme. This addresses reported mixed light surfaces/dark text; static tests do not certify live transitions.

- `VideoBatchDownloaderApp.swift`: process entry point and MenuBarExtra.
- `ContentView.swift`: compact menu-bar shell, history navigation, focused automatic link paste, completion banner that dismisses the panel before Finder reveal, direct Quit App action, and settings-window launch with menu-bar dismissal.
- `SettingsWindowView.swift`: singleton centered macOS window, standard opaque macOS title bar, compact 860×760 initial/minimum content size, theme, and activation behavior.
- `SessionRepairView.swift`: focused AppKit-hosted repair panel for browser policy, profile, session test, update, and retry actions.
- `CompanionInstallGuideView.swift`: dedicated centered Chrome onboarding window with a code-native looping Developer mode and drag-folder animation.
- `HistoryViews.swift`: persistent history presentation.
- `SettingsView.swift`: compact commercial-style sidebar for General, Browser Companion, Finder Quick Actions, Appearance, and About. General is a fixed non-scrolling composition for storage, download defaults, engine maintenance, and local workflow; longer Browser/Appearance pages own their scroll containers.
- `FinderQuickActionGuideView.swift`: dedicated visual onboarding window for the one-time macOS Services approval and Finder right-click workflow; its code-native looping checklist mirrors the three Services rows and sequential ticks.
- `StorageSettingsCard.swift`: download location display and folder actions only.
- `DownloadComponents.swift`: reusable queue and action components.
- `AppText.swift`: localized lookup.
- `AppVisuals.swift`: shared settings/tool and dedicated menu-bar backgrounds, contrast-tiered card/control surfaces, and regular plus compact primary-action styling for native SwiftUI screens.
- `MediaToolViews.swift`: reusable themed window chrome, cards, selected-file rows, run/progress controls, and window centering.
- `VideoCutterModule.swift`: video-cut selection, segment settings, and its independent runner state.
- `MediaConverterModule.swift`: multi-file conversion preset UI and its independent runner state.
- `AudioMasteringModule.swift`: mastering-chain UI, safe source-cleanup option, and its independent runner state.

Presentation depends on `DownloadManager` and models. It does not construct yt-dlp or ffmpeg commands.

Visual contrast is a presentation invariant: screens use `AppVisuals` rather than nesting indistinguishable translucent materials. The app background stays dark in Obsidian/Aurora, while raised cards, controls, and insets have separate luminance and outlines. Primary actions use a dedicated treatment so they remain legible without making every secondary action bright. Settings extends the same rule across its split view: the sidebar and detail are two tonal layers on a shared glass canvas, separated by one fine divider rather than disconnected system-gray regions. The menu bar has a dedicated `MenuBarGlassCanvas`: white/pale-blue/light-purple in Light and white highlights over deep-blue/purple in Dark, so its operational surface shares the product palette without inheriting a generic gray window background. Its paste field is deliberately one control tier brighter: a white upper highlight resolves into a fine black-glass lower edge with a short shadow, establishing it as the primary entry point without visual excess.

The menu-bar header is the operational status surface: it uses the stronger glass gradient, high-contrast translucent/reflection icon actions, and distinct active/waiting/completed metrics. The compact supported-platform slogan and connection-status label are intentionally single-line under header constraints. The Quit action is intentionally the only red/orange header control so it stays discoverable without competing with normal navigation. The three offline media launchers use centered icon/label groups and one thin black-glass outline without a drop shadow. Their surface is explicitly appearance-aware: Light uses calm white–pale-blue, while Dark/Auto Dark uses blue-black glass, a white upper reflection resolving to a black lower edge, and white label contrast. This prevents the footer from inheriting a bright light panel in dark UI. Appearance has only System, Dark glass, and Light glass; retired or unknown persisted values normalize to System at each app/extension boundary, making System a live macOS decision rather than a cached theme. `AppAppearance` resolves System from `NSApplication.effectiveAppearance`, never from a previous window override; `SettingsWindowView` and `MediaToolViews` then synchronously set `NSWindow.appearance`, keeping native labels correct in Light and making Dark/Light → System transitions immediate. `AppGlassCanvas` keeps a restrained deep blue-black canvas with limited blue/pink light blooms in Dark. In the empty queue, Quick Add and ready guidance flow directly across that canvas with a restrained divider, not an enclosing rounded card; its input is smoked glass in Dark and bright glass in Light.

### Application orchestration

From 2.2.46, tool readiness includes available bundled binaries, not only a managed installation. Startup and 24-hour maintenance call metadata-only `updateIsAvailable`, comparing signed-bundle source-checksum records or hash-verified managed metadata against the feed. Changed/unknown provenance offers a localized Update tools / Later native alert; Return/Escape defer. Only the explicit action invokes `installOrUpdate`. Network errors do not interrupt ordinary app use. `Resources/Toolchain` is packaged for bundled provenance; no runtime source compilation. A checksum difference can also mean a revised build/repair, not strictly a newer numeric version.

- `DownloadManager.swift`: single-download FIFO scheduling, published runtime state, stop/retry, notifications, first-install/support-tool update state, 24-hour managed-tool maintenance, and browser-session selection.
- `Models.swift`: queue, job, history, kind, status, removal, and download-folder selection policies.
- `AppPreferences.swift`: validated extension-facing preference persistence.
- `AsyncSemaphore.swift`: serialized GPU conversion gate.
- `DownloadStateServices.swift`: deterministic history persistence plus support-tool update timing policy.
- `SupportToolsInstaller.swift`: one-click user-local installation and atomic update of yt-dlp, FFmpeg, and FFprobe. It parses allowlisted release metadata, verifies SHA-256 before activation, rejects oversized payloads, inspects thin/universal Mach-O headers for arm64 without Xcode Command Line Tools, signs and smoke-tests staged executables, and preserves the prior managed tool set on failure.
- `CompanionInstaller.swift`: browser/Finder launch sequence for companion onboarding.

The manager decides **when** work runs. It delegates **how** media is downloaded and converted.

Before starting the engine, the manager resolves storage through `DownloadFolderPolicy`. An available session override wins for the lifetime of the process; otherwise the configured persistent folder is used. If neither is available, AppKit presents a directory picker and stores the selection only in memory. Canceling stops the pending job without classifying it as a download failure. A relaunch starts with no override, so a reconnected configured volume becomes the default again.

Browser companion setup is delegated to `CompanionInstaller`: it verifies the packaged extension, opens the browser setup page, then opens app `Contents/Resources` in Finder last. The parent level is intentional because `ChromeExtension` must remain visible as the folder users drag into Chrome.

Chrome setup captures and hides the Settings window, launches Chrome/Finder, then uses SwiftUI `openWindow` to present the singleton `chrome-install-guide` scene and reactivate the app. The guide centers itself and is the only Video Batch window visible during onboarding. The animation is rendered in SwiftUI rather than stored as a GIF, so it follows app scaling and localization and does not add a binary asset-maintenance path.

### Offline media tools

- `MediaToolCore.swift`: Foundation-only enums, validation, FFmpeg argument builders, media classification, mastering constants, collision-safe output naming, and managed-first external-tool discovery with bundled and local-install fallbacks.
- `MediaToolRunner.swift`: shared FFmpeg/FFprobe process boundary, batch sequencing, `-progress` parsing, cancellation, bounded logs, and Finder reveal.

Each of the three window modules owns a separate `MediaToolRunner`, so cutter, converter, and mastering state cannot leak into each other or into `DownloadManager`. They share command and execution infrastructure but not mutable workflow state. Each module also owns its import selection and resets it only after a successful `MediaToolRunner.execute` return, keeping failed or cancelled sources available for retry. The old standalone cutter and Raycast shell scripts are reference inputs only and are not runtime dependencies.

The cutter chooses either stream copy through the segment muxer or precise H.264 VideoToolbox encoding. It accepts one or many videos and builds one sequential command per source. `VideoSegmentArrangement` has three editing policies: sequential, creative random, and random source mix. For a multi-source batch all temporary segments land in a shared output folder, then `BatchSegmentRenamePlan` emits either a round-robin timeline A1 → B1 → … → A2, a shuffled-per-source version of that timeline, or a random-source timeline that avoids repeating a source while alternatives remain. Global filenames use `0001_A` through source label A–Z, where the letter represents the input video. Default output is the next collision-free `mixed_N` beside the first source; an explicit chosen folder overrides it. FFmpeg writes uniquely prefixed temporary segments, then `MediaToolRunner` performs a brief collision-safe local rename after completion; the work is filesystem-only and independent of media processing. The converter maps a stable preset to one command per source and executes the batch sequentially. Audio mastering centralizes the gate/loudness filter constant; it preserves video streams, emits 24-bit WAV for audio-only sources, and only requests recoverable Trash cleanup when the user enables the off-by-default option.

`MediaFilePolicy` is the shared source of truth for media extension classification. The shared `MediaFileDropZone` keeps Finder drag-and-drop behavior consistent across the three tools. Converter batching is category-locked after the first accepted file: video can target MP4 or extract MP3, audio can target MP3, and images can target JPG or PNG. This keeps incompatible choices out of the UI rather than relying on FFmpeg failure handling.

Finder integration uses the standard macOS Services mechanism declared in `Info.plist`. `FinderQuickActions.swift` is deliberately a thin adapter: it reads file URLs from the Services pasteboard, applies the `FinderQuickActionKind` eligibility policy in `MediaToolCore.swift`, and publishes one launch request. The always-live menu-bar label opens the matching SwiftUI window; that module consumes the selected files and continues through the same command builder and runner as drag-and-drop or file picking. macOS owns whether each Service is enabled. Setup makes its best-effort Keyboard launch, while the ordered code-native guide models the reliable manual path: Keyboard Shortcuts… → Services → expand Files and Folders → tick services. Compact symbols in service labels make the right-click entries recognizable.

Browser overlays are discovered and displayed only in the middle half of the viewport. `overlay-core.js` uses a −25% top/bottom IntersectionObserver margin to defer creation outside that band and keeps a matching runtime visibility check for existing overlays. Platform adapters still own URL extraction; this central policy prevents duplicated viewport math and reduces visual noise.

Social image eligibility remains adapter-specific: Facebook requires image content inside a permalink-bearing feed post and excludes Marketplace/navigation/sponsored surfaces; X requires `tweetPhoto`. This avoids generic CDN-image selectors and keeps detection low-noise.

### Download infrastructure

- `DownloadEngine.swift`: managed-first yt-dlp/FFmpeg/FFprobe lifecycle with signed-bundle and external fallbacks, image downloads, numeric progress parsing, ordered browser-resolved Douyin media candidates, forced direct MP4 remux, ffprobe video-stream validation, failed-staging cleanup, ASCII staging filenames with best-effort portable local rename, explicit page-extractor fallback, smart cookie retry orchestration, and bounded Bilibili media refresh when actual byte growth over the latest rolling minute remains below 500 KB/s. A timer samples stalled connections; each refresh advances a child-process-only CDN index and reuses the same resumable cache. Tool updates never modify the signed app bundle.
- `Resources/YtDlpPlugins`: app-bundled, Bilibili-only extractor overrides for normal video, Bangumi, and Cheese. Index zero preserves Bilibili's primary media URL; later indices select only API-provided `backupUrl` values and never manufacture, persist, or expose signed media URLs or cookies.
- `DownloadCommandBuilder.swift`: deterministic yt-dlp argument construction, explicit partial-file continuation, and Bilibili-specific HTTP chunk/retry/throttle recovery plus bundled-plugin loading policy.
- `BrowserSession.swift`: cookie policy, browser/profile specification, deterministic 403/auth/cookie-access classification, and Smart retry policy. A Douyin fresh-cookie response is retried once from a newly read browser-cookie snapshot before the user is asked to repair the session.
- `ProcessRunner.swift`: isolated process execution with separate stdout/stderr collection and CR/LF-normalized live line delivery; it is the transport boundary for every external-tool progress callback.
- `ProgressProtocol.swift`: Foundation-only shared parser and normalizer for yt-dlp and FFmpeg progress protocols; it shields UI and runners from tool-specific line formats, retains byte counts even before yt-dlp knows a total, and provides human-readable file units only at the presentation boundary. `DownloadCommandBuilder` must force yt-dlp `--progress` output into Process pipes. `DownloadTransferProgressAccumulator` turns the preferred separate video/audio transfers into one monotonic job fraction without sacrificing the requested quality.
- `MediaConverter.swift`: ffprobe compatibility decisions and ffmpeg/VideoToolbox conversion.
- `URLNormalizer.swift`: canonical platform URLs and platform classification.

Dependency direction is:

`DownloadManager → DownloadEngine → DownloadCommandBuilder / BrowserSession / ProcessRunner / MediaConverter`

### Local bridge

- `LocalHTTPServer.swift`: TCP listener and small HTTP transport on `127.0.0.1:17832`.
- `LocalAPIOriginPolicy.swift`: rejects ordinary website origins and permits browser-extension origins plus origin-less local diagnostics.

The bridge exposes `/health`, `/preferences`, and `/enqueue`. It does not download or inspect DOM itself.

### Browser companion

Since 2.2.32, Douyin resolution also reads live React `memoizedProps` reached from bounded video-element ancestors. Exact-ID details with their own media are eligible; matching an ID on an unrelated metadata object is insufficient. Fiber traversal skips cycles, while props search avoids React/DOM ownership links and bounds its queue. It does not read arbitrary DOM video sources or resource timing. This addresses SPA player data absent from SSR/global roots; React internals remain a volatile platform integration.

Douyin SSR parsing isolates script bodies before URI decoding and unwraps JSON string literals without evaluation (maximum three wrapper layers, 4 MB per input). Matching scripts/chunks are filtered by the requested video ID before the 80-candidate cap, so unrelated early scripts cannot hide a late video payload. HTML detail-API responses receive `api-html`, not a cookie diagnosis. Exact detail-ID and media-host validation remain mandatory. These paths have synthetic regressions; live download success is not implied.

- `background.js`: the only extension component that talks to the app; generic-site registration, browser-wide preference sync, and privacy-preserving Douyin media resolution in the active page MAIN world. The resolver accepts the exact source and nearby visible title captured from the clicked video, then adds only bounded embedded page state, streaming SSR (`self.__pace_f` and matching script chunks), signed detail metadata, and, only when these yield no source, one same-origin canonical page HTML read for that permalink's video ID. It understands legacy `play_addr.url_list` and newer `playAddr`/`bitRateList` `src` forms, rejecting detail-API or page HTML results for another ID. It deliberately rejects document-wide DOM streams and recent resource timing because an infinite feed can associate them with adjacent items. Cookie values never cross the bridge. Titles prefer untranslated serialized/API descriptions before the clicked visible text fallback. The app allowlists/deduplicates media URLs and normalizes the description before using it as UI text or a filename. A floating-button request carries a Boolean resolution-attempt marker and a bounded, sanitized status code for player/SSR/API/HTML paths so an empty direct-source path cannot be mistaken for a cookie-only problem when yt-dlp also fails; no signed URL or cookie appears in the error report.
- `overlay-core.js`: adapter registry, visible-target scheduling, focus filtering, overlay lifecycle, and storage change listener.
- `lib/settings.js`: normalized settings and diff calculation.
- `lib/url-tools.js`: shared canonical URL and generic-site identity utilities.
- `adapters/*.js`: one platform per file, implementing `{ id, matches, scan, focus? }`. The Bilibili adapter intentionally targets the domestic `bilibili.com`/`b23.tv` surfaces and sends canonical page permalinks rather than `blob:` player streams.
- `popup.js`: user-initiated settings edits, connection state, and generic-site permission UI. Writes use serialized snapshots and local revision guards against stale replies; storage changes update idle popup controls. `lib/popup-i18n.js` owns complete popup dictionaries for nine languages and browser-UI Auto resolution, covered by key-parity and rapid-switch regression tests.
- Popup sizing uses a 600px body flex container, hidden root overflow and one shrinking main scroll owner. Do not cap its height with viewport units: Chrome's initial popup viewport can be tiny and create a content-sizing feedback collapse. Static CSS contracts are not proof of actual browser layout.

Dependency direction is:

`popup/adapters → background or overlay core → local bridge → DownloadManager`

Adapters never call localhost and never own settings persistence.

## Invariants

- Fresh browser sessions use Automatic/Smart policy. Chrome's absent profile preference defaults to Default; other browsers retain automatic discovery. Explicit saved empty/custom profiles and Always/Never remain unchanged. Centralized pure preference helpers own this contract. The user reported a successful YouTube download in Automatic and later clarified that Full Disk Access was also needed on their newer OS; no trace establishes the successful tier. Do not treat changing policy as a fix for permissions or prescribe Full Disk Access solely from a missing-database string.

- Fresh installs default to English in both AppPreferences and companion settings. Valid saved languages, including explicit System/auto, are preserved. Native language selection is centralized in AppPreferences.language; do not restore separate locale-dependent first-run fallbacks.

- Maximum active downloads is one. Queue order is FIFO even though newest cards render first.
- A missing configured download folder is never recreated implicitly and does not fail the job. The user chooses a session-only folder; this override is not persisted and the configured folder is preferred again after relaunch when available.
- Menu-bar media launchers open three separate window scenes. Offline media tools use independent runners, collision-safe outputs, and never enter the download FIFO.
- Original media is preserved by default. Audio-only Trash cleanup is explicit and recoverable; video sources are never deleted.
- Completed jobs are recorded in history and removed from the live queue automatically. Failed and stopped jobs remain available for retry/continue or explicit deletion. During the download stage each job owns one stable hidden cache directory; interrupted `.part` data remains attached to that card, while successful completion or explicit Delete removes only the exact UUID-owned cache. The model-level removal policy prevents deletion of queued, active, or completed jobs.
- Menu-bar pastes use the persisted default media type and video quality; matching clipboard content queues automatically.
- Quit App remains directly available from the menu-bar header and is not duplicated inside Settings. `QuitConfirmationDelegate` gates normal application termination (including Cmd-Q) with a localized native alert. Only explicit Yes terminates; No/Return/Escape stays, and Support opens Ko-fi while cancelling termination. Ordinary window closing is unaffected. Force Quit and termination signals are outside this UI gate.
- A compatible MP4 with H.264/HEVC and AAC is kept without conversion.
- GPU conversions are serialized.
- Smart cookie mode uses sessions first for sign-in-oriented social sites and domestic Bilibili, and retries YouTube once only after a recognized authentication error.
- Persistent YouTube 403/authentication/cookie-access failures may open one repair panel and send a notification; network, private, unavailable, and region errors must not be classified as session repair.
- Cookie values never enter app preferences, logs, history, extension storage, or documentation.
- Douyin browser resolution does not request the extension cookie permission. Chrome attaches cookies inside the active page request, and only an allowlisted short-lived media URL crosses the local bridge.
- Content scripts do not poll localhost or write `storage.sync`.
- Background preference synchronization runs at most once per minute and writes only changed keys.
- Generic detection requires explicit host permission.
- YouTube and Douyin adapters only create overlays for an opened/focused video.
- Local HTTP remains bound to loopback and rejects normal website origins.

## Test architecture

`Scripts/test.sh` is deterministic and network-free:

- Compiles a Swift core harness against URL normalization, request decoding, download/media-tool command construction, unique output naming, Finder Quick Action eligibility, cookie retry/session-repair classification, yt-dlp update policy, history persistence, origin policy, queue retention/removal, and session download-folder selection.
- Verifies all three Finder Service message names in `Info.plist`.
- Syntax-checks every extension JavaScript file.
- Runs Node tests for shared settings, URL tools, adapter contracts, and the no-content-script-polling/no-sync-write quota invariant.

`Scripts/build-app.sh` is a separate release gate that compiles SwiftUI/AppKit code, packages resources and the extension, and signs the bundle.

Real social-platform downloads and real browser cookie access are user-run functional tests because they are account-, network-, and platform-state-dependent.

## Hotspots

- Before changing a platform extractor or treating an error as expired cookies, read `PLATFORM-DOWNLOAD-TROUBLESHOOTING.md`. Keep observed response structure, synthetic test coverage, and user-confirmed functional results distinct. Reuse the diagnostic procedure across sites, not platform-specific endpoints/schema assumptions.

- Platform adapters are intentionally volatile because website DOM changes. Fix only the affected adapter unless the shared contract is wrong.
- `DownloadManager.swift` is the central published state owner. History persistence and yt-dlp timing have been extracted, but changes to queue concurrency, cancellation, job transitions, or notification sequencing still require focused regression coverage. Progress protocol changes belong in `ProgressProtocol.swift`, not in this coordinator or a SwiftUI view.
- macOS Services are system-controlled. Metadata and file eligibility are deterministic and tested, but final visibility depends on the user’s one-time Services approval and must be functionally checked in Finder after installation.
- `MediaToolCore.swift` is the stable offline-editing policy boundary. Add presets there and cover their arguments before exposing them in a module UI.
- `MediaToolRunner.swift` is shared mutable infrastructure. Keep workflow-specific selection and destructive options in their owning module, not in the runner.
- `LocalHTTPServer.swift` is a deliberately small HTTP implementation; add request-size, header, and routing tests before extending the protocol.
- `AppText.swift` still uses dictionary-based localization. If the product expands, migrate to string catalogs without moving download logic into the presentation layer.
- Codec compatibility rules in `MediaConverter.swift` affect destructive replacement of source files and require fixture-backed tests before broadening.
