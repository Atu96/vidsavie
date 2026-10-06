# Working rules

These rules apply to every file under this repository.

## Source of truth

- Edit the workspace repository, not the installed application bundle.
- `/Users/gemst/Documents/Tools/VideoBatchDownloader` is a deployment mirror.
- `/Applications/Video Batch Downloader.app` is a built artifact.
- Preserve user data, browser profiles, cookies, download history, and unrelated local changes.

## Required workflow

1. Read `CHECKPOINT.md`, `SYSTEM-MAP.md`, and `ARCHITECTURE.md`.
2. Locate the owning layer and smallest affected module before editing.
3. Keep platform DOM logic inside its own file under `ChromeExtension/adapters/`.
4. Add or update a deterministic regression test for changed core behavior.
5. Run `./Scripts/test.sh`. Every test and JavaScript syntax check must pass.
6. Run `./Scripts/build-app.sh`. A release app must build and pass code-sign verification before deployment.
7. Bump the app build number for an installed-app change. Keep app and extension marketing versions aligned when both ship together.
8. Update `CHECKPOINT.md` and any architecture/system-map entry affected by the change.

## Distribution

- `./Scripts/build-dmg.sh` rebuilds the current release and emits a verified arm64 DMG plus SHA-256 checksum under `dist/`.
- The DMG must contain the signed app and an `/Applications` shortcut. Confirm the executable is arm64-only and mount-test the image before sharing it.
- The arm64 DMG is self-contained: package pinned, checksum-verified fallback copies of yt-dlp, FFmpeg, and FFprobe under `Contents/Resources/Tools`, and sign each nested executable before signing the app. Runtime resolution order is app-managed tools under Application Support, bundled fallback tools, then external paths. Never modify the signed bundle in place.
- The Support tools action installs or updates all three executables without Homebrew. It must download only from the allowlisted HTTPS sources in `SupportToolsInstaller`, verify published SHA-256 values before activation, inspect Mach-O bytes for arm64 without calling `lipo` or requiring Xcode Command Line Tools, smoke-test every executable, and preserve the previous managed tool directory on any failure. A first launch keeps using bundled fallbacks until the user explicitly chooses Install tools; installed managed tools receive the existing 24-hour update check.
- The current local release uses an ad-hoc signature. Do not claim Gatekeeper notarization unless a valid Developer ID identity is present and Apple's notary service has accepted the exact artifact.

## UI ownership

