# VideoFetch Flow

Local-first macOS menu bar downloader with a Chrome/Firefox companion extension.

## Current behavior

- Downloads video, original audio, and images.
- Supports focused YouTube and Douyin videos plus X, Facebook, Instagram, Google Images, and opt-in generic websites.
- Processes one download at a time; later items remain in a FIFO queue.
- Prefers compatible MP4 media and converts incompatible video with Apple VideoToolbox.
- Keeps persistent download history with open, reveal, remove, and redownload actions.
- Shows percentage, speed, ETA, completion notifications, and a glass progress fill.
- Includes fallback yt-dlp, FFmpeg and FFprobe; offers one-click managed tool updates without Homebrew.
- Can use a selected local browser session. Smart mode retries YouTube with browser cookies only after an authentication or bot-verification error.
- Does not use a paid cloud API.

## Required validation

```sh
./Scripts/test.sh
./Scripts/build-app.sh
```

`test.sh` runs deterministic Swift core tests, JavaScript syntax checks, and Node extension tests. It does not download media or contact social platforms.

## Installation

Copy `.build/app/VideoFetch Flow.app` to `/Applications`.

For Chrome, open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select the bundled `ChromeExtension` directory.

## Branding and compatibility

Utility artwork from 2.2.39 differs from the app: the Chrome companion uses a square near-edge perforated film border, including 16/32 px action icons; the menu bar uses a monochrome circular outline. Both contain a downward lightning-arrow mark. Reload the unpacked companion after installation to refresh Chrome's cached icons.

Settings → About includes an optional Donate action with a red heart, linking to https://ko-fi.com/atu1202 in the default browser. The menu panel also offers a compact localized Support action immediately right of Completed in the metric strip. Donations are handled by Ko-fi, not inside the app.

VideoFetch Flow replaces the visible Video Batch Downloader name in 2.2.33 (135). The existing bundle identifier, executable name, `videobatch://` URL scheme, preferences, managed-tools directory and resumable-cache names remain unchanged for upgrade compatibility. Since 2.2.37 (139), `Scripts/render-brand.swift` reproduces centered lightning inside a tall perforated film strip in app, menu-bar and companion sizes; package the iconset using `iconutil` before building. The status icon is a simplified monochrome template, not a composite play/download symbol.

Read `CHECKPOINT.md`, `SYSTEM-MAP.md`, and `ARCHITECTURE.md` before changing runtime behavior.
