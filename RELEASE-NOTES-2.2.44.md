# VidSavie 2.2.44

## Licensing audit update — 2026-10-06

Project-authored source is now offered under GPL-3.0-or-later; third-party tools retain their own licenses. **Corresponding-source verification for the bundled tools is still pending.** The existing installer predates the new license documents and has not been replaced. In particular, the FFmpeg provider's source link does not match the version reported by the bundled binaries. See the [licensing audit](https://github.com/Atu96/vidsavie/blob/main/LICENSING-AUDIT.md) for evidence, ownership boundaries and unresolved requirements. Do not treat this release as licensing-compliance certified.

Download. Cut. Convert. Your everyday media toolkit for Mac.

## What's included

- Video, audio, and image downloads from supported sites, with a sequential queue and resumable partial downloads where available.
- Built-in video cutting, media conversion, and audio processing tools.
- Chrome companion with floating download controls and synced settings.
- Bundled yt-dlp, FFmpeg, and FFprobe, plus in-app support-tool updates.
- English by default on fresh installations. Existing language preferences stay unchanged; other languages and System mode remain available in Settings.

## Installation

This installer is **Apple Silicon / arm64 only**. Open the DMG and drag VidSavie into Applications.

The app is ad-hoc signed, **not Developer ID signed or notarized by Apple**. macOS may display a warning. Only open a copy from a source you trust; do not disable Gatekeeper across your Mac.

The Chrome companion is bundled with the app, not installed automatically. Use Settings → Browser Companion for setup. Existing companion users should reload the unpacked extension and reopen their video tabs.

Website support varies by content, account access, region, and changes to the source sites. Please only download content you have permission to save. Real platform downloads are not covered by the automated test suite.

The matching `.sha256` file is provided to verify the DMG download. The repository and this release are publicly accessible.

If the app helps, you can [buy me a coffee on Ko-fi](https://ko-fi.com/atu1202). No pressure — thanks for trying it. ❤️
