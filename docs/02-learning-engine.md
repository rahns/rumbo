# 2. Learning engine

The engine is pure Swift with no UI or Apple-framework dependencies (`RumboCore`), so every rule here is unit-testable. References like (R3) point to [01-research.md](01-research.md).

## 2.1 Levels (bands)

Rumbo uses six internal bands. Each band has an **input-hours threshold** (hours of comprehensible input, measured the way Dreaming Spanish counts them) and a **can-do check** (10 self-assessment statements adapted from the CEFR self-assessment grid).

| Band | Label in app | Input hours | Example can-do statement |
|---|---|---|---|
| A2.1 | Explorador | 150–225 | "I can follow a slow, clear video about daily life on a familiar topic." |
| A2.2 | Viajero | 225–300 | "I can describe my day and my plans in simple connected sentences." |
| B1.1 | Andante | 300–450 | "I can understand the main points of a podcast about a topic I know." |
| B1.2 | Conversador | 450–600 | "I can tell a story about something that happened to me, using past tenses." |
| B2.1 | Fluido | 600–800 | "I can follow most of a TV series episode for native speakers." |
| B2.2 | Local | 800–1000 | "I can keep up in a group conversation and give my opinion with reasons." |

Reaching the end of B2.2 completes the goal. After that Rumbo switches to a **maintenance plan** (same engine, B2.2 targets, mostly native content).

Learners below 150 h can still use Rumbo. Onboarding shows a note that it's designed from A2 and places them in A2.1.

### Placement (onboarding)

1. `inputHours` = Dreaming Spanish hours, or, for people who don't use Dreaming Spanish, an estimate of total hours of Spanish watched or listened to with mostly-understood content.
2. Band by hours, using the table above.
3. Can-do adjustment: if the learner ticks ≥ 8/10 statements from the **next** band, move up one. If they tick < 5/10 of their **own** band's statements, move down one. The adjustment is at most ±1.

### Promotion (level-up gates)

- When `inputHours` crosses the next threshold, a **gate node** appears on the path.
- At the gate, the learner takes the next band's can-do check. Passing needs ≥ 7/10 → promotion, with a celebration and the new strand mix.
- Failing has no penalty: the plan continues and the gate reopens in 14 days.
- Hours never go down. Bands never go down automatically. A learner can move themselves down a band in Settings.

## 2.2 Strands and targets by band

Every task belongs to exactly one strand (R1). The planner targets these shares of total minutes, **balanced over a rolling 7 days, not per day**. That is what makes irregular 15–45 minute days work.

| Band | Input | Output | Language-focused | Fluency |
|---|---|---|---|---|
| A2.1 | 45% | 15% | 30% | 10% |
| A2.2 | 45% | 18% | 27% | 10% |
| B1.1 | 45% | 22% | 20% | 13% |
| B1.2 | 45% | 25% | 15% | 15% |
| B2.1 | 45% | 28% | 12% | 15% |
| B2.2 | 45% | 30% | 10% | 15% |

The trend: output grows and language-focused study shrinks as structured courses finish (R4, R5, R15). Why input stays above Nation's 25% is explained in [01-research.md](01-research.md#where-rumbo-deliberately-deviates).

## 2.3 Task catalog

Times are minutes: min / default / max per day.

