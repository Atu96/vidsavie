#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TOOLS_DIR="$PROJECT_DIR/.build/portable-tools"
mkdir -p "$TOOLS_DIR"

download_binary() {
  local name="$1"
  local url="$2"
  local expected="$3"
  local archive_kind="${4:-binary}"
  local destination="$TOOLS_DIR/$name"

  if [[ -f "$destination" ]] && [[ "$(shasum -a 256 "$destination" | awk '{print $1}')" == "$expected" ]]; then
    chmod 755 "$destination"
    return
  fi

  local work_dir
  work_dir="$(mktemp -d "${TMPDIR%/}/VideoBatchTool.XXXXXX")"
  local payload="$work_dir/payload"
  curl -L --fail --silent --show-error "$url" -o "$payload"

  local source="$payload"
  if [[ "$archive_kind" == "zip" ]]; then
    mkdir -p "$work_dir/unpacked"
    ditto -x -k "$payload" "$work_dir/unpacked"
    source="$(find "$work_dir/unpacked" -type f -name "$name" | head -1)"
    if [[ -z "$source" ]]; then
      rm -rf "$work_dir"
      print -u2 "Portable tool archive did not contain $name"
      exit 1
    fi
  fi

  local actual
  actual="$(shasum -a 256 "$source" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    rm -rf "$work_dir"
    print -u2 "Checksum mismatch for $name: expected $expected, found $actual"
    exit 1
  fi

  cp "$source" "$destination"
  chmod 755 "$destination"
  xattr -cr "$destination"
  rm -rf "$work_dir"
}

download_binary \
  "yt-dlp" \
  "https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp_macos" \
  "0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202"

TASK_MEDIA_MANIFEST="$PROJECT_DIR/Resources/Toolchain/media-release.json"
TASK_MEDIA_VALUES=("${(@f)$(node -e '
const fs = require("fs"), m = JSON.parse(fs.readFileSync(process.argv[1]));
if (m.schema !== 1 || m.provider !== "vidsavie-source-build" ||
    !m.archiveURL.startsWith("https://github.com/Atu96/vidsavie/releases/download/media-") ||
    ![m.archiveSHA256,m.ffmpegSHA256,m.ffprobeSHA256].every(x => /^[a-f0-9]{64}$/.test(x))) process.exit(1);
console.log([m.archiveURL,m.archiveSHA256,m.ffmpegSHA256,m.ffprobeSHA256].join("\n"));
' "$TASK_MEDIA_MANIFEST")}")
[[ "${#TASK_MEDIA_VALUES}" == 4 ]] || { print -u2 'Invalid reviewed media manifest'; exit 1; }
if [[ ! -f "$TOOLS_DIR/ffmpeg" || ! -f "$TOOLS_DIR/ffprobe" ]] ||
   [[ "$(shasum -a 256 "$TOOLS_DIR/ffmpeg" | awk '{print $1}')" != "$TASK_MEDIA_VALUES[3]" ]] ||
   [[ "$(shasum -a 256 "$TOOLS_DIR/ffprobe" | awk '{print $1}')" != "$TASK_MEDIA_VALUES[4]" ]]; then
  TASK_MEDIA_STAGE="$(mktemp -d "${TMPDIR%/}/VidSavieMediaBootstrap.XXXXXX")"
  curl --fail --location --silent --show-error --connect-timeout 15 --max-time 180 "$TASK_MEDIA_VALUES[1]" -o "$TASK_MEDIA_STAGE/media.zip"
  [[ "$(shasum -a 256 "$TASK_MEDIA_STAGE/media.zip" | awk '{print $1}')" == "$TASK_MEDIA_VALUES[2]" ]] || { print -u2 'Media archive checksum mismatch'; exit 1; }
  mkdir -p "$TASK_MEDIA_STAGE/unpacked"
  ditto -x -k "$TASK_MEDIA_STAGE/media.zip" "$TASK_MEDIA_STAGE/unpacked"
  [[ -f "$TASK_MEDIA_STAGE/unpacked/ffmpeg" && ! -L "$TASK_MEDIA_STAGE/unpacked/ffmpeg" ]]
  [[ -f "$TASK_MEDIA_STAGE/unpacked/ffprobe" && ! -L "$TASK_MEDIA_STAGE/unpacked/ffprobe" ]]
  [[ "$(shasum -a 256 "$TASK_MEDIA_STAGE/unpacked/ffmpeg" | awk '{print $1}')" == "$TASK_MEDIA_VALUES[3]" ]]
  [[ "$(shasum -a 256 "$TASK_MEDIA_STAGE/unpacked/ffprobe" | awk '{print $1}')" == "$TASK_MEDIA_VALUES[4]" ]]
  cp "$TASK_MEDIA_STAGE/unpacked/ffmpeg" "$TASK_MEDIA_STAGE/unpacked/ffprobe" "$TOOLS_DIR/"
fi
chmod 755 "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe"

[[ "$(lipo -archs "$TOOLS_DIR/yt-dlp")" == *arm64* ]]
[[ "$(lipo -archs "$TOOLS_DIR/ffmpeg")" == "arm64" ]]
[[ "$(lipo -archs "$TOOLS_DIR/ffprobe")" == "arm64" ]]

print "$TOOLS_DIR"
