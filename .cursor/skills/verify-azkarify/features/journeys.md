# Journeys

Journeys lets a person open the daily journey list from home and complete the evening journey so the completion remains after the app relaunches.

## Sub-features

- `journeys-open` opens the daily list from `dailyJourneys` and shows `journey-evening`.
- `journeys-complete-evening` marks `journey-step-evening-azkar` complete and shows `Journey complete`.
- `journeys-restore` shows that same step selected and `Journey complete` after relaunch.

## How to get to it (user POV)

- Open the app in English with the introduction and the location sheet already completed.
- Choose `Your daily journeys`.
- Choose the evening journey, mark its azkar step complete, leave the app, and open the evening journey again.

## Driving it with azkarify-verify

Preconditions:

- Doctor prints `worth_driving=yes` for `azkarify-verify`.
- Launch left the container empty, so today's evening step is not already complete. If it is, the test clears it before completing it again.

- **Open and complete.** Choose `Your daily journeys`, then the evening journey, then the evening azkar step. Run `.cursor/skills/verify-azkarify/scripts/azkarify-verify drive azkarifyUITests/JourneyUITests/testEnglishEveningJourneyCompletionSurvivesRelaunch`. The completion label reads `Journey complete`.
- **Relaunch.** The same test terminates the app, launches it, and opens the evening journey again. `journey-step-evening-azkar` is selected, its value is `Complete`, and the label is still `Journey complete`.
- **Proof.** The xcresult at `artifacts/verify-azkarify/evidence/azkarifyUITests-JourneyUITests-testEnglishEveningJourneyCompletionSurvivesRelaunch.xcresult` includes the screenshots `en evening journey completed` and `en evening journey restored`.

## Gotchas

- Completion is stored on the simulator for the current day. Cleanup uninstalls the app. A second drive without cleanup can still pass, because the test clears a selected step before completing it, but it is then proving a dirty container.
- Arabic copy uses `اكتملت الرحلة` and `مكتملة`. This file is the English test only. `testArabicJourneyAndPrayerConfigurationSurviveRelaunch` is a different journey.
- The home card's accessibility identifier is `dailyJourneys`. The visible label is `Your daily journeys`.
