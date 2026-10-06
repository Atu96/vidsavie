# VidSavie media toolchain 9.0.2-v1

This profile is built by the VidSavie project from pinned upstream sources, not from OSXExperts binaries. The FFmpeg implementation remains copyright its upstream authors.

| Source | Version | License | Archive SHA-256 |
|---|---|---|---|
| FFmpeg | 9.0.2 | LGPL-2.1-or-later under this configuration | `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e` |
| LAME | 4.0, encoding library only | LGPL-2.0-or-later | `3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb` |
| dav1d | 1.5.4, static AV1 decoder | BSD-2-Clause | `2abfb0c89212e6e4733a54e0ae509ec00a5b845a6360946f918806e14aedb011` |
| pkgconf (general build tool, not linked into FFmpeg) | 3.0.7 | ISC | `c926ff491cbd9a331a589160811bd97ab1749b4d5198a519338f2cdfabe6940a` |

Recipe: `Scripts/build-media-toolchain.sh`. Meson 1.12.1 and Ninja 1.13.2 are build tools only; Python, compiler and macOS SDK are general/platform build prerequisites and are not shipped in the app.

The media-source release package contains the exact downloaded source archives, the recipe, configuration and dependency license texts. Configure disables autodetection, GPL, nonfree and version3 components. The only statically linked external runtime code is LAME and dav1d; zlib and Apple frameworks are linked as system libraries. No x264/x265 is bundled in this profile. The source bundle includes the input archives and recipe for rebuilding FFmpeg/FFprobe and their static dependencies; build environment/path differences may change output hashes. Bit-for-bit reproducibility has not been claimed.

The app's tested media operations use VideoToolbox H.264, native AAC/PCM, LAME MP3, gate/loudness filters, PNG/JPEG and AV1/VP9 decoding. This profile is not a promise of every optional FFmpeg feature. Patent and platform SDK terms are separate from copyright licenses.

Current tool release and corresponding-source download:
https://github.com/Atu96/vidsavie/releases/tag/media-9.0.2-v1

Original unsigned FFmpeg SHA-256: `a969e652f635257b4d2728bf27ed5509665f798b8b722403c5f6e0dec3f341bb`.
Original unsigned FFprobe SHA-256: `e254e810b2f9b5b176290e0d270f1ce1ce13bfd7087645aacae55fbfb1ec5a31`.

Keep FFmpeg-LGPL-2.1.txt, LAME-LGPL-2.0.txt and DAV1D-BSD-2-Clause.txt with the redistributed profile. Project source GPL, yt-dlp standalone dependencies and historical distributions retain their separate scope and audit status.
