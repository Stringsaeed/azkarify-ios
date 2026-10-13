---
name: verify-azkarify
description: >-
  Drives the Azkarify iOS app on a dedicated Simulator and proves user-facing
  behavior with the repo XCUITest harness. Use when changing Azkarify screens,
  navigation, journeys, prayer location, favorites, settings, or when asked to
  verify the iOS app.
---

# Verify Azkarify

Primary surface is the Azkarify iOS app (`com.stringsaeed.azkarify`). Read `features/README.md`, then the feature file for the behavior you are proving.

The content editor at `python3 content-editor/server.py` (http://127.0.0.1:8765) is a separate local tool for JSON text. This skill does not drive it.

Simulator runs cannot prove Apple App Attest. Debug and Release both call the staging catalog, and the simulator uses bundled or cached location data. A passing simulator run does not certify enrollment, assertion counters, or a physical device.

## Launch

From the repo root:

```sh
.cursor/skills/verify-azkarify/scripts/azkarify-verify launch
```

Launch creates or reuses a simulator named `azkarify-verify` (iPhone 17 Pro, iOS 27.0), boots only that simulator, builds the `azkarify` scheme Debug, uninstalls any previous copy of the app on that simulator, installs the new build, and launches it. Uninstall is the empty data dir. Azkar JSON is bundled in the app, so a fresh container can show categories with no migration and no seed command.

The process is usable when the command prints `ready=yes` and `artifacts/verify-azkarify/evidence/launch.png` shows the English home screen (`Your daily journeys` and the azkar list). A blank white frame is not ready. Launch waits up to 15 seconds for that screen. Those are the `@AppStorage` keys in `azkarify/azkarifyApp.swift` and `ContentView`. With them set, home is the first screen. Without them, a fresh install shows `IntroView` and then the location sheet.

Refuse to launch when `artifacts/verify-azkarify/instance.env` already exists.

## Doctor

```sh
.cursor/skills/verify-azkarify/scripts/azkarify-verify doctor
```

Run this before every drive. It is worth driving only when the command prints `worth_driving=yes`. That requires one `azkarify-verify` simulator, the UDID in `instance.env`, state `Booted`, and `com.stringsaeed.azkarify` installed on that UDID. Any other result means stop. Do not drive a different booted simulator.

## Drive

```sh
.cursor/skills/verify-azkarify/scripts/azkarify-verify drive <only-testing identifier>
```

The identifier is the XCUITest the feature file names. The helper runs `xcodebuild test` on the recorded UDID only. The test relaunches the app and performs the user path. Pass when the command exits 0 and prints `proved=` plus `xcresult=`.

Drive one feature file end to end. A proof that uses a different test than the file names is a different path. Report it as a skip with the unmet precondition.

## Evidence

Keep proof in `artifacts/verify-azkarify/evidence/`. Launch writes `launch.png`. Drive writes `<test-identifier>.xcresult`. The bundle contains the test log and the screenshots the test attaches.

A proof includes the action and the resulting state. The xcresult must contain the passing test that taps the control and the assertion on the next screen, selection, or saved value. A screenshot with no matching assertion is not proof. Check side effects the feature file names (UserDefaults-backed favorites, journey completion after relaunch, location label after relaunch). Do not call stores or test hooks to set that state.

## Cleanup

```sh
.cursor/skills/verify-azkarify/scripts/azkarify-verify cleanup
```

Cleanup terminates and uninstalls `com.stringsaeed.azkarify` on the UDID in `instance.env`, shuts down that simulator only, deletes `/tmp/azkarify-verify-derived`, and removes `instance.env` and the lock. It does not delete `artifacts/verify-azkarify/evidence/`. It does not shut down simulators whose name is not `azkarify-verify`.

Run cleanup after a failed launch or drive too, so the dedicated simulator is not left booted.

## Helpers

`.cursor/skills/verify-azkarify/scripts/azkarify-verify` is the only helper. Invoke it from the repo root with `doctor`, `launch`, `drive <id>`, or `cleanup`.
