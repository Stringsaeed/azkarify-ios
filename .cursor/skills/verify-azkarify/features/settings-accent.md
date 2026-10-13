# Settings accent

Settings accent lets a person open Settings in Arabic, open the accent list, and leave blue selected.

## Sub-features

- `settings-open-ar` opens Settings from the gear control. The screen shows `الإعدادات`.
- `settings-accent-blue` opens `لون التمييز`, chooses `أزرق`, and shows that choice selected when the list is opened again.

## How to get to it (user POV)

- Open the app in Arabic with the introduction and the location sheet already completed.
- Choose the Settings gear.
- Choose the accent row, then choose blue.
- Open the accent row again and see blue selected.

## Driving it with azkarify-verify

Preconditions:

- Doctor prints `worth_driving=yes` for `azkarify-verify`.
- The test launches in Arabic itself via `-AppleLanguages (ar)`. The English launch screenshot is not this screen.

- **Choose blue.** Open Settings, open the accent row, choose blue, then open the accent row again. Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive azkarifyUITests/azkarifyUITests/testAccentSelectionUpdatesSettings`. The `أزرق` button is selected.
- **Proof.** The xcresult at `artifacts/verify-azkarify/evidence/azkarifyUITests-azkarifyUITests-testAccentSelectionUpdatesSettings.xcresult` includes the screenshot `Settings after selecting blue`.

## Gotchas

- Accent options use Arabic labels in this test (`أزرق`, `فيروزي`). The English words are a different path.
- The accent value is `@AppStorage("accent")` on the simulator. Cleanup uninstalls the app, which drops it.
