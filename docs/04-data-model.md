# 4. Data model and backup

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

## 4.3 No sync; manual backup

Rumbo keeps everything on the phone. There is no sync and no automatic backup: CloudKit needs an entitlement the author's signing profile doesn't grant, and Rumbo can't keep access to a file in iCloud Drive across launches on that setup (M0).

**Manual backup** (Settings → Backup), implemented in `Rumbo/Services/Backup.swift`:
- **Save backup** writes `Rumbo Backup YYYY-MM-DD.json` wherever the learner chooses, through the system save dialog. It holds the profile, every activity log and every writing entry. Today's plan isn't included; it's rebuilt from the history.
- **Restore from a backup** picks a file, imports a copy, decodes it fully, asks for confirmation, then replaces everything. Also offered on the first onboarding screen, for a new phone or reinstall.
- The file has a `version` number; a backup from a newer Rumbo is refused with a message rather than half-read.

If the app is lost without a backup, the learner onboards again. That's cheap by design:
- The numbers that matter live in the sources themselves: Dreaming Spanish hours, the Language Transfer track, the Duolingo unit and Extra episodes. Onboarding asks for exactly these.
- What's lost is Rumbo's own history: streak, XP, writing entries and the mistake deck.
