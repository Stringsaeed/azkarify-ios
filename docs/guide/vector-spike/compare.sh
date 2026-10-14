#!/bin/sh
# side by side: render vs reference for one posture -> work/cmp-NAME.png
cd "$(dirname "$0")"
python3 render.py pose "$1" >/dev/null && ffmpeg -loglevel error -y -i out/pose-$1.png -i ~/projects/azkarify-guide-assets/poses/guide-pose-$1.jpg \
  -filter_complex "[0:v]scale=540:960[a];[1:v]scale=540:967,crop=540:960:0:0[b];[a][b]hstack" work/cmp-$1.png && echo work/cmp-$1.png
