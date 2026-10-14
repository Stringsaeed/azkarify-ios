# Illustrated prayer guide prototype

Superseded by `../web-motion/` after the user required continuous body movement. This older experiment was made after the user ruled out paid production. It uses coherent whole-character paintings and a short fade between postures. It replaces continuous body interpolation with an illustrated presentation.

The prototype supports standing and bowing only. It retains artboard `PrayerGuide` and the Number input `Guide.pose`, using values `0` and `2`. It is not the completed ten-posture guide or a new skeletal character rig.

## Review

Play `renders/illustrated-preview.mp4`. The clip is captured from Rive, with input changes from standing to bowing and back. The room stays fixed. One drawing fades out before the other fades in, avoiding overlapping limbs and distorted clothing.

The nominal timings are a 200 ms fade out and a 300 ms fade in. Requests received during a fade are resolved at the next state boundary. Repeating the held value leaves the drawing unchanged.

## Artwork

`assets/standing.png` is a whole-character extraction generated from the original standing reference. `assets/bowing.png` is a generated whole-character redraw with a flatter back, based on the same identity reference. These are not pixel-identical copies of the originals. Each complete drawing is uniformly scaled, with the near sole at y=1560. The standing kufi begins at y=560.

The existing built-in image generation tool and installed Rive CLI were used. No contractor or separately paid model service was commissioned.

## Files

- `illustrated-pilot.riv`: interactive two-pose runtime.
- `illustrated-pilot.rev`: editable Rive export.
- `rive-source/`: the actual Rive scene and state machine.
- `layout.json`: dimensions, artwork placement, and supported inputs.
- `room.jpg`: the existing approved empty room.
- `source/`: generation provenance and prompts.
- `build.cjs`: packages the complete drawings and builds the scene.
- `render.cjs`: drives the real input and captures the review clip.

The original Rive kit remains available as a comparison. This prototype deliberately does not implement continuous bowing movement, breathing, the other eight postures, or iOS integration. Visual acceptance of this simpler direction remains open.
