# 4. Data model

## 4.1 Storage

**SwiftData**, stored on device only. No Rumbo server and no accounts.

Models still follow CloudKit's rules, so sync could be switched on later for a build signed with an iCloud entitlement:
- Every property is optional or has a default value.
- No `@Attribute(.unique)`.
- Every relationship is optional.
- Enums are stored as `String` raw values.

## 4.2 Models

Defined in `Rumbo/Models/Models.swift`. Enums are stored as raw strings/ints, with typed accessors.

| Model | Holds |
|---|---|
| `LearnerProfile` | One per install: name, goal, target date, band, speaking stage, enabled sources, weekly goal, habit cue and reminder, travel mode, and the learner's place in each source: baseline input hours, Dreaming Spanish difficulty range, Language Transfer track (+ repeat flag), Extra episode and part, Duolingo section/unit. |
| `ActivityLog` | One logged block: date, task, minutes, comprehension rating (input), track rating or Tandem feeling, bonus flag, and the Dreaming Spanish range it was watched at (for difficulty tuning). |
| `DayPlanRecord` + `PlannedTaskRecord` | Today's plan, saved when the budget is picked so it stays stable as courses move forward during the day. Each task keeps its order, minutes, anchor flag, encoded detail (`lt:13`, `extra:2:1`, `ds:40:48`), the prompt fixed at planning time, and status (planned / active / done / skipped). |
| `WritingEntry` | Text written in a writing task, with its prompt. Correction is added in M4. |

Coming later: `ReviewCard` (FSRS state for the mistake deck, M4) and `LevelCheck` (gate attempts, M3).

The budget can be changed until the first task is started; after that the day's plan is fixed.

**Derived, never stored:** total input hours (`baselineInputHours` + sum of `ActivityLog` input minutes), XP, streak, strand balance, projection. Computing them keeps a single source of truth.

## 4.3 No sync or backup

Rumbo keeps everything on the phone. There is no sync and no backup file: CloudKit needs an entitlement the author's signing profile doesn't grant, and every iCloud Drive backup approach failed on device in M0.

If the app is lost (new phone, reinstall, new certificate), the learner simply onboards again. That's cheap by design:
- The numbers that matter live in the sources themselves: Dreaming Spanish hours, the Language Transfer track, the Duolingo unit and Extra episodes. Onboarding asks for exactly these, so the plan picks up where it left off.
- What's lost is Rumbo's own history: streak, XP, writing entries and the mistake deck.
- Onboarding should take about 2 minutes (see [03-experience.md](03-experience.md#onboarding-first-launch-about-2-minutes)).