- Keep quick operational actions in the menu-bar window: paste, history, settings launch, and Quit App.
- Keep Video Cutter, Media Converter, and Audio Mastering as separate window scenes launched from the menu-bar footer. Opening a media tool hides the menu-bar panel, and closing a tool must not terminate the background app.
- Keep configuration in the centered settings window: storage, download defaults, engine maintenance, browser companion/session, language, theme, and about.
- Preserve visual hierarchy with `AppVisuals.swift`: use the shared background and `AppSurface` levels for native app chrome. Do not reintroduce low-contrast nested materials or ad-hoc primary-opacity cards.
- Menu-bar header actions must stay high contrast and visibly glass: translucent blue/purple navigation, a distinct reflective red/orange Quit control, and bold readable activity metrics.
- Dark themes use `AppGlassCanvas`: ambient blue/pink light belongs behind surfaces only. Keep it restrained; cards and controls must remain more legible than the canvas.
- `auto` follows macOS for color scheme but must use `AppGlassCanvas` whenever macOS is dark; do not fall back to the native gray window color. Empty-state space must be an intentional glass stage.
- Empty queue UI flows over the glass canvas: Quick Add flows into ready guidance through a subtle divider, with no enclosing rounded card. Do not split it into visually competing cards.
- Media-tool footer launchers use one calm white–pale-blue fill, a thin restrained black-glass outline, no drop shadow, white icon, bold label, and distinct tool tint.
- Keep the footer launcher contents centered. Keep the compact platform slogan on one header line; allow scaling rather than wrapping.
- Connection-status labels in the menu-bar header must remain one line; use a compact fixed-width label rather than allowing a two-line header.
- General is intentionally a fixed, non-scrolling page. Settings opens at its compact 860×760 minimum so its four General cards fit without a vertical scrollbar; only Browser Companion and Appearance may scroll when their content needs it. The sidebar footer is a centered Private local connection label only: do not show 127.0.0.1 or transient readiness text there. Sidebar/list and detail must share the settings glass canvas; use a fine divider rather than disconnected system-gray panels.
- Settings uses the standard opaque macOS title bar. Do not use full-size transparent title bar mode: it creates a second safe-area strip and may reveal content behind the window. Keep initial content size 900×780 (860×680 minimum).
- The menu-bar panel uses `MenuBarGlassCanvas`, separate from the settings/tool canvas: white–pale blue–light purple in Light and white highlights over deep blue/purple in Dark. Keep this palette coherent with Settings.
- Keep footer media launchers appearance-aware: Light uses the restrained white–pale-blue surface; Dark/Auto Dark uses blue-black glass, a white-to-black edge, and explicit white label contrast. Never rely on the inherited primary text color there.
- Appearance is a three-value contract only: `auto`, `dark`, `light`. Do not reintroduce Aurora/Neon. Normalize any legacy or unknown theme to `auto` in both `AppPreferences` and `ChromeExtension/lib/settings.js` so System mode cannot be overridden by stale synced storage.
- Apply appearance at both layers immediately: SwiftUI color scheme and each `NSWindow.appearance` (`.aqua`, `.darkAqua`, or `nil` for System). Do not defer `updateNSView`; it can leave stale foreground colors and introduce a System-mode delay. Dark Quick Add must use smoked glass, not a bright white input panel.
- System color must resolve from `NSApplication.shared.effectiveAppearance`, not an inherited SwiftUI `colorScheme` that may already be overridden by the active window. This prevents a Dark → System transition from reading its own stale Dark state.
- The menu-bar paste field is the primary entry point: use the brighter control surface, a white-top to black-glass-bottom edge, and only a restrained soft shadow; do not add duplicate borders or a loud gradient.
- The yt-dlp update control is a compact native-glass toggle, not an illustrative multi-stroke icon. Keep the blue sync glyph and small state badge aligned to the row.
- Download progress is truthful UI: only a real yt-dlp numeric percentage/fraction may advance `job.progress` and the active-card background fill. Never animate a decorative substitute for unavailable progress, and do not add a percentage label unless explicitly requested.
- A yt-dlp byte update can arrive before a total size. Preserve that received-byte/speed/ETA metadata and mark the job downloading, but advance the full-card progress fill only once a real total makes the fraction truthful. Keep the active card compact: do not restore a duplicate text row or decorative progress rail.
- All app-originated yt-dlp downloads must include `--progress` because Process pipes are non-interactive and yt-dlp otherwise suppresses its progress template entirely. Use a bounded `--progress-delta` rather than unthrottled UI callbacks.
- Bilibili throttle recovery belongs to the app-owned rolling-speed detector, not yt-dlp's `--throttled-rate` three-second trigger or its lifetime-average progress speed. Measure actual byte growth over the latest full minute, including timer samples while the connection stalls; below 500 KB/s triggers a bounded refresh that reuses the job's stable `.part` cache.
- Bilibili CDN rotation must use only `backupUrl` values returned by Bilibili's own play response through the bundled `Resources/YtDlpPlugins` override. Index zero keeps the primary URL; throttle refreshes stay on API-provided backups. Never synthesize mirror hosts, log signed URLs, persist media metadata, or broaden the override beyond Bilibili video/Bangumi/Cheese extractors.
- yt-dlp may transfer preferred video and audio streams independently. Present them as one monotonic whole-job progress using `DownloadTransferProgressAccumulator`; do not let the second stream visibly restart the card at zero or switch to a lower-quality progressive stream merely to simplify UI.
- Browser overlay discovery and display are intentionally limited to the middle 50% of the viewport. Preserve the `-25%` top/bottom IntersectionObserver root margin and the runtime focus-band hide check so controls do not crowd content at either screen edge.
- Keep social-image detection adapter-specific: Facebook must require post context and exclude UI/Marketplace/sponsored surfaces; X must require `tweetPhoto`. Do not broaden either selector to generic CDN images.
- Finder setup must use the case-sensitive KeyboardSettings route `x-apple.systempreferences:com.apple.Keyboard-Settings.extension?services` with lowercase `services`. Do not change its capitalization. Fall back to Keyboard Shortcuts and the guide only when opening that route fails. Keep compact Unicode symbols in service labels for recognizable Finder menu entries.
- The Finder guide must explicitly include expanding the `Files and Folders` disclosure group before asking the user to tick the three services. There is no public macOS command that safely expands that UI-only group; do not add brittle coordinate-based automation.
- The Finder walkthrough must mirror the full user-visible order: Keyboard Shortcuts… button, Services sidebar, Files and Folders disclosure, then three Video Batch checkboxes. Do not describe the partial deep link as a guaranteed direct Services launch.
- All external-tool progress parsing belongs in `ProgressProtocol.swift`. It returns normalized 0...1 fractions and is covered by the Foundation-only core test harness. Do not restore per-runner string parsing; support yt-dlp template/standard percentages and FFmpeg `out_time_us` / `out_time_ms` before changing a progress UI.
- Keep raw byte counts inside `ProgressProtocol` and models for exact arithmetic, but present them with `ProgressProtocol.displayBytes` in the UI. Do not expose raw byte integers to users.
- `ProcessRunner` must keep stdout and stderr on separate pipes and normalize CR/LF before delivering `onLine`. Do not merge the descriptors: yt-dlp emits progress on stderr and a shared pipe can delay or lose live callbacks.
- Opening Settings must hide the menu-bar window; closing Settings must not terminate the background app.
- Keep the configured download folder persistent. If it is unavailable, request a session-only replacement without overwriting preferences; a new app process must check and prefer the configured folder again.
- Companion setup must open the browser setup page and then bring Finder forward at app `Contents/Resources`, where the complete `ChromeExtension` directory is visible as the draggable install item. Do not open inside `ChromeExtension`.
- Chrome setup owns the animated Developer mode → drag-folder guide. Keep it non-blocking, reusable, localized, and Chrome-only unless another browser is verified to support the same workflow.
- External Chrome/Finder launches take application focus. Chrome setup must hide Settings and open the singleton SwiftUI `chrome-install-guide` window after those launches; do not use a detached AppKit panel.
- Session-related download failures may open the focused repair window. Keep its classifier deterministic: 403/authentication/cookie access may trigger repair; ordinary network, unavailable, private, and region errors must not.
- Failed and stopped jobs must remain retryable and individually removable. Interrupted download-stage jobs retain their exact per-card `.part` cache so Retry can continue; successful completion or explicit Delete removes it. Cache cleanup must validate the exact UUID-owned directory under `.VideoBatchDownloader-cache`; do not restore unconditional temporary-directory cleanup. Removal is restricted to failed/stopped jobs so queued, active, and completed work cannot be discarded accidentally. The completion banner hides the menu-bar panel before opening Finder at the completed file; it does not autoplay media.
- Keep Finder Quick Actions as routing only: `FinderQuickActions.swift` validates selected file types and opens the owning module. Processing, presets, output naming, and cancellation must continue through the existing module → `MediaToolCore` → `MediaToolRunner` path.
- Do not silently claim Quick Actions are enabled. macOS controls Services approval; Settings may request the direct Services deep link, register the bundled services, and show the looping three-checkbox guide, but the user must enable them once at Keyboard Shortcuts → Services → Files and Folders. Treat the deep-link anchor as best-effort and preserve the manual path in the guide.

