# VidSavie media tools 9.0.2-v1 (dependency package, not the app installer)

FFmpeg and FFprobe arm64, built by VidSavie from pinned FFmpeg 9.0.2, LAME 4.0 and dav1d 1.5.4 sources. The executable distribution is LGPL-2.1-or-later under this configuration; LAME and dav1d retain their LGPL/BSD notices. This does not change the GPL license of original VidSavie app source or the separate yt-dlp licensing scope.

Assets:

- `vidsavie-media-9.0.2-v1-arm64.zip`: the two unsigned media executables and their component notices. The app verifies hashes and ad-hoc signs before activating managed tools.
- `vidsavie-media-9.0.2-v1-sources.tar.gz`: exact source input archives, build recipe, configuration information and notices for the static dependencies. No promise of bit-identical rebuilding across build environments.

Synthetic local tests passed for VideoToolbox H.264/AAC, copy/precise cut, conversion, MP3 encoding, gate/loudness processing, PNG/JPEG, AV1/VP9 decoding and ffprobe. HTTPS is enabled through Apple's SecureTransport. Only system frameworks/libraries are dynamically linked; no Homebrew runtime library is required.

This is an app-specific profile, not every optional FFmpeg codec/filter. Tests used generated media on one Apple Silicon Mac; real website downloads and all older Macs/macOS versions were not tested. Copyright licensing does not resolve codec patent or platform SDK obligations.

Full profile, source archive hashes and original executable hashes are in `Resources/ThirdParty/MEDIA-TOOLCHAIN.md`; the reviewed update feed is `Resources/Toolchain/media-release.json`.
