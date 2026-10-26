# 7. Roadmap

Each milestone ends with a downloadable IPA from CI.

| # | Milestone | Done when |
|---|---|---|
| **M0** | **Foundations and signing test** | XcodeGen project, CI producing an unsigned IPA, a placeholder app with the Diagnostics screen. The author installs it and reports which entitlements (iCloud/CloudKit, App Group), Live Activities and Apple models (on-device, cloud) work. |
| **M1** | **Core engine** | `RumboCore`: bands, placement, strand targets, planner, projection, FSRS, all with unit tests covering the rules in [02-learning-engine.md](02-learning-engine.md). |
| **M2** | **Onboarding and Today** | Full onboarding, Today screen with budget picker, task cards, timer, logging, SwiftData models, sync/backup. Usable daily from here. |
| **M3** | **Path, Pico and motion** | The scrolling path, gates, streaks/XP, Pico with all states, the motion and haptics catalog. |
| **M4** | **Writing and mistakes** | Writing editor, correction pipeline, rewrite flow, mistake deck. |
| **M5** | **Widgets and Live Activity** | Home and Lock Screen widgets, Dynamic Island timer with Pause/Done. |
| **M6** | **Progress, Library, Travel mode** | Charts, projection, content catalog with remote refresh, Travel mode and missions, notifications. |
| **M7** | **Polish and sharing** | Accessibility pass, empty states, export/restore, a Releases page friends can download from. |

## Open questions to settle in M0
- Does the author's certificate/profile keep the iCloud and App Group entitlements after signing?
- Can a sideloaded build use Apple's Private Cloud Compute model?
- Which URL schemes do Dreaming Spanish, Language Transfer and Tandem respond to?
