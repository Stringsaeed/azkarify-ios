# Azkarify verification map

This directory is the maintained source for verifying Azkarify's user-facing iOS behavior. Read this index, then use the matching feature file.

## Baseline preconditions

- Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify launch` from the repo root.
- Require `ready=yes` and a non-empty `artifacts/verify-azkarify/evidence/launch.png`.
- Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify doctor` and require `worth_driving=yes`.
- The dedicated simulator is named `azkarify-verify`. Never drive any other simulator.
- Launch starts from an uninstalled app container. Bundled azkar JSON is the content. There is no network seed.

## Driving conventions

- Start every recipe from the baseline unless its preconditions say otherwise.
- Prefer accessibility identifiers (`dailyJourneys`, `home.prayerLocation`, `journey-evening`) over visible labels when the file names an identifier. Visible labels follow the language.
- Run every drive through `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive`.
- Treat the only-testing identifier as literal.
- Do not remove files under `artifacts/verify-azkarify/evidence/` during cleanup.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- Proof is the xcresult for the named test, including its attached screenshot and the assertion that failed or passed.
- Record the feature file and the only-testing identifier with the artifact path.
- Report an unreachable path with the command you ran and the unmet precondition.
- Do not report a skipped entry point as verified through a different test.

## Feature entry contract

Each feature file starts with an H1 and one paragraph. It then uses these H2 sections in order.

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with azkarify-verify`
4. `Gotchas`

## Features

- [Favorites](./favorites.md) covers adding a favorite from home and the filled indicator.
- [Browse azkar](./browse-azkar.md) covers opening a category and returning to the list on a phone-width simulator.
- [Journeys](./journeys.md) covers opening a daily journey and completing the evening journey across relaunch.
- [Prayer location](./prayer-location.md) covers choosing Dubai after denying device location, and remembering it.
- [Settings accent](./settings-accent.md) covers opening Settings and selecting the blue accent in Arabic.