| Task ID | Strand | Min/Def/Max | Bands | Notes |
|---|---|---|---|---|
| `duo.lesson` | Language | 5 / 5 / 5 (never more) | A2.1–B1.2, optional in B2.1 | Retrieval warm-up (R7, R15) |
| `lt.track` | Language | 8 / 12 / 25 | Until the course is done | Next track. Rated "shaky" → repeat it once. |
| `ds.watch` | Input | 8 / 20 / 60 | All | At the suggested difficulty (§2.6) |
| `ds.easy` | Fluency | 8 / 10 / 20 | All | Videos 10–15 points below your level, at normal speed (R8) |
| `extra.intensive` | Input | 10 / 12 / 15 | A2.1–A2.2 | One part = half an episode. Step 1: watch with Spanish subtitles (R9). Step 2: rewatch one scene and shadow it for 2–3 min (R10). Counted as input: it's mostly captioned viewing, and counting it as language study crowded out Language Transfer in simulations. |
| `extra.extensive` | Input | 12 / 25 / 30 | B1.1–B1.2 | One episode straight through, can be split over 2 days |
| `content.watch` / `content.listen` | Input | 10 / 20 / 60 | When a source has run out | From the [content catalog](06-content-catalog.md) |
| `write.guided` | Output | 8 / 12 / 20 | All | Words: A2 50–100, B1 120–180, B2 200–300. Write → AI feedback → rewrite (R11). |
| `write.quick` | Fluency | 5 / 5 / 10 | B1.1+ | Timed free-write on an easy topic; no correction, just volume |
| `tandem.text` | Output | 5 / 10 / 15 | All | Message with a prompt. Corrections from the partner can be logged into the mistake deck. |
| `tandem.voice` | Output | 8 / 10 / 15 | From voice stage | Planned: 3 min bullet points → 1–2 min recording (R6) |
| `tandem.call` | Output | 15 / 20 / 30 | From call stage | Includes a 3-question prep card |
| `fluency.432` | Fluency | 10 / 10 / 12 | From voice stage | Same story in 4 → 3 → 2 minutes, recorded in-app (R8) |
| `review.mistakes` | Language | 3 / 5 / 10 | All | Only when cards are due (FSRS scheduling) |
| `mission.travel` | Output | 5 / 10 / 20 | All, Travel mode | Real-world task, e.g. "Ask for a recommendation at the hostel and log two phrases you heard." |

If a source is disabled, its tasks are never planned. Its strand's minutes go to the other tasks in the same strand.

## 2.4 Speaking stages (Tandem)

Staged to reduce anxiety and add planning time (R5, R6):

| Stage | Unlocks when | Tasks |
|---|---|---|
| 1. Text | Start | `tandem.text` |
| 2. Planned voice notes | `inputHours ≥ 250` **and** ≥ 8 text exchanges logged over ≥ 3 weeks **and** the learner rates text chats as "comfortable" | adds `tandem.voice`, `fluency.432` |
| 3. Live calls | `inputHours ≥ 400` **and** ≥ 6 voice notes logged | adds `tandem.call` |

The learner can always unlock a stage early with "I feel ready". Autonomy matters more than the gate.

## 2.5 Daily planner

### Inputs
Band, today's budget `B` (10 / 15 / 20 / 30 / 45 / 60 min, chosen at the start of the day), the last 6 days of logged minutes per strand, source states, speaking stage, Travel/offline mode, weekly anchors still due, and the number of due mistake cards.

### Algorithm
Implemented in `RumboCore/DayPlanner.swift`.

1. **Warm-up.** If `B ≥ 15` and the band uses Duolingo, plan `duo.lesson` 5 min. If `B ≥ 20` and ≥ 5 cards are due, plan `review.mistakes` (3 min, or 5 from 30 min).
2. **Deficits.** For each strand: `target = share × (logged last 6 days + B)`, then `deficit = target − logged last 6 days − planned today`.
3. **Fill with new cards.** While there are fewer than 4 cards:
   - Pick the strand with the largest deficit.
   - Within that strand, take the first task not already planned, in this order: a **weekly anchor** that's due (see below), then the next **progression** task (next Language Transfer track, next Extra part), then the defaults.
   - Allocate `clamp(round5(deficit), min, max)`, but never more than what's left. If nothing in the strand fits, move to the next strand.
4. **Leftover.** Minutes too few for a new card go to existing cards that have headroom: input first, then the strand with the largest deficit.
5. **Limits.** At most 4 cards per day (to keep cognitive load low) **[design]**, and at most **one weekly anchor per day (two from 45 min)**, so a fresh week spreads its anchors out instead of crowding out progression **[design]**.
6. **Order.** Warm-up → language-focused → input → output → fluency (R4, R7 **[design]**). The output card's prompt reuses that day's Language Transfer track or Extra episode (R4).
7. **Tiny days.** If `B = 10`, plan exactly one task: the strand with the largest deficit, using its first task that fits.

### Weekly anchors
Planned on the first day the budget allows, so they don't depend on a fixed weekday (which wouldn't survive backpacking).

