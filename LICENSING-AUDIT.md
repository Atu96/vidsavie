# VidSavie licensing audit

Checked: 2026-10-06. This is an evidence-based inventory, not a legal opinion or a certification of complete compliance.

## 1. Scope of the project's GPL grant

The owner selected **GPL-3.0-or-later** for project-authored source. The unmodified GPLv3 text is in `LICENSE`; the copyright, version choice and scope are in `COPYRIGHT`. Commercial use and sale are allowed subject to the license. There is no non-commercial restriction, donation requirement, or additional restriction added to GPL.

| Material | Classification | License / owner boundary |
|---|---|---|
| `Sources/VideoBatchDownloader/*.swift` | Project-maintained app UI, queue, download orchestration, local bridge, media tools and preferences | GPL-3.0-or-later for original project code; not ownership of Apple SDK/framework implementations |
| `ChromeExtension` JS/HTML/CSS and adapters | Project-maintained browser integration | GPL-3.0-or-later for original project code; browser APIs are not vendored library code |
| `Scripts`, `Tests`, `Package.swift`, project configuration | Project-maintained build/test code | GPL-3.0-or-later for original project code; preserve any specific upstream notice if later discovered |
| `Resources/YtDlpPlugins/.../video_batch_bilibili.py` | Project integration importing yt-dlp extractor classes | GPL-3.0-or-later for the project's adapter; imported yt-dlp implementation is external and not claimed as original |
| yt-dlp executable and dependencies inside it | Unmodified external distribution before local code-signing | Upstream notices and source obligations, not the project's copyright |
| FFmpeg and FFprobe executables / statically included libraries | External distribution before local code-signing | Upstream notices and source obligations, not the project's copyright |
| Current and historical image assets | Separate artwork/provenance category | Do not assume every PNG is covered by the source grant; see below |

`Package.swift` declares no external Swift package dependency. The npm package is a test runner and declares no third-party npm dependency. Source imports inspected are Apple/system modules and yt-dlp in the integration plugin. These facts do not prove that no snippet or asset ever originated elsewhere: provenance beyond available project records is not certified. Specific third-party notices take precedence over a broad project-source statement.

The app invokes executable tools through `ProcessRunner`; this is not a claim that the app directly embeds FFmpeg library code. Distribution of those executables still carries their own obligations. Running tools as subprocesses alone is not a complete legal analysis of derivative-work boundaries.

## 2. What was checked in the bundled tools

Hashes below identify original downloaded files **before signing**. Signed copies and the DMG have different hashes.

| Tool | Version / original SHA-256 | Observed licensing |
|---|---|---|
| yt-dlp macOS standalone | 2026.08.19 / `0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202` | Core source: Unlicense. Upstream states PyInstaller standalone distributions combine dependencies under GPLv3+; preserve all component notices |
| FFmpeg arm64 | 9.0 / `591260c945d0eef150e3bf82b0ef988bd36a9cecc18ff05d6679617159f0a95e` | `ffmpeg -L` explicitly states GPL version 2 or later; configure includes `--enable-gpl`, x264, x265 and other external libraries |
| FFprobe arm64 | 9.0 / `e11c17e8200b3ee4c4c186d245e2b4053f01d56957336c1817fca0b997469106` | `ffprobe -L` explicitly states GPL version 2 or later, same configure flags |

No `--enable-nonfree` flag was observed. That is **not** proof that every static dependency is licensed compatibly, nor an exhaustive patent/redistribution clearance.

Evidence:

- [FFmpeg license explanation](https://www.ffmpeg.org/legal.html).
- [yt-dlp licensing at the pinned tag](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/README.md#licensing).
- [yt-dlp third-party notices at that tag](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/THIRD_PARTY_LICENSES.txt).
- [Binary provider and published checksums](https://www.osxexperts.net/).

## 3. License documents preserved in source

Under `Resources/ThirdParty`:

- `GPL-2.0.txt`: unmodified GPLv2 text, for GPLv2-or-later components.
- `GPL-3.0.txt`: unmodified GPLv3 text, for the project's grant and applicable tool distributions.
- `YTDLP-UNLICENSE.txt`: upstream yt-dlp core license from tag 2026.08.19.
- `YTDLP-THIRD-PARTY-LICENSES.txt`: complete upstream dependency notice bundle from tag 2026.08.19, original SHA-256 `472aefe951c7db35e1657c1d13fd337140511ed6f2b329205105ad441c5a02b7`.
- `PORTABLE_TOOLS.md`: source/version/hash references, separate from the license texts.

Keeping license texts is necessary but does **not**, by itself, satisfy a requirement to provide corresponding source. The upstream notice collection does not establish exact dependency versions inside every executable or every future managed update.

## 4. Unresolved binary redistribution requirements

**Status: pending. Do not describe the existing installer or a new installer as fully licensing-verified.**

### FFmpeg / FFprobe

On the audit date, the provider's "Source used to compile" link for the advertised 9.0 arm64 files resolves to [FFmpeg release/6.1](https://github.com/FFmpeg/FFmpeg/tree/release/6.1), while both bundled executables report 9.0. That link is not verified corresponding source for these binaries.

The configure line also includes static external libraries. Their exact versions, patches, notices and build inputs have not been established. A generic upstream FFmpeg tarball or a link to an unrelated branch is not presented here as a substitute for that information.

To close this item, obtain the actual corresponding source and build inputs from the producer, or replace the tools with a reproducibly built distribution whose exact sources, dependency versions, patches and licenses can be provided. Do not contact the producer on the user's behalf without permission; do not promise source the project cannot supply.

The provider's page also uses "educational purposes only" wording. Its interpretation and the full distribution terms have not been resolved; this audit does not treat that wording as permission for all commercial distribution or as changing upstream GPL rights.

### yt-dlp standalone

The core tag and upstream notice bundle are identified. The exact source/build/dependency set corresponding to the combined standalone binary has not been mirrored or independently reproduced. Upstream's notice describes original-project sources and an upstream source contact; that is not an independent written source offer by VidSavie.

Before certifying binary redistribution, verify and provide a permitted corresponding-source route for all covered dependencies. Do not rely on "core is Unlicense" to ignore the executable's GPL and other bundled components.

### Managed tool updates

Updates download later binaries after checksum/architecture checks. Those checks do not check licenses or source completeness. Future versions need version-matched notices and corresponding-source handling; the notices pinned here must not silently be attributed to all future updates.

## 5. Artwork and ownership limits

`Scripts/render-brand.swift` is the project's code-native renderer for current app/menu/companion artwork. That generation route is documented; historical master/versioned PNGs also remain in the repository, and their complete provenance is not independently established by this audit. Do not claim that every old asset is original or relicense third-party artwork as the user's work. Obtain provenance/permission or omit uncertain legacy assets from a redistributed source/asset package.

Apple framework implementations, system fonts and system symbols are not claimed as project-authored code. This source review is not an audit of every applicable Apple asset/SDK distribution term.

## 6. Published installer versus source updates

Release v2.2.44 was built before these license documents were added. Its DMG remains unchanged: SHA-256 `16330e112f6e3699ff5482b2d2ed1692e3b7535f3e686e84a4f7975a3124794d`. Updating the main branch does not insert documents into that already signed installer or rewrite its source tag.

No new binary release is authorized as "compliance complete" by this audit. Existing assets have not been removed or hidden. The owner should decide whether to pause their distribution while corresponding-source issues are resolved. A next binary release must include applicable notices, the project's GPL text/scope, and a verified source-compliance plan, then be rebuilt and signed normally.
