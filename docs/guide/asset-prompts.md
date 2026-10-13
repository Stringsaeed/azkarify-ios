# Prayer guide assets: tools, prompts, and specs

Everything below produces two kinds of files the guide screen will load:

| Kind | Files | Used for |
| --- | --- | --- |
| Pose keyframes (PNG, 1080 x 1920) | `guide-pose-<name>.png` | the held frame of each chapter, the fallback when a clip is missing or Reduce Motion is on |
| Transition clips (MP4, 1080 x 1920, 2 to 3 s, no audio) | `guide-clip-<from>-to-<to>.mp4` | the animation played when Next moves to a chapter with a new posture |

Keep the same character, outfit, room, and camera in every frame. The character from PR 14 (`chapter-standing.jpg`) is the reference for all of them.

## 1. Tools

### Keyframes (image to image with a character reference)

Pick one and generate all keyframes in the same session so the style does not drift.

- **Gemini image (Nano Banana)**: best at keeping a character identical across edits. Upload the standing image, then ask for each pose. Free tier in Gemini or AI Studio.
- **OpenAI GPT Image** (ChatGPT or the Images API): also strong at edits from a reference, and supports a transparent background if you want the kid as a cutout.
- **Midjourney** with the character reference option (`--cref` or omni reference) and `--ar 9:16`: nicest painterly look, weaker at exact pose control.
- **Flux Kontext** (via fal.ai or Replicate): good pose edits from a reference, cheap, scriptable.

### Transition clips (image to video with a first and last frame)

The clip must start on keyframe A and end on keyframe B, so use a tool that accepts both a start and an end frame:

- **Kling** (start frame plus end frame mode): the most reliable for "go from this pose to that pose".
- **Runway Gen-4** (keyframes: first and last).
- **Luma Dream Machine** (start and end frame).
- **Google Veo in Flow** (first and last frame).
- Pika and Hailuo also work but drift more from the end frame.

Generate at 9:16, 2 to 3 seconds, 24 or 30 fps. Export MP4 (H.264), no audio.

### Cleanup

- **Remove.bg** or Photoshop or Pixelmator for cutting the kid out if you go the cutout route.
- **Topaz Video AI** or the tool's own upscaler if a clip comes out at 720p.
- **HandBrake** to re-encode every clip to H.264, 1080 x 1920, no audio, so iOS plays them all the same way.

## 2. Before you start: regenerate the standing frame

The PR 14 image is a frontal view. Bowing and prostration are unreadable from the front, so every keyframe should use the same three-quarter side camera. Regenerate standing first with that camera, then derive every other pose from the new standing frame.

Paste this as the base description every time (the "character block"):

```
Same character as the reference image: a young boy about seven years old, warm light-brown skin, short dark hair, white ribbed kufi cap, long beige thobe with a small chest placket, loose cream trousers, bare feet. Soft children's book illustration, thin pencil outline, flat muted colors, gentle paper texture, no shading gradients, no text, no watermark. Room: pale cream plaster wall, a small arched niche on the wall, warm wooden floor, a plain beige prayer mat, a soft diagonal shaft of morning light from the top left. Camera: fixed three-quarter view from the boy's right side, slightly above eye level, full body visible with space above the head and below the mat, portrait 9:16. Keep the character, outfit, colors, room, and camera identical to the reference.
```

## 3. Keyframe prompts

Use the character block first, then one of these pose lines. Keep the file names.

| File | Pose line |
| --- | --- |
| `guide-pose-standing.png` | Standing upright on the mat facing the niche, feet shoulder width apart, eyes lowered toward the mat, right hand placed over the left hand on the chest, calm neutral face. |
| `guide-pose-takbir.png` | Standing upright, both hands raised open beside the ears with palms facing forward, fingers together, eyes lowered, calm face. |
| `guide-pose-bowing.png` | Bowing forward from the hips with a flat straight back parallel to the floor, head in line with the back, both hands resting on the knees with fingers spread, legs straight, eyes toward the mat. |
| `guide-pose-rising.png` | Standing upright after bowing, arms relaxed straight down at the sides, eyes lowered, calm face. |
| `guide-pose-prostrating.png` | Prostrating on the mat: knees on the floor, forehead and nose touching the mat, palms flat on the mat beside the shoulders with fingers together pointing forward, elbows raised off the floor, toes tucked under so the toes touch the mat. |
| `guide-pose-sitting.png` | Sitting on the mat between prostrations: sitting on the left foot laid flat, right foot upright with toes on the mat, back straight, hands resting flat on the thighs near the knees, eyes lowered. |
| `guide-pose-tashahhud.png` | Sitting on the mat as before, left hand flat on the left thigh, right hand on the right thigh in a loose fist with the index finger pointing forward, eyes looking at the raised finger. |
| `guide-pose-salam-right.png` | Same seated pose with the right index finger down, hands flat on the thighs, head turned to look over the right shoulder, slight smile. |
| `guide-pose-salam-left.png` | Same seated pose, head turned to look over the left shoulder, slight smile. |
| `guide-pose-after.png` | Sitting cross-legged on the mat facing the niche, back straight, both hands raised in front of the chest with open palms facing up, peaceful smile. |

