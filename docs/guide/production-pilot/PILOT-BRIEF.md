# Painted prayer character animation pilot

Create one polished eight-second production test of the supplied boy standing, bowing, and returning to the starting pose. Preserve the painted children's-book appearance. Deliver the animation in Rive with editable artwork and animation source.

The illustrations are the visual target. The previous generated rig is a rejected technical prototype. Its successful structural checks are not artistic acceptance.

## Creative direction

The boy is calm, attentive, and childlike. Preserve his large head relative to the body, gentle facial features, dark hair, ribbed off-white kufi, sand-coloured thobe, ivory trousers, and bare feet. Keep the soft pencil contours and restrained painted shading.

Maintain the same camera and left-facing body view. His left side is nearest the viewer. Use a single character model sheet to keep proportions, line weight, facial construction, and palette consistent across all drawings. Preserve proportions when scaling; do not resize body parts independently to fit predetermined boxes.

Build a coherent layered master drawing. Use deformation for small bends and displacement. Draw replacements when the silhouette, overlap, garment fold, or perspective changes substantially. A sleeve must continue to look like a sleeve when bent; a robe must retain volume rather than stretch into a polygon.

## The eight-second test

The supplied `timing-animatic.mp4` uses existing stills to describe timing. The missing intermediate drawings and motion remain to be authored. This loop is a production exercise; the complete guide will use the required prayer sequence.

| Time | Action | What makes it convincing |
| --- | --- | --- |
| 0.00–1.10 | Hold standing | Right hand over left on the chest. Eyes down. Feet planted. No whole-character scaling. |
| 1.10–1.80 | Release the hands | Fingers release first. Forearms separate and lower. The torso stays upright until the hands clear. |
| 1.80–3.20 | Bow | Hinge at the hips. Keep the feet planted and the legs straight. Hands travel toward the knees. Draw the cloth compression at the hips and changing arm overlaps. |
| 3.20–4.80 | Hold bowing | Back flat and horizontal, head aligned with it, hands resting on the knees. Settle the cloth subtly without wobbling the entire body. |
| 4.80–6.20 | Return upright | Hands release the knees as the torso rises. Preserve weight and contact. Author this direction separately if a reversed clip feels unnatural. |
| 6.20–7.10 | Return hands to the chest | Place the left hand, then the right over it. Keep fingers and wrist contact readable. |
| 7.10–8.00 | Hold standing | Settle gently into the opening pose for a clean loop. |

The bowing reference needs a posture correction: preserve the character and painting, but draw the back flatter than the supplied illustration. Do not treat the previous rig's horizontal bones as proof of a flat drawn back.

## Pilot deliverables

1. One character model sheet and colour reference.
2. Clean standing and bowing key drawings.
3. Rough breakdown drawings for hand release, the hip hinge, hand-to-knee contact, rising, and hand replacement.
4. A rough animated pilot for motion review before final painted cleanup.
5. The cleaned eight-second loop, plus the two directional movement clips and held poses.
6. Layered illustration source with named parts, replacement drawings, and complete hidden overlaps.
7. `pilot-character.riv`, the editable `.rev`, and the Rive source or editor link.
8. Transparent PNG assets at 2x, a full-colour preview over `room.jpg`, and a preview on a contrasting background.

The MP4 is a review export. The app asset remains a 2D Rive animation with the room drawn separately.

## Required runtime contract for the artist-built pilot

Keep artboard `PrayerGuide` at 1080 × 1920 with transparency. The near foot's standing contact is y=1560 and the head top is near y=560. Position the boy in the right half, leaving the upper and left wall clear. Match the approved raised mat in `references/room.jpg`.

Keep one public Number input named `pose` on `Guide`. The pilot needs destinations `0` for standing and `2` for bowing. The complete guide retains all ten original values.

Use authored movement timelines internally. The previous rule that every action must be a single-frame pose with a universal 1200 ms blend is superseded for this production method. Give each action the time and keys it needs.

For adjacent prayer steps, play the corresponding authored action before holding the destination. For a Back action, use a suitable reverse clip or an independently authored return. For a nonadjacent chapter jump, use a short fade reset or an explicitly approved route rather than distorting the body through an arbitrary blend.

Record the latest requested destination during an action. Change course at an authored safe point, such as after the hands have released or a foot has planted. No additional app input should be necessary. The exact interruption behaviour is part of the pilot demonstration.

The breathing loop must be secondary, with fixed contact points. It must not move the feet, inflate the head, or lift the hands from the knees.

## Visual acceptance

Review the rough motion at normal speed before reviewing technical exports. Then inspect the key drawings and the most extreme intermediate frames at enlarged scale.

- The boy remains recognisably the same character as the original standing illustration.
- The body keeps its volume and childlike proportions throughout the movement.
- Hands release, travel, and settle in a readable order.
- Wrist and elbow construction remains convincing; there are no exposed rounded cutout ends or visible duplicate limbs.
- Clothing folds are drawn or controlled intentionally. Texture and outlines do not smear, shear, or stretch unnaturally.
- Feet remain planted during the bow. Knees stay straight without a locked or hyperextended appearance.
- The back is flat in the held bow, and the head continues its line.
- No layer swaps, pops, ghosts, or gaps are visible at normal playback speed.
- The opening and closing held drawings match.

Passing file checks, connected-pixel checks, or joint-coordinate checks is insufficient for visual acceptance. Do not expand to the other prayer poses until this pilot has passed the visual review.

## Artist selection

Choose a character illustrator/animator with examples of a clothed human changing pose, convincing hands, and controlled texture or drawn linework. A portfolio of logo animation, UI transitions, or simple floating mascots does not establish these skills.

Request a fixed-price quote for this pilot, including layered source, editable Rive handoff, and a defined revision allowance. Ask for the artist's rough-motion milestone before painted cleanup. Do not commission the full ten-posture set before the pilot passes.

The quote must state the schedule, included revisions, ownership or commercial-use rights, permission to ship the embedded artwork, and any third-party asset restrictions. Ask which Rive editor and iOS runtime versions the deliverable targets. These terms are requests for a quote and are not an agreed commission.

The implementation team can handle the app integration, input wiring, export checks, device testing, and packaging. The artist owns drawing consistency, posing, timing, and cleanup.

## Why this method

Use replacement drawings where deformation visibly stretches a painted contour or texture. Identify those drawings during the rough-motion pass, before final cleanup.

Duolingo's documented [Rive production workflow](https://blog.duolingo.com/world-character-visemes/) separates character design and authored animation from runtime state-machine integration. This example supports the production method; they do not establish that any particular artist can reproduce this painted style.
