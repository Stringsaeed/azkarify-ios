# Azkarify progression and collectibles

Design proposal · 29 September 2026 · Planning only

See the [visual and sound direction](design/visual-and-sound-direction.md) for the illustrated journey, animation timings, original sound previews, and playback rules.

The requested direction is playful, with visible points, levels, and collectibles. The numerical rules below are starting values for a pilot, not proven retention targets. This plan refers to the current native iOS app in this checkout.

## Product decision

Build **My Journey**, a personal progression feature where completing an azkar routine earns XP, advances a numbered level, and unlocks decorative collectibles. A five-day weekly goal gives the user a manageable reason to return. Earned XP and collectibles remain after missed days.

Use one point total. XP is cumulative and cannot be spent. Levels communicate progress; collectibles give people something visible to earn and choose. A second currency, shop, and economy are unnecessary for the first release.

The collection starts with illustrated objects such as a crescent, lantern, geometric tile, and palm. Users can feature an unlocked object on their Journey card. Preserve the app's warm cream background, brown accent, Arabic typography, and existing color choices. Commission original artwork for the shipped collection. Icons in the concept preview are placeholders.

Two designs were compared: an XP collection album and a customizable miniature courtyard. Use the album as the base. Bring over the courtyard design's useful idea of displaying earned objects on Home, with one featured object rather than a placement editor. This gives the rewards a visible use while keeping the first release small. A courtyard can become a later use for the same inventory if users value collecting.

Reject scroll-duration tracking and partial-category thresholds as proof of completion. They reward screen exposure and can label an unfinished routine complete. Also reject requiring a countdown for every entry, which excludes people who read and count independently. Explicit entry confirmation plus a final Finish action is the shared rule.

The product promise is: “Build your routine. Grow your collection.” Explain once that XP records activity in Azkarify and does not measure faith or spiritual reward. Use “Level 4,” never spiritual ranks. All azkar, translations, existing appearance settings, and accessibility options remain available from the start.

## What exists today

| Area | Observed behavior | Consequence for this design |
| --- | --- | --- |
| Home | Searchable category list, favorites, menu shortcuts | Add one compact Journey card above the list; keep search prominent |
| Quick Mode | Category 27 for Morning & Evening, 28 for Before Sleep, 1 for Upon Waking | Add explicit routine identities; category 27 alone cannot distinguish morning and evening |
| Reader | Cards and a separate slideshow | Both presentation modes must share one session |
| Counter | Transient state; countdown for entries with repeat count greater than one | A countdown reaching zero can mark an entry ready, but does not prove the whole routine is complete |
| Persistence | SwiftData JSON cache; preferences and favorites in UserDefaults | Add structured session and reward records |
| Offline | Previously fetched content can load from cache | Progress can work offline, but a new uncached routine still needs a download |
| Reminders | Local morning and evening notifications | Reuse the existing opt-in reminders; completion happens in the app |
| Accounts | No account or progress sync in the inspected app | Start with progress on this installation; do not promise cross-device recovery |

Source files include `Features/Home/ContentView.swift`, `Features/QuickMode/QuickModeView.swift`, `Features/Zikr/ZikrViews.swift`, `Features/Counter/CounterView.swift`, `State/AzkarStore.swift`, `Data/AzkarRepository.swift`, and `azkarifyApp.swift`, all under `azkarify/`.

## The first-use and daily experience

1. Home offers “Start your journey.” The user can also keep using the existing library.
2. The user chooses a preferred routine: Morning, Evening, Before Sleep, Upon Waking, or a category from favorites. This changes the Home shortcut, not the value of XP.
3. Offer a reminder using the existing settings. Permission and XP are unrelated. Bedtime and waking reminder scheduling are later additions; do not silently substitute morning or evening notifications.
4. Start the chosen routine. Show the current entry, its prescribed repetitions, and session progress such as “3 of 8 completed.” The number of entries comes from the loaded content.
5. The user confirms the entries and taps “Finish routine.” The first completion earns 30 XP and unlocks Level 2 plus a crescent collectible.
6. A small completion sheet shows the earned XP, new level if applicable, and “Use on my Journey.” A secondary “Done” action returns to the reader or Home.
7. On later visits, Home shows the preferred routine or “Resume,” XP to the next level, the featured collectible, and “3 of 5 days this week.”

