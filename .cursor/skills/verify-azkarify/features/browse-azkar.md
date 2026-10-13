# Browse azkar

Browse azkar lets a person open a category from the home list, see that category's azkar, and return to the list.

## Sub-features

- `browse-open-morning` opens `Words of remembrance for morning and evening` and shows `Slideshow`.
- `browse-back` returns to the home list on a phone-width simulator.
- `browse-open-sleep` opens `What to say before sleeping` and shows that title.

## How to get to it (user POV)

- Open the app in English with the introduction and the location sheet already completed.
- On the home list, choose a category title.
- Choose the back control to return to the list, then choose another category.

## Driving it with azkarify-verify

Preconditions:

- Doctor prints `worth_driving=yes` for `azkarify-verify`.
- The simulator is iPhone 17 Pro, so the window is narrower than 700 points and the sidebar does not stay beside the detail.

- **Open morning.** Choose `Words of remembrance for morning and evening`. Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive azkarifyUITests/azkarifyUITests/testAdaptiveCategoryNavigation`. `Slideshow` is visible.
- **Return and open sleep.** The same test goes back, then chooses `What to say before sleeping`. The sleeping title is visible and `Slideshow` is visible again.
- **Proof.** The xcresult at `artifacts/verify-azkarify/evidence/azkarifyUITests-azkarifyUITests-testAdaptiveCategoryNavigation.xcresult` includes the attached screenshot `Adaptive category navigation`.

## Gotchas

- At a window width of 700 points or more the sidebar stays on screen and the back control is not the path. This recipe is the phone-width path. Do not count an iPad run as this proof.
- Category buttons use the category title as their label. Search text that filters the list can hide `What to say before sleeping`.
