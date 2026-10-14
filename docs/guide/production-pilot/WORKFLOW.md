# Prayer character production pilot

**Superseded constraint: paid production was declined by the user.** The active experiment is the no-paid illustrated presentation in `../illustrated-pilot/`. This folder retains the earlier production planning and audit.

- [x] Read the Poteto principles required by figure-it-out.
- [x] Ground the decision in the rejected v2 renders, original illustrations, and available tools.
- [x] Prepare a reference-based timing animatic and a specific animator brief.
- [x] Compare the original artwork with the generated rig in uniformly scaled side-by-side panels.
- [x] Independently review the decision trail and handoff with gpt-5.6-sol.
- [x] Prepare the production decision, review artifacts, and remaining production dependency for handoff.

## Frame

The failed premise was that separately generated body parts and increasingly elaborate rig controls would recover the quality of the finished illustrations. The user's visual rejection supersedes the v2 structural checks.

The visible problems are concentrated in the garment silhouette and folds, anatomical proportions, wrist and elbow construction, and the paths between postures. These are artwork and performance decisions. The existing Number input, image packaging, and runtime export are usable engineering work.

The selected production method is an illustrator-built hybrid 2D character in Rive. One coherent layered drawing supplies the base art. Replacement drawings handle foreshortening, folded clothing, head turns, and hand contacts. Authored transition clips control the order and timing of movement. The app can retain a single pose destination input, while the internal state machine becomes more expressive.

This pass produces one reversible production pilot specification for standing to bowing and back. It does not authorize commissioning, contacting an artist, paid model runs, or deployment.

## Quality gate

The final animation pilot passes only when its held standing and bowing drawings match the approved character, the movement reads naturally at normal speed, and close inspection shows no broken anatomy, exposed cutout ends, texture stretching, sliding feet, or cloth tears. A renderer or compiler pass cannot satisfy that gate.

The animatic in this folder is a timing reference made from existing still illustrations. It does not satisfy the final motion-quality gate. It establishes what the animator needs to deliver and makes the intended sequence reviewable.

## Rigor and scope

High rigor for the visual acceptance gate, light tooling for the brief. One character, one fixed camera, two approved endpoint poses, two authored directional transitions, and short held poses. No expansion to the complete ten-pose guide until the pilot passes visually.

The source silhouettes and textures remain the visual reference. The bowing artwork also needs the requested flat-back correction; a horizontal body axis in the rig is not enough to prove the drawn back is flat.

## Production dependency

A character illustrator/animator must redraw and author the pilot. The available image generator is useful for exploration but has not established frame-to-frame drawing consistency in this project. The current automation can prepare the brief, implement Rive logic, package exports, and run technical checks. It has not demonstrated the requested artistic finish.

The independent review confirmed that the timed stills cannot test motion, easing, cloth behaviour, or redraw consistency. Production-method selection and the artist handoff are complete; the animated pilot remains open. No artist, price, schedule, or commissioning agreement has been selected.
