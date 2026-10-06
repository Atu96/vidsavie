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

download_binary \
  "ffmpeg" \
  "https://www.osxexperts.net/ffmpeg9arm.zip" \
  "591260c945d0eef150e3bf82b0ef988bd36a9cecc18ff05d6679617159f0a95e" \
  "zip"

download_binary \
  "ffprobe" \
  "https://www.osxexperts.net/ffprobe9arm.zip" \
  "e11c17e8200b3ee4c4c186d245e2b4053f01d56957336c1817fca0b997469106" \
  "zip"

[[ "$(lipo -archs "$TOOLS_DIR/yt-dlp")" == *arm64* ]]
[[ "$(lipo -archs "$TOOLS_DIR/ffmpeg")" == "arm64" ]]
[[ "$(lipo -archs "$TOOLS_DIR/ffprobe")" == "arm64" ]]

print "$TOOLS_DIR"
