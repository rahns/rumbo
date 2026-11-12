# 9. Supporting languages other than Spanish

**Status: draft plan. Nothing here is built yet.** The other docs describe the app as it is (Spanish only); this one describes how to get from there to an app that can teach several languages. French is the second language. The app's own text stays in English.

## 9.1 Summary

Rumbo's engine is mostly language-neutral already: the four strands, the planner's balancing, streaks, freezes, goals, FSRS, classes/tutoring, the path, and the plan balance don't care what is being learned. Spanish lives in five places:

1. **The sources.** Dreaming Spanish, Language Transfer, Extra en Español, Duolingo and Tandem/HelloTalk are named in enums (`SourceKind`, `TaskKind`), and their facts are constants: 90 tracks and their lengths, 13 episodes, a 0–100 difficulty scale, which levels each one is used at.
2. **The level model.** The training hours each level starts at come from Dreaming Spanish's roadmap for English speakers.
3. **Words.** About 40 English sentences in the app say "Spanish"; 22 prompts and 3 can-do statements do too; the suggested content list is Spanish shows.
4. **The writing check.** The tutor instructions name Spanish grammar points (ser/estar, por/para), and the basic checker asks LanguageTool for `es`.
5. **Flavour.** Spanish words used as decoration: "Semana 3", "Hoy", "¡Hecho!", "¡Buenos días!", level names ("Explorador"), Pico's squawks, Spanish day names on the path.

The plan is to gather all five into one value per language, a **language pack**, and have the engine and the app read from the active pack instead of from constants. Spanish becomes the first pack, with identical behaviour; French is then mostly content work, not code.

Two things should land **before the first public release**, because they are cheap now and costly once people have data on their phones: tagging stored data with its language (§9.4), and a backup format that carries the tag (§9.4). Everything else can follow in any order.

## 9.2 Decisions needed

These change the design, so they should be settled before Phase 3. Each has a recommendation.

| # | Decision | Recommendation |
| --- | --- | --- |
| 1 | Can someone learn two languages at once in the app? | Store data so they can (every record tagged), but ship with **one active language**, switchable in Settings. Each language has its own level, plan, weekly goal, streak and history. Side-by-side daily plans can come later without another data change. |
| 2 | The Spanish decoration ("Semana", "¡Hecho!") for other languages | Translate it per language through the pack (French: "Semaine 3", "Aujourd'hui", "C'est fait !"). It is a small fixed list (§9.3 "Phrasebook") and it is part of the app's charm. The alternative is plain English everywhere. |
| 3 | Name and mascot | Keep **Rumbo** and **Pico**. Both are Spanish words, and the reminder title "¿Rumbo a dónde?" is Spanish too; the brand line stays, the reminder title moves to the phrasebook. A per-language accessory for Pico (a beret) is optional polish. |
| 4 | Level range | Stay A2–B2 for every language. Beginners from zero are out of scope, as now. |
| 5 | A language with no good source for a role (say, no graded video site) | Ship it anyway. The planner already passes on the share of a strand that has nothing to plan (`LearnerSnapshot.canPlan`), and suggested content covers listening. |
| 6 | Which languages after French | Affects how much of §9.3 "Levels" is needed. French, Italian and Portuguese take about the same hours as Spanish for an English speaker. German takes more; Japanese, Korean, Mandarin and Arabic take several times more, have no LanguageTool support worth using, and need script-aware text handling in the mistake deck. Recommend the first group, then German. |

## 9.3 Target design

### Language pack

A new type in RumboCore, `LanguagePack`, one static value per language (`LanguagePack.spanish`, `.french`), looked up by code (`"es"`, `"fr"`). Packs are Swift values, not downloaded files, so they are type-checked and unit-tested like the rest of the engine. The one bulky list that already updates over the air (suggested content) stays a JSON file, one per language.

A pack holds:

| Part | Contents | Replaces |
| --- | --- | --- |
| Identity | Code, English name ("Spanish"), own name ("Español"), locale for dates | The literal "Spanish" everywhere; `SpanishDate` |
| Levels | Training hours at which each of the six levels starts | `Band.hoursThreshold` |
| Sources | For each role (below) the pack has zero or one source: name, icon, what it is, where to find it, links, app URL scheme, and its numbers | `SourceCopy`, `SourceInfoSheet`, `DeepLinks`, `Course`, band checks in `LearnerSnapshot.isEligible` |
| Anchors | How often each weekly anchor is due, per level | `AnchorTargets` |
| Tutor | The grammar points the AI checker should watch for, the LanguageTool code (or none), and from which level explanations switch to the target language | `CorrectionService.instructions`, `LanguageTool.check` |
| Phrasebook | The decoration strings | Scattered literals in 10 files |
| Can-do | The self-assessment statements | `CanDo` |
| Prompts | Writing, exchange, quick-write, story and travel-mission lists | `Prompts` |
| Catalog | Bundled file name and remote URL | `ContentLibrary` |

