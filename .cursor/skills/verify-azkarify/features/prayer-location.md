# Prayer location

Prayer location lets a person deny device location, pick Dubai, and see Dubai on the home control after a relaunch.

## Sub-features

- `location-deny` denies the system location prompt and shows `location.city.Dubai`.
- `location-choose-dubai` saves Dubai and shows it on `home.prayerLocation`.
- `location-remember` shows Dubai on `home.prayerLocation` after relaunch and does not show `location.useDevice`.

## How to get to it (user POV)

- Open the app in English before a prayer location has been saved.
- Choose to use device location, then deny the system prompt.
- Choose Dubai.
- Leave the app and open it again. The home location control still names Dubai.

## Driving it with azkarify-verify

Preconditions:

- Doctor prints `worth_driving=yes` for `azkarify-verify`.
- This journey needs the location sheet. The default launch sets `-hasPresentedPrayerLocationSetup YES`, which skips the sheet. The UI test replaces launch arguments with `-hasPresentedPrayerLocationSetup NO` and clears the saved prayer configuration. Run the test itself. Do not expect the launch screenshot to show the sheet.

- **Deny and choose Dubai.** Choose device location, deny the system alert, then choose Dubai. Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive azkarifyUITests/LocationSetupUITests/testDeniedLocationOffersCityAndRemembersSelection`. `home.prayerLocation` contains `Dubai`.
- **Remember.** The same test relaunches. `home.prayerLocation` still contains `Dubai`, and `location.useDevice` is gone.
- **Proof.** The xcresult at `artifacts/verify-azkarify/evidence/azkarifyUITests-LocationSetupUITests-testDeniedLocationOffersCityAndRemembersSelection.xcresult` includes the screenshot `City fallback after denying location`.

## Gotchas

- The deny button is a SpringBoard alert, not an Azkarify control. The test matches a button whose label begins with `Don`.
- Simulator location data is bundled or cached. This journey does not prove App Attest or the staging catalog.
- `testAllowedLocationSavesCoordinatesOnDevice` taps `Allow Once` and expects coordinates `25.2048` and `55.2708`. That is a different entry point. Do not treat this Dubai denial as that proof.
