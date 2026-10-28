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
| `LearnerProfile` | One per install: name, goal, target date, band, gates passed, last failed gate, speaking stage, enabled sources, weekly goal, habit cue and reminder, week start, travel mode, the Library item being watched (`currentContentID`), and the learner's place in each source: baseline input hours, Dreaming Spanish difficulty range, Language Transfer track (+ repeat flag), Extra episode and part, Duolingo section/unit. |
| `ActivityLog` | One logged block: date, task, minutes, comprehension rating (input), track rating or Tandem feeling, bonus flag, the Dreaming Spanish range it was watched at (for difficulty tuning), and the level the learner says they watched (`levelWatched`, Dreaming Spanish and Easy Dreaming, for the Progress chart). |
| `DayPlanRecord` + `PlannedTaskRecord` | A day's plan, saved when the budget is picked so it stays stable as courses move forward during the day. `day` is the calendar day the plan is *for*: a plan made early (working ahead) is stored under the later day. Each task keeps its order, minutes, anchor flag, an `isExtra` flag (added from "Keep going" after the plan was complete; extras don't count toward the day being complete), the writing draft, rewrite and feedback while a writing task is in progress (kept as they're typed), encoded detail (`lt:13`, `extra:2:1`, `ds:40:48`), the prompt fixed at planning time, and status (planned / active / done / skipped). Once done, it also keeps what's needed to undo it: the log and writing entry IDs, the course progress before, and the previous Duolingo position. |
| `WritingEntry` | Text written in a writing task, with its prompt, the correction (encoded `CorrectionService.Result`) and the learner's rewrite. |
| `ReviewCard` | A mistake-deck card: front, back, explanation, origin (writing / tandem / manual), the writing entry it came from, and its FSRS state (due, stability, difficulty, reps, lapses, state, last review). |

Gate attempts are stored on the profile (`gatesPassed`, `lastFailedGate`) rather than as their own model.

The budget can be changed until the first task is started; after that the day's plan is fixed.

**Derived, never stored:** training hours (`baselineInputHours` ÷ 0.55 + every `ActivityLog` minute), listening hours (`baselineInputHours` + listening minutes, for speaking stages), streak, strand balance, projection. Computing them keeps a single source of truth.

## 4.3 No sync; manual backup

Rumbo keeps everything on the phone. There is no sync and no automatic backup: CloudKit needs an entitlement the author's signing profile doesn't grant, and Rumbo can't keep access to a file in iCloud Drive across launches on that setup (M0).

**Manual backup** (Settings → Backup), implemented in `Rumbo/Services/Backup.swift`:
- **Save backup** writes `Rumbo Backup YYYY-MM-DD.json` wherever the learner chooses, through the system save dialog. It holds the profile, every activity log, every writing entry (with feedback and rewrite) and every mistake-deck card with its schedule. Fields added after version 1 (cards, gates, week start, watched item, level watched) are optional, so older backups still restore. Today's plan (with any extras and unsaved writing drafts) and the Gemini API key (Keychain only) aren't included: the plan is rebuilt from the history, and the key is pasted again. A restored profile is brought up to date like an old one: a 5-point Dreaming Spanish range and a target date that matches the weekly goal.
- **Restore from a backup** picks a file, imports a copy, decodes it fully, asks for confirmation, then replaces everything. Also offered on the first onboarding screen, for a new phone or reinstall.
- The file has a `version` number; a backup from a newer Rumbo is refused with a message rather than half-read.

If the app is lost without a backup, the learner onboards again. That's cheap by design:
- The numbers that matter live in the sources themselves: Dreaming Spanish hours, the Language Transfer track, the Duolingo unit and Extra episodes. Onboarding asks for exactly these.
- What's lost is Rumbo's own history: streak, writing entries and the mistake deck.
