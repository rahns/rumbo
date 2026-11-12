# 9. Supporting languages other than Spanish

**Status: built. Spanish and French can both be chosen.** The French pack (§9.7) rests on a few judgements that are listed there. This doc is the design for teaching several languages and the record of what was decided. French is the second language. The app's own text stays in English.

## 9.1 Summary

Rumbo's engine is mostly language-neutral already: the four strands, the planner's balancing, streaks, freezes, goals, FSRS, classes/tutoring, the path, and the plan balance don't care what is being learned. Spanish lives in five places:

1. **The sources.** Dreaming Spanish, Language Transfer, Extra en Español, Duolingo and Tandem/HelloTalk are named in enums (`SourceKind`, `TaskKind`), and their facts are constants: 90 tracks and their lengths, 13 episodes, a 0–100 difficulty scale, which levels each one is used at.
2. **The level model.** The training hours each level starts at come from Dreaming Spanish's roadmap for English speakers.
3. **Words.** About 40 English sentences in the app say "Spanish"; 22 prompts and 3 can-do statements do too; the suggested content list is Spanish shows.
4. **The writing check.** The tutor instructions name Spanish grammar points (ser/estar, por/para), and the basic checker asks LanguageTool for `es`.
5. **Flavour.** Spanish words used as decoration: "Semana 3", "Hoy", "¡Hecho!", "¡Buenos días!", level names ("Explorador"), Pico's squawks, Spanish day names on the path.

The plan is to gather all five into one value per language, a **language pack**, and have the engine and the app read from the active pack instead of from constants. Spanish becomes the first pack, with identical behaviour; French is then mostly content work, not code.

Two things should land **before the first public release**, because they are cheap now and costly once people have data on their phones: tagging stored data with its language (§9.4), and a backup format that carries the tag (§9.4). Everything else can follow in any order.

## 9.2 Decisions

| # | Decision | Settled |
| --- | --- | --- |
| 1 | Can someone learn two languages at once in the app? | Data is stored so they can (every record tagged), with **one active language**, switchable in Settings. Each language has its own level, plan, weekly goal, streak and history. Onboarding starts by choosing the language. |
| 2 | The Spanish decoration ("Semana", "¡Hecho!") for other languages | Translated per language through the pack's phrasebook. |
| 3 | Name and mascot | **Rumbo** and **Pico** stay for every language, as do the welcome screen's "¡Hola!" and "¿Rumbo a dónde?". The daily reminder's title is in the phrasebook, so a language can keep or translate it. |
| 4 | Level range | A2–B2 for every language. |
| 5 | A language with no good source for a role | Ships anyway: the planner passes on the share of a strand that has nothing to plan (tested with a pack that has only writing, a partner and suggested content). |
| 6 | Which languages after French | Not decided. Languages that need different text handling (Japanese, Korean, Mandarin, Arabic) are for later. |

## 9.3 Design

### Language pack

A type in RumboCore, `LanguagePack` (`LanguagePack.swift`), one static value per language (`LanguagePack.spanish` in `LanguagePack+Spanish.swift`), listed in `LanguagePack.all` and looked up by code (`LanguagePack.pack(for: "es")`; an unknown code gives Spanish). Packs are Swift values, not downloaded files, so they are type-checked and unit-tested like the rest of the engine. The one bulky list that already updates over the air (suggested content) stays a JSON file, one per language.

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

Can-do statements and prompts are English text about everyday life and are nearly the same for every language. They are shared lists with a `{language}` placeholder ("Order food or a drink entirely in {language}") and place words from the pack (`{region}`, `{regional}`, `{places}`, `{filmOrigin}`: "a festival in Latin America" or "in France"). A pack can add travel missions of its own.

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

In code the roles are `gradedVideo`, `audioCourse`, `learnerSeries`, `drillApp`, `writing`, `exchange` and `suggestedContent`; the task kinds are `gradedWatch`, `gradedEasy`, `courseTrack`, `seriesIntensive`, `seriesExtensive`, `drillLesson`, `exchangeText/Voice/Call`. `LanguagePackTests.storedIdentifiersNeverChange` pins the stored values.

