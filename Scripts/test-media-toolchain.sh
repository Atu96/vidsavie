#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
TASK_FFMPEG="${1:-$PROJECT_DIR/.build/media-toolchain/output/ffmpeg}"
TASK_FFPROBE="${2:-$PROJECT_DIR/.build/media-toolchain/output/ffprobe}"
TASK_REFERENCE="${3:-}"
TASK_FIXTURES="$(mktemp -d "${TMPDIR%/}/VidSavieMediaSmoke.XXXXXX")"

"$TASK_FFMPEG" -hide_banner -protocols 2>/dev/null | rg -q '^  https$'
"$TASK_FFMPEG" -hide_banner -encoders 2>/dev/null | rg -q 'h264_videotoolbox'
"$TASK_FFMPEG" -hide_banner -encoders 2>/dev/null | rg -q 'libmp3lame'
"$TASK_FFMPEG" -hide_banner -decoders 2>/dev/null | rg -q 'libdav1d'
"$TASK_FFMPEG" -hide_banner -filters 2>/dev/null | rg -q 'loudnorm'
"$TASK_FFMPEG" -hide_banner -filters 2>/dev/null | rg -q 'agate'

"$TASK_FFMPEG" -hide_banner -loglevel error -f lavfi -i 'testsrc2=size=128x96:rate=12' -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t 2 -c:v h264_videotoolbox -b:v 1M -g 12 -c:a aac -b:a 192k "$TASK_FIXTURES/source.mp4"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/source.mp4" -c copy -map 0 -f segment -segment_time 1 -reset_timestamps 1 "$TASK_FIXTURES/copy_%03d.mp4"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/source.mp4" -c:v h264_videotoolbox -b:v 8M -c:a aac -b:a 192k -map 0 -f segment -segment_time 1 -reset_timestamps 1 "$TASK_FIXTURES/precise_%03d.mp4"
"$TASK_FFMPEG" -hide_banner -loglevel error -hwaccel videotoolbox -i "$TASK_FIXTURES/source.mp4" -map 0:v:0 -map '0:a?' -c:v h264_videotoolbox -b:v 10M -c:a aac -b:a 192k -movflags +faststart "$TASK_FIXTURES/converted.mp4"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/source.mp4" -map 0:a:0 -vn -c:a libmp3lame -b:a 320k "$TASK_FIXTURES/audio.mp3"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/audio.mp3" -af 'agate=threshold=0.012:ratio=1.5:attack=15:release=220:range=0.18,loudnorm=I=-14:TP=-1.5:LRA=11' -c:a pcm_s24le -ar 48000 "$TASK_FIXTURES/mastered.wav"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/source.mp4" -map '0:v:0?' -map 0:a:0 -c:v copy -af 'agate=threshold=0.012:ratio=1.5:attack=15:release=220:range=0.18,loudnorm=I=-14:TP=-1.5:LRA=11' -c:a aac -b:a 192k -movflags +faststart "$TASK_FIXTURES/mastered.mp4"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/source.mp4" -frames:v 1 -compression_level 6 -update 1 "$TASK_FIXTURES/frame.png"
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/frame.png" -frames:v 1 -q:v 2 -update 1 "$TASK_FIXTURES/frame.jpg"

# These committed inputs were generated from lavfi test patterns, never user media.
if [[ -n "$TASK_REFERENCE" ]]; then
  "$TASK_REFERENCE" -hide_banner -loglevel error -f lavfi -i 'testsrc2=size=128x96:rate=2' -frames:v 2 -c:v libaom-av1 -cpu-used 8 -crf 40 "$TASK_FIXTURES/av1.mkv"
  "$TASK_REFERENCE" -hide_banner -loglevel error -f lavfi -i 'testsrc2=size=128x96:rate=2' -frames:v 2 -c:v libvpx-vp9 -deadline realtime -cpu-used 8 "$TASK_FIXTURES/vp9.webm"
else
  cp "$PROJECT_DIR/Tests/Media/synthetic-av1.mkv" "$TASK_FIXTURES/av1.mkv"
  cp "$PROJECT_DIR/Tests/Media/synthetic-vp9.webm" "$TASK_FIXTURES/vp9.webm"
fi
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/av1.mkv" -f null -
"$TASK_FFMPEG" -hide_banner -loglevel error -i "$TASK_FIXTURES/vp9.webm" -f null -

for file in source.mp4 copy_000.mp4 precise_000.mp4 converted.mp4 audio.mp3 mastered.wav mastered.mp4 frame.png frame.jpg; do
  [[ -s "$TASK_FIXTURES/$file" ]]
  "$TASK_FFPROBE" -v error -show_entries stream=codec_name -of csv=p=0 "$TASK_FIXTURES/$file" | rg -q '.'
done
print "Synthetic media checks passed: HTTPS capability, H264/AAC, copy/precise cut, conversion, MP3, mastering, PNG/JPEG, AV1/VP9 decode and ffprobe."
print "Fixtures retained at $TASK_FIXTURES"
