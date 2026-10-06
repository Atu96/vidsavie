# Portable tool notices

VidSavie's arm64 distribution includes third-party command-line tools so a recipient does not need Homebrew or a separate Terminal setup. Their implementation is not authored by VidSavie. New builds use the project-built media profile described in `MEDIA-TOOLCHAIN.md`; source and notices accompany its reviewed tool release. yt-dlp standalone dependency-source review remains separate; see the root `LICENSING-AUDIT.md`. Do not interpret a successful build or checksum check as comprehensive legal certification.

## yt-dlp 2026.08.19

- Core source is Unlicense; upstream identifies the PyInstaller standalone combined distribution as GPLv3+. Preserve `YTDLP-UNLICENSE.txt`, `GPL-3.0.txt` and the complete version-matched `YTDLP-THIRD-PARTY-LICENSES.txt`.

- Source and license: https://github.com/yt-dlp/yt-dlp
- Official macOS standalone release: https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19
- Bundled file SHA-256: `0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202`

## Current FFmpeg / FFprobe 9.0.2 arm64 source build

- Project-built from pinned FFmpeg, LAME and dav1d inputs; only platform/system dynamic libraries are needed at runtime.
- FFmpeg/FFprobe report LGPL-2.1-or-later under the controlled configuration; LAME is LGPL-2.0-or-later, dav1d BSD-2-Clause. Read the preserved component texts and `MEDIA-TOOLCHAIN.md`.
- Release, executable/source/archive hashes: https://github.com/Atu96/vidsavie/releases/tag/media-9.0.2-v1 and `Resources/Toolchain/media-release.json`.
- The managed updater verifies and retains the exact matching source archive and component notices before activating the reviewed media pair. It no longer parses/downloads OSXExperts media releases.

## Historical FFmpeg / FFprobe 9.0 profile in app 2.2.44

- The actual bundled tools report GPLv2-or-later (`-L`) and `--enable-gpl`. Preserve `GPL-2.0.txt` / `GPL-3.0.txt` as applicable; statically included components keep their own copyrights and source obligations.
- The provider's current source link resolves to release/6.1 rather than the bundled 9.0. Exact corresponding source, static dependency versions and build inputs remain unverified. A generic source URL is not a certification of complete compliance.

- FFmpeg project and license information: https://ffmpeg.org/
- Static Apple Silicon build and corresponding build-source link: https://www.osxexperts.net/
- FFmpeg SHA-256: `591260c945d0eef150e3bf82b0ef988bd36a9cecc18ff05d6679617159f0a95e`
- FFprobe SHA-256: `e11c17e8200b3ee4c4c186d245e2b4053f01d56957336c1817fca0b997469106`

The bundled binaries are code-signed as nested executables when the app bundle is built. Their original downloaded bytes are verified against the pinned checksums before signing.

The optional in-app Support tools installer uses the official yt-dlp latest-release checksum list and the Apple Silicon FFmpeg/FFprobe URLs plus checksums published on OSXExperts. Downloads are staged under the current user's Application Support directory, verified before signing, and activated only after all three executables pass architecture and launch checks. The signed app bundle is never modified.
