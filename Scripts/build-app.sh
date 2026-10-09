#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/.build/app/VidSavie.app"
EXECUTABLE="$PROJECT_DIR/.build/release/VideoBatchDownloader"
TASK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk"

if [[ ! -d "$TASK_SDK" ]]; then
  TASK_SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi

cd "$PROJECT_DIR"
SDKROOT="$TASK_SDK" \
SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR%/}/VideoBatchSwiftModuleCache" \
CLANG_MODULE_CACHE_PATH="${TMPDIR%/}/VideoBatchClangModuleCache" \
swift build --build-system native --disable-sandbox -c release

zsh "$PROJECT_DIR/Scripts/prepare-portable-tools.sh" >/dev/null

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/VideoBatchDownloader"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Resources/MenuBarIcon.png" "$APP_DIR/Contents/Resources/MenuBarIcon.png"
rm -rf "$APP_DIR/Contents/Resources/ChromeExtension"
cp -R "$PROJECT_DIR/ChromeExtension" "$APP_DIR/Contents/Resources/ChromeExtension"
rm -rf "$APP_DIR/Contents/Resources/YtDlpPlugins"
cp -R "$PROJECT_DIR/Resources/YtDlpPlugins" "$APP_DIR/Contents/Resources/YtDlpPlugins"
find "$APP_DIR/Contents/Resources/YtDlpPlugins" -type d -name '__pycache__' -prune -exec rm -rf {} +
rm -rf "$APP_DIR/Contents/Resources/Tools" "$APP_DIR/Contents/Resources/ThirdParty" "$APP_DIR/Contents/Resources/Toolchain"
mkdir -p "$APP_DIR/Contents/Resources/Tools"
cp "$PROJECT_DIR/.build/portable-tools/yt-dlp" "$APP_DIR/Contents/Resources/Tools/yt-dlp"
cp "$PROJECT_DIR/.build/portable-tools/ffmpeg" "$APP_DIR/Contents/Resources/Tools/ffmpeg"
cp "$PROJECT_DIR/.build/portable-tools/ffprobe" "$APP_DIR/Contents/Resources/Tools/ffprobe"
cp -R "$PROJECT_DIR/Resources/ThirdParty" "$APP_DIR/Contents/Resources/ThirdParty"
cp -R "$PROJECT_DIR/Resources/Toolchain" "$APP_DIR/Contents/Resources/Toolchain"
chmod 755 "$APP_DIR/Contents/Resources/Tools/yt-dlp" "$APP_DIR/Contents/Resources/Tools/ffmpeg" "$APP_DIR/Contents/Resources/Tools/ffprobe"
xattr -cr "$APP_DIR/Contents/Resources/Tools"
codesign --force --sign - "$APP_DIR/Contents/Resources/Tools/yt-dlp"
codesign --force --sign - "$APP_DIR/Contents/Resources/Tools/ffmpeg"
codesign --force --sign - "$APP_DIR/Contents/Resources/Tools/ffprobe"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
[[ "$(lipo -archs "$APP_DIR/Contents/Resources/Tools/yt-dlp")" == *arm64* ]]
[[ "$(lipo -archs "$APP_DIR/Contents/Resources/Tools/ffmpeg")" == "arm64" ]]
[[ "$(lipo -archs "$APP_DIR/Contents/Resources/Tools/ffprobe")" == "arm64" ]]
PYTHONDONTWRITEBYTECODE=1 "$APP_DIR/Contents/Resources/Tools/yt-dlp" --version >/dev/null
"$APP_DIR/Contents/Resources/Tools/ffmpeg" -version >/dev/null 2>&1
"$APP_DIR/Contents/Resources/Tools/ffprobe" -version >/dev/null 2>&1
echo "$APP_DIR"