Can-do statements and prompts are English text about everyday life and are nearly the same for every language. They move to a shared list with a `{language}` placeholder ("Order food or a drink entirely in {language}"), and a pack can add or remove items where culture matters.

### Roles instead of brands

`SourceKind` has seven cases, each a brand. They become seven **roles**, and each pack says which product fills each role:

| Role | Spanish | What the engine needs to know |
| --- | --- | --- |
| Graded video | Dreaming Spanish | Whether it has a difficulty scale, its range and window width; whether it counts hours the learner can import at onboarding |
| Audio course | Language Transfer | Number of tracks, each track's length, levels it is used at |
| Learner series | Extra en Español | Episodes, parts per episode, levels for intensive and extensive viewing, search text for opening an episode |
| Drill app | Duolingo | Levels it is used at, how progress is counted (section and unit) |
| Writing | Built in | Word targets per level |
| Exchange partner | Tandem/HelloTalk | Nothing language-specific |
| Suggested content | Library | The catalog |

`TaskKind` follows: `.dsWatch` becomes the graded video task, `.ltTrack` the audio course task, and so on. The Swift names change; **the stored raw values (`"ds.watch"`, `"lt.track"`, `"dreamingSpanish"`) stay**, so every existing store and backup keeps working with no migration. They are opaque identifiers that nobody sees.

One source per role is a limit: a language with two strong graded-video sources can only list one. That is acceptable for now; lifting it means the planner choosing between sources inside a role, which is a larger change.

### Levels

The level thresholds (270 / 410 / 550 / 820 / 1090 / 1450 training hours) are Dreaming Spanish's listening milestones divided by the listening share. For closely related languages the same numbers hold. Each pack states its own six numbers rather than a multiplier, so a language with published milestones of its own can use them. `Band` keeps the level names and strand targets; `hoursThreshold` moves to the pack, and everything that calls it (`Band.forHours`, `Placement`, `LevelGate`, `GoalPace`, `Projection`, `GoalEditor`, `SpeakingProgress`) takes the pack or the thresholds as a parameter.

The level names shown in the app ("Explorador", "Viajero") are decoration and move to the phrasebook.

### Phrasebook

A struct with one field per decoration string, so a missing translation is a compile error, not a blank on screen. From the scan, about 25 entries: week ("Semana"), week complete (two forms), today, done, three greetings, yes, congratulations, let's go, well done, goal reached, days in a row, the six level names, Pico's squawks, the daily reminder title, the test notification title. Day and month names come from the pack's locale, as `SpanishDate` does today.

Widgets and the Live Activity show some of these ("¡Hecho!"). They already link RumboCore, so the widget snapshot only needs to carry the language code.

### Writing check

`CorrectionService.instructions(for:)` becomes a template filled from the pack: the language name, the list of things to check, an example of a tense-and-time-word mismatch, and the level from which explanations are given in the target language. Gemini, Groq and the on-device model all use the same instructions, so there is one place to change. LanguageTool is skipped for a language it doesn't cover. `Mistakes.normalized` (used to match and de-duplicate corrections) needs a check that it handles French elision and accents; it is locale-neutral today, which is probably right.

## 9.4 Stored data

SwiftData models keep the CloudKit rules (defaults on every property, no unique constraints).

- **Language tag.** `LearnerProfile`, `ActivityLog`, `DayPlanRecord`, `WritingEntry` and `ReviewCard` each get `languageCode: String = "es"`. The default makes every existing record Spanish with no migration code. This is the change to make before release.
- **One profile per language.** `LearnerProfile` is "one per install" today. It becomes one per language; the active one is named in `UserDefaults` (and in the shared store, for widgets). `AppModel.profile`, `logs`, `sessions`, the mistake deck and writing history all filter by the active language. `AppModel` is 1,141 lines and reaches these collections in many places, so the filter should go in at the lowest level (the fetches) rather than at each use.
- **Source progress.** The profile has fixed columns per Spanish source (`dsDifficultyLow/High`, `languageTransferLastTrack`, `extraEpisodesWatched`, `duolingoSection/Unit`, …). Because each role has at most one source and each profile is one language, these columns already work as "the graded video window", "the audio course track", and so on. Rename them in Swift with `@Attribute(originalName:)` to keep the stored columns, or leave the names and add role-named accessors. No data moves either way.
- **Settings shared across languages.** Reminder time, week start, AI checker keys and default checker, thinking level: stay global. Weekly goal, target level and date, travel mode, classes/tutoring, plan balance, speaking stage: per language, so they stay on the profile.
- **Backup.** `BackupFile` goes to version 2: a list of profiles, and a language code on each log, writing entry and card. A version 1 file restores as Spanish. Decide whether restoring replaces every language or only the ones in the file; recommend "replaces everything", as now.
- **Path history** (`pathHistoryData`) is on the profile, so it is per language already.
- **Content catalog.** `Rumbo/Resources/catalog/content.json` becomes `content.es.json`, with `content.fr.json` beside it; the remote URL and the cache file take the code. `currentContentID` is on the profile, so it is per language already. Keep serving the old URL for builds already installed.

