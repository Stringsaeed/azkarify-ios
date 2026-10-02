#!/bin/zsh
# Renders the app preview video. Usage: ./build-video.sh [width]  (886 = App Store 6.9", 1080 = social)
set -euo pipefail
cd "$(dirname "$0")"
W=${1:-886}
WORK=/tmp/azkarify-video
OUT=../app-store/video
mkdir -p $OUT
[[ -d .venv ]] || { python3 -m venv .venv && .venv/bin/pip -q install numpy; }
node video.mjs --width $W ${SKIP_EXTRACT:+--skip-extract}
.venv/bin/python audio.py $WORK/cues.json $WORK/audio.wav
NAME=$([[ $W == 886 ]] && echo "app-preview-iphone-6.9-886x1920" || echo "promo-${W}x1920")
ffmpeg -loglevel error -y -framerate 30 -i $WORK/frames-$W/%05d.jpg -i $WORK/audio.wav \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -crf 16 -preset slow -r 30 \
  -c:a aac -b:a 256k -ar 48000 -ac 2 -shortest -movflags +faststart $OUT/$NAME.mp4
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate:format=duration,size -of compact $OUT/$NAME.mp4
