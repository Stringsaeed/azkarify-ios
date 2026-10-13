# Favorites

Favorites lets a person mark an azkar from the home list and see that it is saved.

## Sub-features

- `favorites-add` marks the first home favorite control as saved.
- `favorites-indicator` replaces `Add to favorites` with `Remove from favorites` on that control.

## How to get to it (user POV)

- Open the app in English with the introduction and the location sheet already completed.
- On the home list, choose `Add to favorites` on an azkar row.

## Driving it with azkarify-verify

Preconditions:

- Doctor prints `worth_driving=yes` for `azkarify-verify`.
- The app container was empty at launch, so the row is not already a favorite.

- **Add a favorite.** On the English home list, choose `Add to favorites`. Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive azkarifyUITests/azkarifyUITests/testAddingFavoriteShowsIndicator`. The same row shows `Remove from favorites`.
- **Proof.** The xcresult at `artifacts/verify-azkarify/evidence/azkarifyUITests-azkarifyUITests-testAddingFavoriteShowsIndicator.xcresult` records the tap and the `Remove from favorites` assertion, plus the attached screenshot named `Favorite added indicator`.

## Gotchas

- The test taps `Add to favorites` and fails if that button is already gone. A container left over from an earlier drive is the usual cause. Clean up and launch again.
- The control uses the English label. An Arabic launch looks for different text. This file is the English home path only.
- Favorites are stored in UserDefaults on the simulator. Uninstall during cleanup is what clears them. Quitting the app does not.
