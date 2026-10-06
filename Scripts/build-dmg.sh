#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="VidSavie"
APP_PATH="$PROJECT_DIR/.build/app/$APP_NAME.app"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUILD="$(plutil -extract CFBundleVersion raw "$INFO_PLIST")"
OUTPUT_DIR="$PROJECT_DIR/dist"
DMG_PATH="$OUTPUT_DIR/VidSavie-$VERSION-arm64.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
STAGING_DIR="$(mktemp -d "${TMPDIR%/}/VideoBatchDMG.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_DIR/Scripts/build-app.sh" >/dev/null

ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/VideoBatchDownloader")"
if [[ "$ARCHS" != "arm64" ]]; then
  print -u2 "Expected an arm64-only app, found: $ARCHS"
  exit 1
fi

codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$OUTPUT_DIR" "$STAGING_DIR/$APP_NAME $VERSION ($BUILD)"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME $VERSION ($BUILD)/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/$APP_NAME $VERSION ($BUILD)/Applications"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR/$APP_NAME $VERSION ($BUILD)" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null
(cd "$OUTPUT_DIR"; shasum -a 256 "${DMG_PATH:t}") > "$CHECKSUM_PATH"

print "$DMG_PATH"
print "$CHECKSUM_PATH"
