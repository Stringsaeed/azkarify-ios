# Astra brief: the prayer guide character in Rive

Goal: the same boy from the illustrations, as a 2D rig that the app drives with the Rive runtime. The app sets one number, `pose`, and Rive tweens the character from whatever pose it is in to the new one. That gives smooth, interruptible motion, Back for free, and keeps the illustration's look. No video, no 3D.

## What to share with Astra

Upload `~/projects/azkarify-guide-assets/rive-kit.zip`:

| File | Why |
| --- | --- |
| `references/guide-pose-*.jpg` (10 images) | The look and the exact pose per posture. `guide-pose-standing.jpg` is the master for proportions, colours and the camera. |
| this brief | The contract below. |

## The contract (paste into the first prompt)

- **Camera and side.** Side view, the boy faces LEFT, so the viewer sees his left side. Turning his head toward the viewer is a turn to his LEFT. All parts are drawn for this one view; no front view is needed.
- **Artboard.** Name `PrayerGuide`, 1080 x 1920, transparent background. The character stands on the mat with his feet at y = 1560 (the floor line of the room image) and his head top near y = 560 when standing; his body sits in the right half of the artboard, about x = 420 to 1000, because the speech bubble lives in the top third and the left half of the wall.
- **Parts.** Deliver the character as separate transparent PNGs at 2x (2160 x 3840 artboard space) in the illustration's painted style, one per part, each drawn COMPLETE including the areas normally hidden behind other parts, so rotation never shows a gap: `kufi`, `hair`, `head` (face, eyes, mouth, ears), `neck`, `torso_thobe` (chest to hips, including the placket), `skirt_thobe` (hips to below the knees, the part that folds when sitting and bowing), `upper_arm_near`, `forearm_near`, `hand_near` (open hand, fingers together), `hand_near_pointing` (fist with index finger extended, swapped in for tashahhud), `upper_arm_far`, `forearm_far`, `hand_far`, `thigh_near`, `shin_near`, `foot_near`, `thigh_far`, `shin_far`, `foot_far`, `trousers_near` and `trousers_far` if they are not part of the legs. "near" is the side facing the viewer (his left), "far" is the other side. Also a `layout.json` listing for each part its position on the artboard, its pivot point (the joint it rotates around), and its z-order from back to front.
- **Bones.** `hips` (root) > `spine` > `chest` > `neck` > `head`; `upper_arm_near` > `forearm_near` > `hand_near`; same for `far`; `thigh_near` > `shin_near` > `foot_near`; same for `far`. The skirt and the torso are bound with a mesh so they bend instead of breaking at the hips and knees; the rigid parts (head, kufi, hands, feet, shins, forearms) are bound to one bone each.
- **Animations.** Ten animations, one per posture, each a single keyframe pose at frame 0, named exactly: `standing` (right hand over left on the chest, eyes down), `takbir` (both hands open beside the ears, palms forward), `bowing` (torso 90 degrees forward, flat back, head in line with the back, hands on the knees, legs straight), `rising` (upright, arms relaxed at the sides), `prostrating` (knees down, forehead and nose on the mat, palms flat beside the shoulders, elbows up, toes tucked), `sitting` (sitting on the left foot, right foot upright, hands flat on the thighs), `tashahhud` (as sitting, near hand swapped to the pointing hand, eyes on the finger), `salamRight` (as sitting, head turned to his right, AWAY from the viewer, back of the kufi showing), `salamLeft` (as sitting, head turned to his left, TOWARD the viewer), `after` (sitting cross-legged, open palms raised in front of the chest, calm smile). Plus one `idle` animation: a slow 3 second breathing loop (chest scale 1 to 1.02) that can be layered on any pose.
- **State machine.** Name `Guide`. One Number input `pose` with these values: standing 0, takbir 1, bowing 2, rising 3, prostrating 4, sitting 5, tashahhud 6, salamRight 7, salamLeft 8, after 9. One state per animation. Transitions from Any State to each pose state with the condition `pose == n`, duration 1200 ms, ease in and out, and no transition when the value is unchanged. A second layer that loops `idle`. This is the whole API the app uses.
- **Files.** `room.jpg` (the empty room from prompt 1), `guide-character.riv` (Rive runtime format, built in the Rive editor or with Rive tooling), and the editor file or a share link so a human can open it. If you cannot produce the .riv, deliver the parts, `layout.json`, and a numbered build guide for the Rive editor that follows this contract step by step, with screenshots.

## Prompt 1: the parts

> I am building a kids' prayer guide for iOS. The character is the boy in the attached illustrations, and I want him as a 2D cutout rig in Rive so the app can tween between prayer postures. First deliverable: the character broken into rig-ready parts, in the same painted children's book style as the illustrations, matched to `guide-pose-standing.jpg` for proportions, colours and the side view. Follow the contract below exactly, especially the part list, the complete-part rule, and the artboard coordinates. Also deliver `room.jpg`: `guide-pose-standing.jpg` with the boy removed and the wall, floor and mat completed, same size, since the app draws the room behind the rig. Deliver the PNG parts, `room.jpg`, a flattened preview of the assembled standing pose over `room.jpg`, and `layout.json`. [paste the contract]

## Prompt 2: the rig and the poses

> Using the parts, build the Rive file: bones and mesh binding as in the contract, then the ten single-keyframe pose animations and the idle loop. Show me a still of each pose from the Rive artboard, assembled over the room. Check the fiqh details per pose against the matching reference image, especially the flat back in bowing, elbows off the mat in prostration, the right foot upright when sitting, and the salam directions (right is away from the viewer). [paste the pose list]

## Prompt 3: the state machine and export

> Add the `Guide` state machine exactly as the contract describes, with the `pose` number input, Any State transitions with 1200 ms eased blends, and the idle layer. Export `guide-character.riv` and tell me the file size. Also give me a 10 second screen recording or GIF of the state machine stepping through poses 0 to 9 in order, then back from 9 to 0.

## Prompt 4: iteration (reuse per round)

> Here is a screenshot from my app and my notes: [attach, list issues]. Change only what the notes ask for, keep the contract, and send the updated .riv and the editor file.

## What happens on my side

I add the Rive iOS runtime, build a `GuideStageRive` with the same interface as the current stage, map each `GuidePosture` to its `pose` number, and show the room image behind the artboard. Smooth motion, Back, and speed come from the state machine, so nothing else in the guide changes. If only the parts come back, I can also rig them in code as a fallback, so the parts deliverable is the one that matters most.