Tips:

- Generate the standing frame, check it, then upload it as the reference for every other pose. Do not chain pose to pose, or small errors pile up.
- Ask for "the same frame, only the pose changes". If the room drifts, say "keep the wall, niche, mat, and floor exactly as the reference".
- Prostration is the one that usually comes out wrong. If the elbows are on the floor or the forehead is lifted, reroll with "elbows lifted off the mat, forehead touching the mat".
- Keep the mat at the same place in every frame. The speech bubble sits in the empty wall space above the boy, so leave the upper third of the frame mostly empty.

## 4. Transition clip prompts

Each clip takes the two keyframes as first and last frame. Prompt text is short because the frames do the work. Use this motion block in every clip:

```
Same children's book illustration, static camera, no camera movement, no zoom, the room stays still, only the boy moves. Smooth, calm, slow movement, natural human motion, no extra limbs, no morphing of the face or clothing. 2 seconds.
```

| File | First frame | Last frame | Motion line |
| --- | --- | --- | --- |
| `guide-clip-standing-to-takbir.mp4` | standing | takbir | The boy raises both hands slowly to his ears, palms forward. |
| `guide-clip-takbir-to-standing.mp4` | takbir | standing | The boy lowers his hands and folds the right hand over the left on his chest. |
| `guide-clip-standing-to-bowing.mp4` | standing | bowing | The boy releases his hands and bends forward from the hips until his back is flat, placing his hands on his knees. |
| `guide-clip-bowing-to-rising.mp4` | bowing | rising | The boy straightens up slowly from the bow to stand upright with his arms at his sides. |
| `guide-clip-rising-to-prostrating.mp4` | rising | prostrating | The boy lowers to his knees, places his hands on the mat, and brings his forehead and nose down to the mat. |
| `guide-clip-prostrating-to-sitting.mp4` | prostrating | sitting | The boy lifts his head and chest and sits back on his left foot with his right foot upright, hands on his thighs. |
| `guide-clip-sitting-to-prostrating.mp4` | sitting | prostrating | The boy leans forward from sitting, places his hands on the mat, and lowers his forehead to the mat. |
| `guide-clip-prostrating-to-tashahhud.mp4` | prostrating | tashahhud | The boy sits up onto his left foot, rests his hands on his thighs, and raises his right index finger. |
| `guide-clip-tashahhud-to-salam-right.mp4` | tashahhud | salam-right | The boy lowers his index finger and slowly turns his head to look over his right shoulder. |
| `guide-clip-salam-right-to-salam-left.mp4` | salam-right | salam-left | The boy turns his head from the right shoulder across to look over his left shoulder. |
| `guide-clip-salam-left-to-after.mp4` | salam-left | after | The boy turns his head back to face forward, shifts to sit cross-legged, and raises his open palms in front of his chest. |

Tips:

- Generate standing to bowing first. If the tool cannot hold the room still on that one, switch tools before doing the rest.
- The app holds the keyframe PNG after each clip and crossfades over the last few frames, so a small drift at the end of a clip is hidden. A drift at the start is not, so reroll any clip whose first frames jump.
- If a tool only allows one frame, use the first frame and describe the end pose in words, then crop or trim so the last frame is close to the keyframe.

## 5. How the clips map to the chapters

| Hisn chapter | Held pose | Clip played on entry |
| --- | --- | --- |
| 16 opening (standing) | standing | none, or takbir in and out as an intro |
| 17 bowing | bowing | standing-to-bowing |
| 18 rising | rising | bowing-to-rising |
| 19 prostration | prostrating | rising-to-prostrating |
| 20 between prostrations | sitting | prostrating-to-sitting |
| (second prostration, no new text) | prostrating | sitting-to-prostrating |
| 22 tashahhud | tashahhud | prostrating-to-tashahhud |
| 23 blessings on the Prophet | tashahhud | none |
| 24 before the salam | tashahhud | none |
| salam (no Hisn text) | salam-left | tashahhud-to-salam-right, then salam-right-to-salam-left |
| 25 after the prayer | after | salam-left-to-after |

## 6. Delivery

Put the finished files in a folder named `guide-assets` anywhere and tell me the path. I will resize, re-encode, add the PNGs to the asset catalog, bundle the MP4s, and wire the names into the scene catalog. Size budget is about 1.5 MB per clip and under 400 KB per PNG, which HandBrake and a PNG optimizer will reach.