## 9.5 What changes, file by file

From a scan of all 15,700 lines. "Source names" means references to the five branded sources or their task kinds: about 740 across some two dozen files.

**RumboCore (engine)**

| File | What is Spanish-specific | Change |
| --- | --- | --- |
| `TaskKind.swift` | `SourceKind` and `TaskKind` cases are brands; minute ranges are tuned to those brands | Rename to roles, keep raw values; minute ranges that depend on the product (track length, episode length) come from the pack |
| `Learner.swift` | `Course` (90 tracks, lengths, 13 episodes, 2 parts); `isEligible` hard-codes which levels use which source; snapshot fields named after brands | `Course` moves into the Spanish pack; eligibility reads the pack; the snapshot carries the pack |
| `DayPlanner.swift` | `AnchorTargets` per level; `candidates` lists branded kinds; "short days stay with Dreaming Spanish"; `detail(for:)` builds track, episode and difficulty details | Read anchors and course numbers from the pack; logic stays |
| `SourceProgress.swift` | Advances Language Transfer and Extra by their fixed sizes | Sizes from the pack |
| `Band.swift` | `hoursThreshold`; Spanish level names in `label` | Thresholds to the pack, names to the phrasebook |
| `Levels.swift`, `Progress.swift` | Use `hoursThreshold`; `ComprehensionTuner` assumes a 0–100 scale | Take thresholds as input; tuner uses the pack's scale, and is skipped when the graded source has none |
| `Content.swift` | `WatchedLevel` is "the Dreaming Spanish level watched" | Generic "level watched", shown only when the graded source has a scale |
| `CanDo.swift`, `Prompts.swift`, `PromptLibrary+*.swift` | 25 items say "Spanish" | `{language}` placeholder; per-pack additions |
| `Gemini.swift`, `Groq.swift`, `WritingChecker.swift`, `Mistakes.swift`, `FSRS.swift`, `Lessons.swift`, `StrandBalance.swift`, `PathLayout.swift` | Nothing | None |

**App**

| File | What is Spanish-specific | Change |
| --- | --- | --- |
| `Models/Models.swift` | Brand-named columns; no language tag | §9.4 |
| `Services/AppModel.swift` | Single profile; streak messages mention Spanish; "¡N días seguidos!" | Active language and filtered fetches; copy from pack and phrasebook |
| `Services/Backup.swift` | Version 1, one profile, brand-named fields | Version 2 (§9.4) |
| `Services/Correction.swift` | Tutor instructions; LanguageTool `es` | Template from the pack |
| `Services/Platform.swift` | Reminder text; `DeepLinks` URLs and the YouTube search for Extra | From the pack |
| `Services/ContentLibrary.swift` | One catalog file and URL | Per language |
| `Features/Onboarding/*` | No language choice; steps ask about each Spanish source by name; `OnboardingDraft` has `dreamingHours`, `languageTransferLastTrack`…; `SourceCopy`, `SourceInfoSheet` | New first step "What are you learning?"; source steps generated from the pack's roles |
| `Features/Settings/SettingsView.swift` | Progress steppers per brand; no language row | Rows generated from the pack; a Language row to switch or add |
| `Features/Today/TaskCopy.swift`, `TaskSessionView.swift`, `TodayView.swift` | Titles, instructions and log forms per brand; "¡Buenos días!" | Titles and instructions from the pack's source; greeting from the phrasebook |
| `Features/Path/PathView.swift` | "Semana", "Hoy", "¡Hecho!", `SpanishDate` | Phrasebook and the pack's locale |
| `Features/Gate/GateView.swift`, `Writing/GuidedWritingView.swift`, `DesignSystem/Moments.swift`, `Shared/Pico/PicoView.swift` | Decoration | Phrasebook |
| `Features/Progress/*` | Dreaming Spanish level chart | Label from the pack; hidden without a scale |
| `Features/Library/LibraryView.swift` | Nothing (reads the catalog) | None |
| `Features/Diagnostics/*` | Checks a fixed list of URL schemes | List from all packs |
| `RumboWidgets/*`, `Shared/WidgetSnapshot.swift` | "¡Hecho!" | Language code in the snapshot; phrasebook |
| `project.yml` | `LSApplicationQueriesSchemes` lists Spanish apps | The union of every pack's schemes (it must be fixed at build time) |