A sample fifth active day starts at 120 XP. Completing the first routine adds 30 XP plus the 50 XP weekly bonus. The new total is 200 XP. Finishing a second distinct routine adds 10 XP, reaching 210 XP. The next level is at 250 XP.

## Exact XP rules

| Event | Award | Limit |
| --- | ---: | --- |
| First qualifying routine completed on a progress day | 30 XP | Once per date |
| Second distinct qualifying routine completed on that date | 10 XP | Once per date |
| Fifth distinct active date in a progress week | 50 XP | Once per week |
| Third routine, replay of the same routine, or extra repetitions | 0 XP | History still records completed sessions |
| Opening the app, scrolling, changing favorites, enabling reminders, purchasing support | 0 XP | None of these proves routine completion |

The ordinary daily maximum is 40 XP. The weekly bonus can make the fifth active day's total 90 XP. The maximum for a seven-day week is 330 XP. A single routine on five days earns 200 XP.

An active date requires at least one completed qualifying routine. A partial session does not make a date active. A completed routine qualifies regardless of whether it is the preferred Home routine.

Weekly progress runs Monday through Sunday in the saved progress timezone. Show the week dates in Journey. If someone joins on Saturday, their existing XP carries forward even if the first short week cannot reach five days. No prorated bonus in version 1.

The five-day goal is fixed for the pilot. Do not add daily goals, weekly quests, streak multipliers, and separate challenges simultaneously. Users can choose when and what to practise without managing several reward systems.

## Levels and collectible catalog

Thresholds refer to lifetime XP. Every unlock is automatic, permanent, and granted once. Users never need to tap “Claim” to keep an earned item.

| Level | Total XP | Reward |
| --- | ---: | --- |
| 1 | 0 | Starter Journey card and collection album |
| 2 | 30 | Crescent collectible |
| 3 | 120 | Lantern collectible |
| 4 | 250 | Geometric tile collectible |
| 5 | 450 | Palm collectible |
| 6 | 700 | Woven bookmark collectible |
| 7 | 1,000 | Courtyard arch collectible |
| 8 | 1,400 | Mosaic collectible |
| 9 | 1,900 | Night-sky collectible |
| 10 | 2,500 | Collection-complete frame |

Locked items show their name, silhouette, and exact XP threshold. There are no random drops, duplicates, expiring items, or purchase requirements. Feature one collectible at a time on the Journey card. The frame is a separate cosmetic slot.

The pilot has ten levels. At Level 10, show “Collection complete” with lifetime XP and weekly progress. XP continues accumulating; no nonexistent next reward is advertised. Before adding another collection, assess whether users still value the routine without frequent unlocks.

The following pacing is calculated, not observed user behavior. It assumes a Monday start and that three-day or five-day users practise on the first three or five days each week.

| Pattern | XP per full week | Reaches Level 5 | Reaches Level 10 |
| --- | ---: | ---: | ---: |
| One routine on 3 days each week | 90 | Day 31 | Day 192 |
| One routine on 5 days each week | 200 | Day 16 | Day 88 |
| One routine every day | 260 | Day 12 | Day 68 |
| Two distinct routines every day | 330 | Day 10 | Day 54 |

This curve gives an immediate first reward and a longer collection goal. The late levels may feel slow for occasional users. Test that explicitly before producing more art or increasing requirements.

## Completion rules

Progress records what the user confirms in the app. It cannot verify recitation or religious practice. Avoid timers, microphone checks, and speed requirements.

| Situation | Required behavior |
| --- | --- |
| Entry with one repetition | Show “Mark completed”; no counter is necessary |
| Entry with multiple repetitions | Countdown can complete the entry, or the user chooses “I completed this zikr” after reading independently |
| Countdown reaches zero | Mark that entry completed once; do not award XP yet |
| All entries completed | Enable “Finish routine”; award only after the user confirms |
| Slideshow swipe | Changes the visible entry only; does not mark it completed |
| Switch list and slideshow | Preserve the same session and completed entry IDs |
| Leave halfway | Save counts and completed entries; show “Resume” later |
| Skip an entry | It remains incomplete; the full routine cannot finish |
| Reset counter | While the session is unfinished, remove that entry's completion and reset its count |
| Start again after finishing | Create a new session; daily reward limits still apply |
| Standalone count-up counter | Remains available; no XP in version 1 because it has no defined routine boundary |

