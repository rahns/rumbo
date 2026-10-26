# 7. Roadmap

Each milestone ends with a downloadable IPA from CI.

| # | Milestone | Done when |
|---|---|---|
| **M0** | **Foundations and signing test** | XcodeGen project, CI producing an unsigned IPA, a placeholder app with the Diagnostics screen. The author installs it and reports which entitlements (iCloud/CloudKit, App Group), Live Activities and Apple models (on-device, cloud) work. |
| **M1** | **Core engine** | `RumboCore`: bands, placement, strand targets, planner, projection, FSRS, all with unit tests covering the rules in [02-learning-engine.md](02-learning-engine.md). |
| **M2** | **Onboarding and Today** | Full onboarding, Today screen with budget picker, task cards, timer, logging, SwiftData models. Usable daily from here. |
| **M3** | **Path, Pico and motion** | The scrolling path, gates, streaks/XP, Pico with all states, the motion and haptics catalog. |
| **M4** | **Writing and mistakes** | Writing editor, correction pipeline, rewrite flow, mistake deck. |
| **M5** | **Widgets and Live Activity** | Home and Lock Screen widgets, Dynamic Island timer with Pause/Done. |
| **M6** | **Progress, Library, Travel mode** | Charts, projection, content catalog with remote refresh, Travel mode and missions, notifications. |
| **M7** | **Polish and sharing** | Accessibility pass, empty states, a Releases page friends can download from. |

## M0 findings (iPhone 16 Pro, iOS 27.2, author's development certificate)

| Question | Answer |
|---|---|
| iCloud/CloudKit entitlement | ❌ Not in the profile |
| App Group entitlement | ❌ Not in the profile. An explicit shared Keychain group also fails (-34018, entitlement missing after signing). Testing the Keychain's *default* group in build 0.1.4+. |
| Push (`aps-environment`) | ✅ Granted |
| Live Activities, notifications | ✅ |
| Apple on-device model | ✅ Available, but weak on tense errors: in the sample it "corrected" *voy → voy* instead of *fui* |
| Apple cloud model (PCC) | ❌ Reports available, but a real request crashes the app (managed entitlement). Not used. |
| LanguageTool | ✅ Caught the agreement error the on-device model missed |
| URL schemes | ✅ `duolingo://`, `youtube://`, `dreaming://` (Dreaming Spanish), `languagetransfer://`, `tandem://`, `spotify://`. `dreamingspanish://` does not work. |
| iCloud Drive backup | ❌ Folder pickers return nothing; a saved file's bookmark doesn't survive a relaunch → **backup dropped**, data stays on device, and re-onboarding is the recovery path |
| App version | XcodeGen hardcoded 1.0 (1) in Info.plist; fixed in 0.1.4 so builds show `0.1.<run>` |

## Resolved in 0.1.4
- Keychain sharing works through the Keychain's default access group (`TEAMID.*` on the author's profile) → widgets use it.
- The on-device pipeline (LanguageTool hints + structured output + no-op filter) found all three errors in the sample and dropped one non-change.

M0 is complete. **M1 (core engine)** is implemented in `RumboCore` with 55 tests.

## M2 status
Written, not yet built: onboarding (7 steps), Today (budget chips, task cards, skip, extra-listening log, difficulty and speaking-stage banners), task session (timer, Live Activity, deep link, writing editor, logging with ratings), Progress tab (level, input hours, projection, streak, courses), Settings (sources, travel mode, progress fixes, speaking stage, habit, diagnostics, start over). Engine additions: course progression, can-do statements, prompts (65 tests).
