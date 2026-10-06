#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TASK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

if [[ ! -d "$TASK_SDK" ]]; then
  TASK_SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi

cd "$PROJECT_DIR"
zsh -n Scripts/prepare-portable-tools.sh
swiftc \
  -sdk "$TASK_SDK" \
  -parse-as-library \
  -module-cache-path "${TMPDIR%/}/VideoBatchSwiftCoreTestModuleCache" \
  Sources/VideoBatchDownloader/Models.swift \
  Sources/VideoBatchDownloader/AppPreferences.swift \
  Sources/VideoBatchDownloader/DownloadStateServices.swift \
  Sources/VideoBatchDownloader/ProcessRunner.swift \
  Sources/VideoBatchDownloader/SupportToolsInstaller.swift \
  Sources/VideoBatchDownloader/URLNormalizer.swift \
  Sources/VideoBatchDownloader/ProgressProtocol.swift \
  Sources/VideoBatchDownloader/BrowserSession.swift \
  Sources/VideoBatchDownloader/FileNameTemplate.swift \
  Sources/VideoBatchDownloader/DownloadCommandBuilder.swift \
  Sources/VideoBatchDownloader/MediaToolCore.swift \
  Sources/VideoBatchDownloader/LocalAPIOriginPolicy.swift \
  Tests/Swift/CoreTestMain.swift \
  -o "${TMPDIR%/}/VideoBatchCoreTests"
"${TMPDIR%/}/VideoBatchCoreTests"

[[ "$(plutil -extract NSServices.0.NSMessage raw Resources/Info.plist)" == "cutVideo" ]]
[[ "$(plutil -extract NSServices.1.NSMessage raw Resources/Info.plist)" == "convertMedia" ]]
[[ "$(plutil -extract NSServices.2.NSMessage raw Resources/Info.plist)" == "masterAudio" ]]
rg -qF 'com.apple.Keyboard-Settings.extension?services' Sources/VideoBatchDownloader/FinderQuickActions.swift
if rg -qF 'com.apple.Keyboard-Settings.extension?Services' Sources/VideoBatchDownloader/FinderQuickActions.swift; then
  print -u2 "Finder Services route must remain lowercase"
  exit 1
fi

for source in ChromeExtension/*.js ChromeExtension/lib/*.js ChromeExtension/adapters/*.js; do
  node --check "$source"
done

/usr/bin/python3 -c \
  'import ast, pathlib; ast.parse(pathlib.Path("Resources/YtDlpPlugins/yt_dlp_plugins/extractor/video_batch_bilibili.py").read_text())'

npm run test:extension