Browsing never requires participation in Journey. Add an explicit “Start routine” action to category readers. Read-only browsing, including the existing slideshow, continues to work without a session.

Keep at most one unfinished session per routine identity. Starting that routine offers Resume or Start over. Multiple different routines may have drafts. Starting over discards only that routine's unfinished draft after confirmation.

Snapshot the routine's entry IDs, repeat targets, and displayed content when the session begins. A content refresh must not alter a session halfway through. If another language cannot be mapped to the same canonical entries, keep the draft in its original language and offer to finish it or restart. Never silently create new completion credit on a language switch.

## Routine identity and time rules

Use canonical, versioned IDs, never localized titles. Define a small routine catalog owned by the app:

- `morning` and `evening` may reference category 27 but are distinct user-selected routines.
- `beforeSleep` references category 28; `uponWaking` references category 1.
- Other categories use a canonical category identity verified against both supported language datasets.
- Opening category 27 from the library asks which routine is being started. It must not also create a third generic category-27 identity. The same alias rule applies to the other named presets.

The current combined category is not evidence that each entry applies equally to morning and evening. Before shipping separate labels, review the source content and map any time-specific entries correctly. Do not invent or silently shorten religious text to make the game easier.

Morning and evening are user-selected labels in the pilot, not a claim that the app validates religious time windows. Reminder time does not determine reward eligibility. No location permission is needed.

Set a progress timezone from the device when Journey is enabled and keep it fixed in version 1. Show it in Journey settings so travel behavior is understandable. This is an app accounting convention. Completing a session across midnight credits the completion date, once. Persist the date and week key on the award. Do not recalculate old awards when the device timezone changes.

Use local Gregorian dates and Monday week boundaries for accounting independently of the language used to display them. Inject a clock into reward logic for tests. Offline clock manipulation is an accepted limitation of local, noncompetitive cosmetic rewards; no fraud service is needed.

## Missed days, privacy, and monetization

There is no daily streak that can erase progress. On a missed day, nothing is deducted. At the next week, the five-day display resets and previous weekly results remain in history. The return message is “Welcome back. Continue your journey.”

Avoid loss warnings, scarce reward countdowns, red missed-day indicators, and notifications about falling behind. No leaderboard in the first release. The app records very personal habits; do not make them public by default.

Offer “Show Journey” in settings. Turning it off hides progression and stops new XP tracking. Existing records remain until the user explicitly resets Journey. Turning it back on resumes with the saved total; no backfill for untracked activity. Reset requires confirmation and deletes progress, inventory, and drafts without deleting favorites, downloaded content, or appearance preferences.

Progress is stored on this installation. Do not advertise account recovery or iCloud sync. Standard device backups may include app data, but a fresh reinstall is not a promised restore flow.

Keep RevenueCat support separate. Payments must not buy XP, weekly credit, levels, or repairs for missed days. Cosmetic supporter packs could be a later business decision, but the first collectible album is earnable without payment. Do not lock any currently free theme, accent, or font behind the new system.

## Screens and copy

| Screen | Design and actions |
| --- | --- |
| Home | Compact card above the category list: featured collectible, level, XP progress, weekly days, Start or Resume; card opens Journey |
| Reader | Session progress and entry completion controls; keep XP out of the reading text area |
| Completion sheet | One combined result for session XP, weekly bonus, level changes, and unlocked items; Use on my Journey or Done |
| Journey | Lifetime XP, current level, next unlock, week dates, active days, and album |
| Collectible detail | Artwork, name, unlock requirement, earned date if unlocked, feature action |
| Settings | Show Journey, progress timezone, optional celebration haptics, reset progress |

Suggested English copy: “Routine complete,” “+30 XP,” “Lantern unlocked,” “Use on my Journey,” and “Your practice is saved.” For a replay, say “Routine complete. Today's XP for this routine is already recorded.”

Draft Arabic labels: “رحلتي”, “اكتمل الورد”, “نقاط التقدم”, and “مجموعتك”. Review their tone with Arabic-speaking users before release. Localize full sentences and plural forms, format numerals for the locale, and mirror directional navigation.

