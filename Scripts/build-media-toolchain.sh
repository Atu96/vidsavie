#!/bin/zsh
set -euo pipefail

# Build-only script. Never touches installed apps or managed user tools.
PROJECT_DIR="${0:A:h:h}"
TASK_ROOT="$PROJECT_DIR/.build/media-toolchain"
TASK_DOWNLOADS="$TASK_ROOT/sources"
TASK_PYTHON="${VIDSAVIE_BUILD_PYTHON:-$(command -v python3)}"
TASK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk"
[[ -d "$TASK_SDK" ]] || TASK_SDK="$(xcrun --sdk macosx --show-sdk-path)"
[[ "$(uname -m)" == arm64 ]] || { print -u2 'This recipe currently builds arm64 only'; exit 1; }
mkdir -p "$TASK_DOWNLOADS" "$TASK_ROOT/build-tools"
TASK_WORK="$(mktemp -d "$TASK_ROOT/build.XXXXXX")"
TASK_PREFIX="$TASK_WORK/prefix"
mkdir -p "$TASK_PREFIX"

fetch_source() {
  local filename="$1" url="$2" expected="$3"
  local target="$TASK_DOWNLOADS/$filename"
  if [[ ! -f "$target" ]] || [[ "$(shasum -a 256 "$target" | awk '{print $1}')" != "$expected" ]]; then
    curl --fail --location --silent --show-error --connect-timeout 15 --max-time 180 "$url" -o "$target.download"
    [[ "$(shasum -a 256 "$target.download" | awk '{print $1}')" == "$expected" ]] || { print -u2 "Source checksum mismatch: $filename"; exit 1; }
    mv "$target.download" "$target"
  fi
  tar -xf "$target" -C "$TASK_WORK"
}

# Checksums are pinned from Homebrew source metadata, 2026-10-06.
fetch_source ffmpeg-9.0.2.tar.xz https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz 8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
fetch_source lame-4.0.tar.gz https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz 3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb
fetch_source dav1d-1.5.4.tar.bz2 https://code.videolan.org/videolan/dav1d/-/archive/1.5.4/dav1d-1.5.4.tar.bz2 2abfb0c89212e6e4733a54e0ae509ec00a5b845a6360946f918806e14aedb011
fetch_source pkgconf-3.0.7.tar.xz https://distfiles.ariadne.space/pkgconf/pkgconf-3.0.7.tar.xz c926ff491cbd9a331a589160811bd97ab1749b4d5198a519338f2cdfabe6940a

# General build tools only; not redistributed inside the app.
if [[ ! -x "$TASK_ROOT/build-tools/bin/ninja" ]]; then
  "$TASK_PYTHON" -m pip install --disable-pip-version-check --target "$TASK_ROOT/build-tools" 'meson==1.12.1' 'ninja==1.13.2'
fi
TASK_NINJA="$TASK_ROOT/build-tools/bin/ninja"
[[ -x "$TASK_NINJA" ]] || { print -u2 'Ninja build tool is missing'; exit 1; }

cd "$TASK_WORK/pkgconf-3.0.7"
env CFLAGS="-O2 -mmacosx-version-min=13.0 -isysroot $TASK_SDK" LDFLAGS="-mmacosx-version-min=13.0 -isysroot $TASK_SDK" \
  ./configure --prefix="$TASK_PREFIX" --disable-shared --enable-static
make -j8
make install

cd "$TASK_WORK/lame-4.0"
env PKG_CONFIG="$TASK_PREFIX/bin/pkgconf" ac_cv_prog_cc_c23=no CFLAGS="-O2 -std=gnu99 -Wno-implicit-function-declaration -mmacosx-version-min=13.0 -isysroot $TASK_SDK" LDFLAGS="-mmacosx-version-min=13.0 -isysroot $TASK_SDK" \
  ./configure --prefix="$TASK_PREFIX" --disable-shared --enable-static --disable-frontend --disable-decoder
make -j8
make install

cd "$TASK_WORK/dav1d-1.5.4"
env PYTHONPATH="$TASK_ROOT/build-tools" NINJA="$TASK_NINJA" PKG_CONFIG="$TASK_PREFIX/bin/pkgconf" \
  CFLAGS="-O2 -mmacosx-version-min=13.0 -isysroot $TASK_SDK" LDFLAGS="-mmacosx-version-min=13.0 -isysroot $TASK_SDK" \
  "$TASK_PYTHON" -m mesonbuild.mesonmain setup build --prefix="$TASK_PREFIX" --libdir=lib --buildtype=release -Ddefault_library=static -Denable_tools=false -Denable_tests=false
env PYTHONPATH="$TASK_ROOT/build-tools" "$TASK_NINJA" -C build -j8
env PYTHONPATH="$TASK_ROOT/build-tools" NINJA="$TASK_NINJA" "$TASK_PYTHON" -m mesonbuild.mesonmain install -C build

cd "$TASK_WORK/ffmpeg-9.0.2"
env PKG_CONFIG_LIBDIR="$TASK_PREFIX/lib/pkgconfig" ./configure \
  --prefix="$TASK_PREFIX" --arch=arm64 --target-os=darwin --sysroot="$TASK_SDK" \
  --cc=/usr/bin/clang --cxx=/usr/bin/clang++ --pkg-config="$TASK_PREFIX/bin/pkgconf" --pkg-config-flags=--static \
  --disable-autodetect --disable-shared --enable-static --disable-debug --disable-doc --disable-ffplay \
  --disable-gpl --disable-nonfree --disable-version3 \
  --enable-libmp3lame --enable-libdav1d --enable-zlib --enable-securetransport --enable-videotoolbox --enable-audiotoolbox \
  --extra-cflags="-I$TASK_PREFIX/include -mmacosx-version-min=13.0" \
  --extra-ldflags="-L$TASK_PREFIX/lib -mmacosx-version-min=13.0"
make -j8
make install

TASK_OUTPUT="$TASK_WORK/output"
mkdir -p "$TASK_OUTPUT"
cp "$TASK_PREFIX/bin/ffmpeg" "$TASK_PREFIX/bin/ffprobe" "$TASK_OUTPUT/"
cp ffbuild/config.log "$TASK_OUTPUT/config.log"
cp config.h "$TASK_OUTPUT/config.h"
cp "$PROJECT_DIR/Scripts/build-media-toolchain.sh" "$TASK_OUTPUT/build-media-toolchain.sh"
for name in ffmpeg ffprobe; do
  [[ "$(lipo -archs "$TASK_OUTPUT/$name")" == arm64 ]]
  "$TASK_OUTPUT/$name" -version > "$TASK_OUTPUT/$name-version.txt" 2>&1
  "$TASK_OUTPUT/$name" -L > "$TASK_OUTPUT/$name-license.txt" 2>&1
  otool -L "$TASK_OUTPUT/$name" > "$TASK_OUTPUT/$name-linked-libraries.txt"
  if rg -q '/opt/homebrew|/usr/local|@rpath' "$TASK_OUTPUT/$name-linked-libraries.txt"; then
    print -u2 "Unexpected non-system dynamic dependency in $name"; exit 1
  fi
done
(cd "$TASK_OUTPUT"; shasum -a 256 ffmpeg ffprobe > checksums.sha256)
print "Media toolchain candidate: $TASK_OUTPUT"