**How the app reaches the pack.** The engine takes it explicitly: `LearnerSnapshot.pack`, and a `pack` or `levels` argument on everything that depends on the language (`Placement`, `LevelGate`, `Projection.arrivalDates`, `GoalPace`, `CanDo`, `Prompts`, `SourceProgress.record`). In the app, `AppModel.languageCode` and `AppModel.pack` are the active language, and each `LearnerProfile` has its own `pack`. Wording that isn't inside a view with the model at hand (task titles in `TaskCopy`, source names in `SourceCopy`, links, reminders, the tutor's instructions, the path's dates) reads `ActiveLanguage.pack` (`Shared/ActiveLanguage.swift`), a global that `AppModel` keeps equal to its own language and that is remembered in `UserDefaults` (`language.active`). Widgets get the code in their snapshot (`WidgetSnapshot.languageCode`).

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

- **Language tag.** `LearnerProfile`, `ActivityLog`, `DayPlanRecord`, `WritingEntry` and `ReviewCard` each have `languageCode: String = "es"` (protocol `LanguageTagged`). The default makes every record saved before this Spanish, with no migration code. New records are tagged in one place, `AppModel.insert`.
- **One profile per language.** `AppModel.profiles` is every language's profile; `AppModel.profile` is the active language's (nil until that language has been set up, which is what shows onboarding). `logs`, `sessions`, `allCards` and `dueCards` fetch with a predicate on the active language, so everything built on them (streak, weekly minutes, training hours, the path, the planner's history, used prompts, the mistake deck) is per language without further changes. At launch, if the remembered language has no profile but another does, that one becomes active.
- **Source progress.** The profile keeps its columns (`dsDifficultyLow/High`, `languageTransferLastTrack`, `extraEpisodesWatched`, `duolingoSection/Unit`, `keepDuolingoInB2`, `alwaysIncludeDuolingo`). The names are from when Spanish was the only language; they hold the same things for any language's graded video, audio course, learner series and drill app. They weren't renamed, so no stored column changes. `SourceProgress` (saved with each task for undo) has role names in code and the old names as coding keys.
- **Shared across languages.** Reminder time, week start, AI checker keys and default checker, thinking level are on each profile or in the Keychain as before; with several profiles, reminders follow the active one. One-off moments ("7-day streak") are remembered per language: Spanish keeps its plain keys, other languages prefix theirs with the code.
- **Start over** removes the active language's records only; another language's profile, if there is one, becomes active.
- **Backup.** `BackupFile` version 2: `profiles` (every language), `activeLanguage`, and an optional `language` on each profile, log, writing entry and card. `profile` is still written (the active one). A version 1 file has none of these and restores as Spanish. Restoring replaces everything, in every language. Field names for source progress are unchanged.
- **Path history** and the plan balance are on the profile, so they are per language.
- **Content catalog.** `LanguagePack.catalog` names the bundled file, the remote URL and the cache file. Spanish keeps `content.json` and its URL, so installed builds keep updating; French will add `content.fr.json`.

## 9.5 What changed, file by file

The list the work followed, from a scan of all 15,700 lines. "Source names" means references to the five branded sources or their task kinds: about 740 across some two dozen files.

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

| Phase | What | State |
| --- | --- | --- |
| 1 | **Spanish as a pack (engine).** `LanguagePack`, roles, level hours, anchors, can-do and prompts behind the pack | Built. 165 engine tests: the planner's are unchanged apart from names, plus `LanguagePackTests` (stored values pinned, every pack complete, shared wording names no language, a pack with few sources still fills the day, level hours per language) |
| 2 | **Storage.** Language tag, a profile per language, filtered fetches, backup version 2, catalog per language | Built. Not yet run on a device: the app doesn't compile on Linux, so the first CI build is its test |
| 3 | **App reads the pack.** Source names and info, task titles and instructions, links, reminders, the tutor, the decoration, Settings and Progress rows | Built |
| 4 | **Choosing a language.** Onboarding's first step after the welcome ("What are you learning?", with French shown as coming soon); Settings → Language (a plain row while there is one language, a picker once there are two; picking a language with no profile starts its setup, and picking one that's already set up from within onboarding switches to it) | Built |
| 5 | **French pack.** `LanguagePack+French.swift`, `content.fr.json`, place words in shared prompts, Cancel when adding a language (§9.7) | Built. Engine tests cover its numbers, its words, its suggestions list and plans before and after its short course runs out |