Completion celebrations last about one second and never block dismissal. Respect Reduce Motion. Keep haptics optional, use text alongside illustrations, support Dynamic Type, and announce one completion summary to VoiceOver. All controls remain accessible without precision tapping or motion.

## Implementation shape

Keep religious content loading in `AzkarRepository`. Add one `JourneyStore` beside `AzkarStore` that owns session persistence, XP policy, award deduplication, and collectible eligibility. Views send user actions and render results. They never add XP directly.

The caller needs four operations, sketched here as pseudocode rather than compiled Swift:

```text
session = journey.startOrResume(routineID)
session = journey.updateEntry(sessionID, entryID, action)
receipt = journey.finish(sessionID)
journey.feature(collectibleID)
```

`finish` validates that every snapshotted entry is complete, identifies the credit date, determines eligible awards, persists completion and awards together, and returns a display receipt. Calling it twice returns the recorded receipt. A storage failure returns a retryable error and no success celebration.

| Proposed model | Essential fields and ownership |
| --- | --- |
| `JourneyProfile` | Enabled state, preferred routine, saved timezone, featured item and frame, policy version |
| `RoutineSession` | UUID, canonical routine ID, content version and entry snapshot, counts, completed entries, start time, optional finish time, saved receipt |
| `XPAward` | Unique award key, amount, policy version, source session ID, completion time, progress date and week |
| `CollectibleUnlock` | Unique collectible ID, unlock time, triggering award |
| `JourneySnapshot` | Derived lifetime XP, level, this week's dates, next unlock, inventory; a view result rather than another mutable total |

Store the new persistent models in SwiftData, separate from the raw content cache. Include them in the app's model container and define schema migration before shipping. A cache refresh must never clear Journey history.

Award keys include `day:<date>:first`, `day:<date>:second`, and `week:<week-start>:five-days`. Record the qualifying routine for each daily award. A session UUID deduplicates retries; the day key limits a newly created replay. Both are needed.

Serialize mutations through the store and save session completion, XP awards, and unlocks as one transaction, rolling back on failure. Derive total XP from stored awards. Persist historical award amounts and policy versions so a later economy adjustment does not rewrite earned progress. Deduplication must also cover completion sheets appearing twice after navigation or relaunch.

Proposed files:

```text
azkarify/Data/JourneyModels.swift
azkarify/State/JourneyStore.swift
azkarify/Features/Journey/JourneyView.swift
azkarify/Features/Journey/JourneyCard.swift
azkarify/Features/Journey/CompletionView.swift
azkarifyTests/JourneyTests.swift
```

Integrate reader and slideshow session state through `ZikrViews.swift`. Pass entry identity into `CounterView`; return progress rather than awarding there. Extend `ContentView`, `SettingsView`, `azkarifyApp`, and localization resources. The exact file split can stay small until implementation needs more.

## Delivery plan

Estimates assume one developer familiar with this app, part-time design review, and available collectible artwork. They are planning estimates, not delivery promises. Production code remains outside this design task.

| Order | Work item | Acceptance condition | Estimate |
| --- | --- | --- | --- |
| 1 | Validate the concept with 5–8 target users, including Arabic readers and occasional users | Users understand XP, the first unlock, and missed-day behavior; no participant interprets level as religious merit without correction | 1–2 days |
| 2 | Finalize routine mapping, content review, completion interaction, and nine reward assets | Both language catalogs map to canonical IDs; combined morning/evening content reviewed; every locked item has a defined asset and threshold | 2–4 days, content review may take longer |
| 3 | Build persistent sessions and entry completion | List, slideshow, countdown, manual confirmation, restart, and relaunch share correct progress; cached routines work offline | 3–4 days |
| 4 | Build XP, weekly goal, levels, and inventory | Exact rules pass behavioral tests; duplicate completion never adds XP; failed saves never show success | 2–3 days |
| 5 | Add Home, completion sheet, Journey, and settings | First-session unlock and collectible selection work end to end in Arabic and English | 2–3 days |
| 6 | Run accessibility, migration, offline, and time-boundary QA | Required cases below pass on an iOS simulator and at least one physical iPhone | 2–3 days |
| 7 | Pilot through TestFlight and review | Two weeks of observed use plus interviews inform whether to ship, change pacing, or simplify | 2 calendar weeks |

