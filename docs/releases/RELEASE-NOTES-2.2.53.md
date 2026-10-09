# VidSavie 2.2.53 (155)

## What's new

- New installations use Automatic browser-session usage and Chrome's Default profile. Saved choices are preserved. YouTube starts without cookies; recognized authentication failures can trigger a session retry. Other sites keep their existing session policy.
- Dedicated Browser session settings, shared profile-folder chooser, explicit Default shortcut and localized session-test diagnostics.
- Bounded directory-metadata preflight distinguishes missing profiles from permission failures without reading cookie values. Privacy guidance is user-controlled; Full Disk Access is not a default requirement or an automatic fix.
- Settings and other working windows temporarily appear in the Dock/Cmd-Tab and come forward on opening. Closing the last working window hides the Dock icon but keeps the menu-bar app running. Minimized windows remain switchable.

The user confirmed one YouTube download using Automatic and later clarified that Full Disk Access was also needed on their newer macOS installation. This is a user-reported result, not a trace proving which extraction tier succeeded or a requirement for every Mac. Changing policy alone is not claimed to resolve permission failures. Automated tests use synthetic fixtures, not real sessions. Native window behavior across all macOS versions remains unverified.

Verified on the release artifact: 196 Swift assertions, 52 companion/source-contract tests, release build, nested-tool smoke tests, strict/deep signature, arm64 executable, read-only DMG mount, Applications shortcut and portable checksum. DMG size: 62,522,040 bytes (about 60 MiB). SHA-256: `3f8b2d585755e7d64db52d83ac671dcfeb05d8445c61e914158a2d927fc7c509`.

## Install

Apple Silicon only (arm64; M1/M2/M3 and later). The source targets macOS 13+, but compatibility has not been tested on every OS version. No Intel package is available.

Download `VidSavie-2.2.53-arm64.dmg` and its `.sha256` file. Open the DMG and drag VidSavie to Applications. The app includes yt-dlp, FFmpeg and FFprobe; Homebrew and Terminal setup are not needed. Fresh installations start in English. Updates retain valid language and session preferences.

The app is ad-hoc signed, **not Developer ID signed or notarized**. macOS may show a warning. Only open trusted downloads; do not disable Gatekeeper globally.

For the Chrome floating button, follow Settings → Browser Companion setup. If you already use the unpacked companion, reload its card in `chrome://extensions` and refresh existing video tabs after replacing the app. The companion is version 2.2.53.

Bundled tools work before any managed install. Background checks compare release metadata; choose Update tools or Later. Downloads/installation require consent. FFmpeg updates follow the maintainer's published media profile, not every upstream release automatically.

## Licensing and source

Original project code is GPL-3.0-or-later; external tools and dependencies retain their own licenses. Included media profile 9.0.2-v1 has a [matching source package](https://github.com/Atu96/vidsavie/releases/tag/media-9.0.2-v1). **The standalone yt-dlp dependency-source set and other items remain under review** in the [licensing audit](https://github.com/Atu96/vidsavie/blob/main/LICENSING-AUDIT.md). No comprehensive binary-licensing certification is claimed; notices alone are not a substitute for corresponding-source obligations.

See the tag's source archive, build scripts and third-party notices. Previous release assets are retained; this release does not alter older installers.
