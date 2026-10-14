# PrayerGuide Rive character

**Visual acceptance: rejected by the user.** The checks below establish technical behavior only. This file is a comparison prototype, not approved production artwork. The revised production approach is in `../production-pilot/PILOT-BRIEF.md`.

The runtime is `guide-character.riv`. Its artboard is `PrayerGuide`, its state machine is `Guide`, and its only input is the Number `pose`.

| pose | Animation |
| --- | --- |
| 0 | standing |
| 1 | takbir |
| 2 | bowing |
| 3 | rising |
| 4 | prostrating |
| 5 | sitting |
| 6 | tashahhud |
| 7 | salamRight |
| 8 | salamLeft |
| 9 | after |

Each posture has keys only at frame 0. Any State transitions use 1200 ms cubic ease-in-out, with control points `0.42, 0, 0.58, 1`. They permit interruption. Rive excludes the already active state as a transition destination, so assigning an unchanged value does not restart the pose. A separate layer loops `idle` over three seconds, scaling the chest from 1 to 1.02 and back.

## Delivered files

- `guide-character.riv`: runtime export, with embedded raster assets and no room background.
- `guide-character.rev`: editable Rive export.
- `rive-source/scene.rml`: the actual authored scene, bones, meshes, constraints, timelines, and state machine.
- `parts/`: 33 transparent PNGs, each 2160 × 3840. This includes the 19 required parts, the ear overlay, and 13 alternate parts.
- `editor/`: cropped 2x copies of those same assets.
- `layout.json`: positions, pivots, draw groups, variants, and mesh registration. PNG bounds describe source artwork; the Rive mesh registration aligns sleeve and trouser ends to the joints.
- `room.jpg`: the approved empty room with the raised mat, 1232 × 2208. Display at 1080 × 1920 behind the rig.
- `renders/poses/`: all ten poses over the room, captured by the Rive renderer.
- `renders/transitions/`: the three requested blends at 600 ms.
- `renders/transparency/`: standing and the four cloth stress poses against the renderer's dark backdrop.
- `renders/checks/`: isolated cloth and feet from the same renderer, used for the continuity and contact checks.
- `preview/alternate-parts-sheet.png`: the added head, hand, foot, and skirt views.
- `validation.json`, `contract-validation.json`, and `render-validation.json`: the recorded checks.
- `manifest.sha256`: hashes for the delivered assets and exports.

The source artwork and generation prompts are retained in `source/`. All new artwork was generated with the built-in image generation tool. The original trousers remain included in the thigh and shin images.

## What changed in this round

The torso and standing skirt come from one complete painted garment. Their shared 120-unit overlap contains identical pixels and uses matching weights. This removes the waist line without relying on the room to cover a gap.

The far wrist now registers the sleeve cuff to the hand joint. All four limb chains use two-bone IK. Ankle targets and foot-variant offsets keep the soles on the mat during the captured transitions. The neck blends between the neck and head bones to preserve the overlap when the head bends down.

The added artwork includes two complete salam head views with matching hair and kufi, two palm-forward hands, two cupped hands, two tucked-toe feet, a folded skirt, and a crossed-leg skirt. Two flat palm-down hands and a laid-back left foot support the contact poses. The head and limb alternatives use Solo groups, so inactive variants do not ghost through one another.

The torso and skirts retain mesh bindings. Seated and prostration poses also key mesh corrections at frame 0. Rigid head, hand, foot, shin, and forearm parts each retain a single-bone binding. The original bone hierarchy remains intact.

## Render verification

The render scene is separate from the exported character. It places `room.jpg` behind a nested instance of the real `PrayerGuide` artboard and drives the actual `Guide.pose` input. It adds no public controls to the runtime.

A pose capture settles for 119 frames at 60 fps. For a transition, the source pose settles first, the input changes at frame 120, and the capture occurs at frame 156, nominally 600 ms into the 1200 ms blend.

The isolated cloth check requires one connected painted region larger than 10,000 pixels. Components smaller than 100 pixels are ignored as antialiased edge specks. The foot check requires the lowest painted foot pixel to remain within y=1557–1561. Both checks cover the ten endpoints and three requested midpoints. These checks establish continuity and contact at those samples; they do not certify every frame of all 90 possible directed transitions.

Rive's structural checks cover the animation names, frame-zero keys, input mapping, transition duration and easing, idle timing, and rigid bindings. The exported editor file was also decompiled and rebuilt with Rive tooling. The iOS app itself was not changed or tested in this task.

The unchanged-input behavior is implemented by `StateMachineLayerInstance::canChangeState` and `changeState` in the [Rive runtime](https://github.com/rive-app/rive-runtime/blob/main/src/animation/state_machine_instance.cpp).

## Source entry points

`build-standing-rig.cjs` retains its first-round filename but now builds the complete character in `rive-source/`. `poses.cjs` contains the ten pose definitions. `package-extras.cjs` packages the alternate artwork, and `package-garment.cjs` creates the matching torso and skirt from the continuous garment. `render-poses.cjs` captures the real Rive state machine. `verify-renders.cjs`, `verify-contract.cjs`, and `verify-assets.cjs` record the checks.

The original first-round zip remains separate. Its standing-only runtime and editor guide are superseded by this package.