## Native media tools

- Put deterministic FFmpeg arguments, output naming, extension classification, and presets in `MediaToolCore.swift`; keep AppKit/SwiftUI out of that file so the core harness can compile it.
- Put shared process execution, progress parsing, cancellation, and output reveal behavior in `MediaToolRunner.swift`.
- Each media module owns its imported-source state. Clear that state only after `MediaToolRunner.execute` returns successfully; never put import clearing in a `defer`, because failed and cancelled jobs must remain available for retry.
- Keep each product surface isolated in its owning module file: `VideoCutterModule.swift`, `MediaConverterModule.swift`, or `AudioMasteringModule.swift`. Reusable visual chrome belongs in `MediaToolViews.swift`.
- Media-tool runners are independent from one another and from the download queue. Do not route offline editing jobs through `DownloadManager`.
- Each native media module must support Finder drag-and-drop as well as the chooser. Video Cutter accepts one or many videos but must run them sequentially, retain original segment order, and place batch outputs in one folder per source. The converter accepts a single source category per batch and must only show presets compatible with that category; do not expose invalid cross-media options.
- Never overwrite generated media. Use the centralized unique-output policy; Video Cutter must expose a direct prefix and its automatic `0001_A` through `0026_Z` sequence while keeping FFmpeg numbering syntax internal. An empty prefix must yield `0001_A` without a leading underscore. The post-cut local rename pass belongs in `MediaToolRunner`. Creative reverse is an editing arrangement only: it must work for one or many inputs independently, preserve the source, and retain sequential batch execution.
- Video Cutter has exactly two arrangements: sequential and creative random. For multiple inputs, cut sources serially then emit one shared round-robin timeline (A1 → B1 → … → A2); random shuffles each source’s clips before that same round-robin merge. `_A` through `_Z` labels source identity, not segment count.
- Video Cutter also supports random source mix: shuffle each source and pick a non-repeating available source where possible. Default batch output is collision-safe `mixed_N` beside the first input; explicit folder selection remains an override.
- Destructive source cleanup must be explicit, recoverable through macOS Trash, and off by default. Video sources are never removed by Audio Mastering.
- The integrated app must not execute or import the old Raycast scripts or the standalone VideoSegmentCutter project at runtime.

Do not declare work complete if tests or the release build fail.

## Testing boundaries

- Automated tests must not download real media, call social platforms, read real browser cookies, or mutate the user’s download folder.
- The user performs real YouTube, Douyin, and social-platform functional tests.
- Test URL normalization, download/media-tool command construction, unique output naming, Finder Quick Action file eligibility and service metadata, retry/update policy, history persistence, origin policy, shared extension utilities, adapter contracts, and quota regressions locally.

## Security and privacy

- Never commit, print, export, copy, or upload browser cookie values.
- Store only browser name, cookie policy, and optional profile label.
- Browser sessions are passed directly to yt-dlp through `--cookies-from-browser`.
- Keep the local bridge bound to `127.0.0.1`.
- Do not restore wildcard CORS. Mutation requests from normal website origins must remain rejected.

## Extension performance

- Content scripts may read `storage.sync` but must not write it or poll the app.
- Background synchronization is browser-wide, at most once per minute, and writes only changed values.
- Prefer IntersectionObserver, debounced mutation handling, visibility checks, and per-element caches.
- New generic-site support must remain explicit opt-in.

## Deployment

- Stop the running app before replacing it.
- Build first, back up the exact installed bundle to a temporary path, copy the new bundle, verify its signature, launch it, and confirm `/health`.
- Reload the unpacked extension after extension source changes.
- Do not remove the temporary backup until the new app reports healthy.