Still to check on a device (the app doesn't compile on Linux):
- A version 1 backup restoring into this build.
- Setting up French beside Spanish, switching between them in Settings → Language, and each keeping its own streak, plan and widgets.
- The French words on screen, which no French speaker has read yet.

The widget gallery's sample and the Live Activity test in Diagnostics show Spanish source names; they are samples.

## 9.7 The French pack

`LanguagePack.french`. Where each part comes from, and how sure it is:

| Part | French | Basis |
| --- | --- | --- |
| Graded video | **Dreaming French** (dreaming.com/french), same site and app as Dreaming Spanish; counts hours | Confirmed live. The 0–100 difficulty number is assumed from the shared platform (a learner's post mentions "difficulty level 20 or lower"); **check in the app**. Same `dreaming://` scheme |
| Audio course | **Language Transfer, "Introduction to French"**: 40 tracks, 6 h 37 min | Track lengths measured from Language Transfer's own download (`downloads.languagetransfer.org/french/french.zip`). It is an introduction, so it ends early in A2; grammar & vocab time then comes from Duolingo and the mistake deck (tested) |
| Learner series | **Extra French** (Extr@): 13 episodes, same sitcom, set in Paris | Confirmed (Channel 4 Learning; A2–B1). Opened by a YouTube search, as for Spanish; no official channel found |
| Drill app, exchange partner | Duolingo, Tandem/HelloTalk | Same apps and schemes |
| Level hours | 310 / 470 / 630 / 940 / 1250 / 1670 | **A judgement:** Spanish's hours plus 15%. No French roadmap is published; Dreaming's FAQ says the early phase "may be slightly longer if instead of Spanish or Italian you are learning Portuguese, or especially French". Change the six numbers in the pack if better figures appear |
| Weekly anchors, source levels | Same as Spanish | The sources are used the same way |
| Tutor | passé composé or imparfait, être or avoir and participle agreement, gender and number, articles and "de" after a negative, y and en, prepositions, subjunctive, elision; LanguageTool `fr`; explanations in French from B2.1 | Written for this pack |
| Phrasebook | "Semaine", "Aujourd'hui", "C'est fait !", "Bonjour" / "Bonsoir", "Oui !" / "Pas encore", "Objectif atteint !", "7 jours d'affilée !", reminder title "On y va ?", Pico's "Allez !", "Bravo !", … Levels: Explorateur, Voyageur, Flâneur, Bavard, À l'aise, Habitué | Written for this pack, **not yet read by a French speaker**. A no-break space comes before "!" and "?" |
| Suggested content | `Rumbo/Resources/catalog/content.fr.json`, 25 items, at least 5 per level | Learner-made ones (InnerFrench, Easy French, Alice Ayel, French Mornings, Français Authentique, Duolingo French Podcast, Journal en français facile) were found in several recommendation lists. Native ones (Peppa Pig, Trotro, Le Petit Nicolas, C'est pas sorcier, HugoDécrypte, Lupin, Dix pour cent, Plan Cœur, Au service de la France, Le Bureau des légendes, Transfert, Les Pieds sur terre, films) are from general knowledge: **levels and where to watch need a check**, as streaming catalogues vary by country. Most links are YouTube searches so they can't go stale |
| Place words | "France", "French", "France, Quebec or Belgium", "France or Quebec" | For shared prompts that named Latin America (`LanguagePack.wording`; Spanish's read exactly as before) |

Adding French needed no change to `project.yml`: its sources open with the same URL schemes as Spanish's.

## 9.8 Risks

- **Regressions in the Spanish plan.** The planner's behaviour is tuned and tested with Spanish numbers. Phase 1 must not change a single planned minute; the existing tests are the guard, and a snapshot test of a fortnight of plans would make it stricter.
- **`AppModel` and the single-profile assumption.** The largest app-side change. A missed filter would mix two languages' logs into one streak or one level. Putting the filter in the fetches, and testing two languages together, addresses it.
- **Renaming persisted names.** Avoided by keeping raw values and stored column names. The pinning test in Phase 1 makes a slip fail loudly.
- **Uneven languages.** A language with thin sources gives a thinner plan. The app should say so when a language is chosen, not leave it to be discovered.
- **Third-party names.** The packs name other companies' products. That is fine for describing what the learner already uses, but each pack's wording should be checked before a store release.
