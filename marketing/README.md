# App Store marketing assets

| Output | Spec |
| --- | --- |
| `app-store/screenshots/{en,ar}/01–08.png` | iPhone 6.9", 1320 × 2868, RGB PNG |
| `app-store/screenshots-ipad/{en,ar}/01–07.png` | iPad 13", 2064 × 2752, RGB PNG |
| `app-store/video/app-preview-iphone-6.9-886x1920.mp4` | App Preview, 886 × 1920, 30 fps, H.264 + AAC stereo, 22 s |
| `app-store/video/promo-1080x1920.mp4` | Same cut at 1080 × 1920 for social |

Everything uses the app's own assets: Alan Sans, the Icon Composer icon (exported with `ictool`), `JourneyCrescent`, `MosaicCurrency`, the botanical sprig shapes ported from `BotanicalBackground.swift`, and the reward sounds in `docs/design/sounds`. The soundtrack has no music.

`raw/` holds the simulator captures (iPhone 18 Pro Max; `raw/ipad/` from iPad Pro 13-inch (M5); status bar fixed at 9:41). `footage/` holds the screen recordings used in the video (148 MB, git-ignored; keep a copy to re-render).

## Regenerate

```sh
cd marketing/src
npm install                 # playwright-core; uses the installed Google Chrome
node screenshots.mjs        # iPhone; copy lives in COPY at the top of the file
node ipad-screenshots.mjs   # iPad 13"
./build-video.sh 886        # App Store preview
./build-video.sh 1080       # social cut
```

Captures were taken with launch arguments `-hasSeenIntro YES -hasPresentedPrayerLocationSetup YES -AppleLanguages "(en)" -accent <name> -theme <light|dark>`.