| Anchor | A2 | B1 | B2 |
|---|---|---|---|
| `write.guided` | 1×/week | 2×/week | 2–3×/week |
| Extra en Español | 1 intensive part/week, on a day with 20+ min (an episode a fortnight) | 1 episode/week, on a day with 20+ min | — |
| Tandem exchange (any stage) | 3×/week | 3×/week | 3×/week |
| `fluency.432` | — | 1×/week once unlocked | 1×/week |
| `tandem.call` | — | 1×/week once calls are unlocked | 1×/week once calls are unlocked |

Dreaming Spanish is the main input source; Extra is a weekly change of pace (it's a weekly anchor, but only on days with at least 20 minutes, so short days stay with Dreaming Spanish). Duolingo is only ever a 5-minute warm-up: leftover minutes never go to it, and a 10-minute day picks a task that fills the whole time.

### Example: A2.1, first day, Language Transfer track 13 next, Extra episode 2 next

Real planner output (no history yet, so every anchor is due; * = weekly anchor):

| Budget | Plan |
|---|---|
| 10 min | Dreaming Spanish 10 |
| 15 min | Duolingo 5 → Dreaming Spanish 10 |
| 20 min | Duolingo 5 → Extra ep. 2 part 1* (10) → Tandem text 5 |
| 30 min | Duolingo 5 → Extra ep. 2 part 1* (15) → Tandem text 10 |
| 45 min | Duolingo 5 → LT track 13 (10) → Extra ep. 2 part 1* (15) → Guided writing* (15) |
| 60 min | Duolingo 5 → LT track 13 (15) → Extra ep. 2 part 1* (15) → Dreaming Spanish 25 |

Over an irregular fortnight (15/45/20/30/10/45/30, twice) at A2.1 the planner gives 45% input, 14% output, 30% language-focused and 9% fluency, with Language Transfer on 5 days, Dreaming Spanish on 10, Extra on 2, guided writing twice and Tandem on 6 days. These are checked by tests at A2.1, B1.1 and B2.2 (within 5 points of every target).

## 2.6 Keeping input comprehensible

After every input session the learner rates comprehension in one tap (R3):

| Rating | Meaning |
|---|---|
| 😵 Lost | Understood less than ~70% |
| 🙂 Mostly | Understood ~80–90% |
| 😎 Easy | Understood more than ~95% |

Over the last 5 ratings at the current difficulty: 3 or more "Easy" → suggest raising the Dreaming Spanish difficulty range by 5. Two or more "Lost" → suggest lowering it by 5. The range is shown on the `ds.watch` card ("Look for videos rated 40–48").

## 2.7 Travel mode

- **Offline preference.** Tasks are marked offline-capable or not. Offline: downloaded Language Transfer tracks, Dreaming Spanish downloads (where the user's DS subscription allows), writing with on-device AI feedback. Online-only: LanguageTool, Extra on YouTube (unless downloaded with YouTube Premium).
- **Missions.** `mission.travel` becomes the preferred output task.
- **Bonus input.** One-tap logging for Spanish heard outside the app (a bus podcast, a tour in Spanish, a long conversation). It counts toward input hours and strand balance.

## 2.8 Streaks, XP and goals

| Mechanic | Rule |
|---|---|
| Weekly goal | Main metric, chosen in onboarding (default 150 min/week). Shown as a ring. |
| Streak | A day counts if ≥ 10 minutes are logged (R12) |
| Streak freeze | Earn 1 for each week you meet the weekly goal; hold at most 3; used automatically |
| XP | 1 per minute logged, +10 per completed card, +25 for a writing rewrite, +50 for passing a gate |

## 2.9 Projection

Weekly input hours = rolling average over the last 4 weeks, including bonus input. For a newer learner the average covers only the days since their first log (at least 7), so one short first session isn't read as a month-long pace. Until there's a week of history, the forecast assumes the learner meets their weekly goal (goal minutes × the band's input share). Rumbo projects a date for each remaining band threshold and shows it against the learner's target date ("At this pace you'll reach B1.2 by March 2028. +10 min/day → December 2027").

Example (the author, at the time of writing): 154 h. At ~18 min/day of input → ~110 h/year → about 400–450 h by mid-2028 (B1). Logging an extra 30 min/day of outside listening → about 650 h (B2.1).