**Docs.** `01-research.md` and `02-learning-engine.md` state the Spanish numbers as the rules. They need a split into "the method" and "the Spanish pack", and `06-content-catalog.md` becomes per language.

## 9.6 Phases

Each phase ends with the Spanish app behaving exactly as before, checked by the existing 157 engine tests plus the new ones listed.

**Phase 1: Spanish as a pack (engine only).** Add `LanguagePack` and the Spanish pack. Rename sources and task kinds to roles, keeping raw values. Move `Course`, thresholds, anchors, eligibility levels, can-do and prompts behind the pack. `LearnerSnapshot` carries its pack. No app-visible change.
*Tests:* a test that pins every stored raw value; every existing planner test runs unchanged; a pack validator (thresholds rise, every role's numbers are complete, phrasebook has no empty entries, no shared prompt names a language).

**Phase 2: Storage (do before public release).** Language tag on the five models; profile per language; fetches filtered by the active language; backup version 2 that still reads version 1; catalog per language. With only Spanish available, nothing looks different.
*Tests:* restore a saved version 1 backup; a store with two languages keeps their logs, streaks and plans apart (this needs the filtering logic to sit in RumboCore or be covered by a CI app test, since app code doesn't build on Linux).

**Phase 3: App reads the pack.** Replace every "Spanish" literal, the source copy, links, task titles and instructions, the tutor instructions and the decoration with pack lookups. Onboarding and Settings build their source rows from the pack's roles.
*Check:* a grep in CI that fails on "Spanish", "Dreaming", "Duolingo" and the like outside the pack files.

**Phase 4: Choosing a language.** Onboarding's first step; Settings → Language to switch or add one (adding runs the placement steps again for that language). Hidden while only one pack exists, or shown with French marked "coming soon".

**Phase 5: French pack.** Content, not code. See §9.7.

Phases 1 and 2 are independent and could be done in either order; 3 needs 1; 4 needs 2 and 3.

## 9.7 What the French pack needs

To be researched and checked when Phase 5 starts; nothing below has been verified yet.

- **Sources for each role.** Candidates: Dreaming French (does it have the same 0–100 difficulty scale and hour counter?), Language Transfer's French course (it is an introduction, far shorter than Complete Spanish, so the audio course would run out early in A2), Extra in French (same 13-episode format), Duolingo French, Tandem/HelloTalk. Each needs its real numbers: track count and lengths, episode count, URL schemes and links.
- **Level thresholds.** Start from the Spanish numbers; adjust if a French roadmap is published.
- **Tutor focus.** French error patterns in place of ser/estar and por/para: gender and agreement, passé composé against imparfait, être or avoir as auxiliary, partitive articles, y and en, subjunctive triggers, elision.
- **LanguageTool code** `fr`, and whether the on-device model handles French well enough for the offline fallback.
- **Phrasebook**, about 25 strings, checked by a French speaker.
- **Suggested content**, about 24 items across the six levels, as for Spanish.
- **Prompts and can-do**: read through the shared lists for anything that assumes Spanish-speaking countries.
- **Level names**: French counterparts for Explorador … Local.

## 9.8 Risks

- **Regressions in the Spanish plan.** The planner's behaviour is tuned and tested with Spanish numbers. Phase 1 must not change a single planned minute; the existing tests are the guard, and a snapshot test of a fortnight of plans would make it stricter.
- **`AppModel` and the single-profile assumption.** The largest app-side change. A missed filter would mix two languages' logs into one streak or one level. Putting the filter in the fetches, and testing two languages together, addresses it.
- **Renaming persisted names.** Avoided by keeping raw values and stored column names. The pinning test in Phase 1 makes a slip fail loudly.
- **Uneven languages.** A language with thin sources gives a thinner plan. The app should say so when a language is chosen, not leave it to be discovered.
- **Third-party names.** The packs name other companies' products. That is fine for describing what the learner already uses, but each pack's wording should be checked before a store release.