Expect roughly 12–19 working days before the pilot, with some artwork and review work overlapping. Do not add social features, another currency, a scene editor, or seasonal quests to this first release.

The first engineering milestone is one complete routine that survives relaunch and finishes exactly once. Add the first 30-XP award only after that behavior is reliable.

## Verification cases

- A new user completes one routine and receives exactly 30 XP, Level 2, and one crescent.
- Completing another distinct routine that date adds 10 XP. A third routine and replay add zero.
- The fifth active date adds 50 XP once. Reopening the app and finishing another session cannot award it again.
- Four completed entries out of five earn no XP. The user can resume the fifth entry after relaunch.
- An entry with one repetition is finishable without a counter. Manual confirmation and countdown produce the same completed-entry state.
- Opening a screen, swiping every slide, toggling favorites, and allowing notifications add no XP.
- Counter reset before session completion removes that entry's completion. Reset after an already finalized session does not retract or duplicate its award.
- Morning and evening can earn the two daily awards; opening their underlying category does not create a third identity.
- Switching language, switching presentation mode, changing theme, or refreshing content does not duplicate awards or drop the active draft.
- A session ending after midnight credits one completion date. Monday week rollover, a daylight-saving transition, and a device timezone change follow the saved timezone policy.
- Relaunch after a successful save but before the sheet appears preserves the award. A simulated save failure shows Retry and awards nothing until a successful atomic save.
- Existing installations migrate without losing cache, favorites, preferences, or purchases. Existing counter usage does not fabricate historical XP.
- A downloaded routine finishes in airplane mode. An uncached routine presents a download error with no XP.
- Turning Journey off stops tracking; turning it on preserves earlier rewards. Reset removes only Journey data.
- VoiceOver, large text, Arabic right-to-left layout, light and dark appearance, and Reduce Motion keep the experience usable.

## Pilot measurements and release decision

The objective is repeated completion of chosen routines. Time in the app and tap count are not success measures.

The current app has no analytics pipeline. Do not quietly add one as part of the reward engine. For the pilot, collect voluntary feedback and consented exports of coarse activity summaries, or separately scope anonymous analytics. Avoid exporting routine names, religious text, or exact practice timestamps when aggregate counts suffice.

Measure activation as users completing their first routine divided by users enabling Journey. Measure weekly consistency as users active on at least five dates divided by enabled users observed for a full week. Measure days 7–13 return as users with a qualifying completion in that window divided by activated users with a full 14-day observation window. Report numerator and denominator, especially for a small pilot.

If testing with sufficient users, compare random assignment to the same session-tracking reader with and without visible rewards. Comparing to the current app alone confounds new completion controls with gamification. If numbers are too small, use the pilot to find usability problems and do not claim causal retention improvement.

Check whether users rush entries to get XP, misunderstand manual confirmation, feel pressured by the weekly goal, hide Journey, or find late rewards too distant. Review crash reports and loss of saved progress as release blockers. Ship more broadly only after those problems are resolved and users can explain the reward rules without coaching.

## Evidence and limits

Research supports treating game elements as distinct design choices rather than assuming that points alone produce motivation. Sailer and colleagues found different motivational effects for different bundles of game elements in an experimental task. That is useful background, but it does not establish that this design improves azkar practice or that these XP values are optimal. [Original study](https://www.sciencedirect.com/science/article/pii/S074756321630855X).

Optional haptics follow Apple's platform guidance. [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).

All economy values, collectible themes, and scope decisions in this proposal are product recommendations for Azkarify. Validate them through the pilot rather than presenting them as scientific or religious conclusions.

## Design verification

Independent comparison of the two candidates supported the album as the first-release base and the synthesized persistence and identity rules as the implementation contract. The final design intentionally supports two ways to complete an entry: countdown reaching zero or explicit manual confirmation. Both still require the same final Finish routine confirmation. Counting is never mandatory.

The progression table was checked with a day-by-day simulation of each stated attendance pattern. The interactive concept was exercised through continuing a routine, finishing it, receiving 30 XP and Level 2, featuring the crescent, and inspecting the locked and unlocked collection items. JavaScript syntax and fragment structure were checked. This verifies the concept preview, not native app implementation. Native tests in the backlog remain future work.
