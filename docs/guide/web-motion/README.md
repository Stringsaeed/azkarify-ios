# Painted standing-to-bowing web prototype

This prototype animates the painted character continuously. It replaces the previous image-fade experiment. It is an independent web implementation, not a Rive export, and covers standing, bowing, and the return only.

Open `standalone.html` in a browser for an offline, self-contained version. No server or dependencies are required.

For development, run from the repository root:

```sh
python3 -m http.server 8766 --bind 127.0.0.1 --directory docs/guide/web-motion
```

Open http://127.0.0.1:8766. Play, pause, return, scrub through the motion, or enable the checkerboard to inspect transparency.

## How it moves

- A single painted robe texture is drawn on a continuous triangular mesh. A distributed hip bend and a back-contour correction deform it without a waist cut.
- The feet and trousers stay fixed. The same face, hair and cap follow the neck throughout the movement.
- Hand paths release from the chest, descend, and approach the knees. Two-bone inverse kinematics positions the elbows. Each sleeve is one painted texture deformed along a smooth curve, with overlap at the cuff.
- The character remains opaque throughout. There are no whole-pose images, opacity transitions, or video frames in the interactive renderer.
- A forward movement takes 2.4 seconds. The loop holds each pose before returning. Timing is a visual-study choice, not the previous Rive contract's 1200 ms requirement.

The runtime is plain JavaScript and WebGL with no third-party browser dependencies. All assets are local. No artist was hired and no separately paid generation service was used. One new sleeve was generated through the existing built-in image tool; other painted textures were reused from the earlier asset work.

## Files

- `index.html`, `motion.js`: interactive browser prototype.
- `assets/`: self-contained artwork and layout metadata.
- `renders/standing-to-bowing.mp4`: 8-second recording rendered by this implementation, not an AI-generated video.
- `renders/movement-sheet.png`: five actual motion samples.
- `renders/pose-*-transparent.png`: transparent samples for inspecting joints and cloth.
- `renders/verification.json`: browser errors, control checks, reach checks and rendered-foot comparison.
- `render.cjs`: local verification and recording helper using Playwright, Sharp and ffmpeg. Its tool paths match this workstation; the browser prototype does not require these tools.

## Review limits

This is a movement prototype, not an accepted production prayer lesson. The hand shape and its contact with the knees, the shoulder overlap, and the robe folds still need visual judgment. The artwork is generated and differs from the original reference in details. The remaining eight postures are not implemented. iPhone Safari and WKWebView performance have not been tested.

The approach could be embedded in an iOS WKWebView or ported to another texture-mesh renderer after visual acceptance. That integration is not included here.

## Source references

The implementation uses the platform's WebGL shader pipeline. The recording helper composites the rendered canvas over the room with the standard [Canvas drawImage API](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/drawImage).
