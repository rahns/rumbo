# 2. Learning engine

> **Languages.** This chapter states the rules with Spanish's sources and numbers, because Spanish is the language they were tuned on. In code, everything that depends on the language (the hours each level starts at, which product fills each source role and its sizes, the weekly anchors, the can-do wording) comes from the active `LanguagePack`; the method (strands, planning steps, streaks, goals) is the same for every language. See [09-multi-language.md](09-multi-language.md).

The engine is pure Swift with no UI or Apple-framework dependencies (`RumboCore`), so every rule here is unit-testable. References like (R3) point to [01-research.md](01-research.md).

## 2.1 Levels (bands)

Rumbo uses eight internal bands, from a complete beginner (A1.1, zero hours) to B2.2. Each band has a **training-hours threshold** and a **can-do check** (10 self-assessment statements adapted from the CEFR self-assessment grid).

**Training hours** count every minute of practice logged in Rumbo, whatever the strand. The thresholds start from Dreaming Spanish's listening-hour milestones (0 / 50 / 150 / 225 / 300 / 450 / 600 / 800 / 1000) and divide them by the plan's listening share, **55%**, rounded to 10: a learner following the mix reaches each listening milestone at the same time as the training-hour threshold. Listening done before Rumbo (the Dreaming Spanish counter at onboarding) is converted the same way, ÷ 0.55, so 150 h becomes about 273 training hours. **[design]**

Sanity check against other sources (checked October 2026): Cambridge English puts B1 at about 350–400 and B2 at about 500–600 *guided* (classroom) hours; total study is usually put at about twice that. The FSI's 600–750 class hours for Spanish to professional working proficiency is often quoted as about 1,200–1,500 hours with self-study. B1.1 at 550 and B2.1 at 1,090 sit inside those ranges.

| Band | Label in app | Training hours | (Listening milestone) | Example can-do statement |
|---|---|---|---|---|
| A1.1 | Novato | 0–90 | 0 | "I can say my name and where I'm from." |
| A1.2 | Aprendiz | 90–270 | 50 | "I can introduce myself and ask someone their name, age and where they live." |
| A2.1 | Explorador | 270–410 | 150 | "I can follow a slow, clear video about daily life on a familiar topic." |
| A2.2 | Viajero | 410–550 | 225 | "I can describe my day and my plans in simple connected sentences." |
| B1.1 | Andante | 550–820 | 300 | "I can understand the main points of a podcast about a topic I know." |
| B1.2 | Conversador | 820–1,090 | 450 | "I can tell a story about something that happened to me, using past tenses." |
| B2.1 | Fluido | 1,090–1,450 | 600 | "I can follow most of a TV series episode for native speakers." |
| B2.2 | Local | 1,450–1,820 | 800 | "I can keep up in a group conversation and give my opinion with reasons." |

Speaking-stage unlocks (§2.4) still use **listening** hours, since they're about how much the learner understands.

Reaching the end of B2.2 completes the goal. After that Rumbo switches to a **maintenance plan** (same engine, B2.2 targets, mostly native content).

Complete beginners start at A1.1 with zero hours: onboarding has an "I'm completely new" choice that skips the hours and can-do questions. See [10-beginners.md](10-beginners.md) for how the plan differs at A1. (French levels start a little later; each language's hours are in its pack.)

### Placement (onboarding)

1. Listening hours = Dreaming Spanish hours, or, for people who don't use Dreaming Spanish, an estimate of total hours of Spanish watched or listened to with mostly-understood content. These are converted to training hours (÷ 0.55).
2. Band by hours, using the table above.
3. Can-do adjustment: if the learner ticks ≥ 8/10 statements from the **next** band, move up one. If they tick < 5/10 of their **own** band's statements, move down one. The adjustment is at most ±1.

### Promotion (level-up gates)

- When training hours cross the next threshold, a **gate node** appears on the path.
- At the gate, the learner takes the next band's can-do check. Passing needs ≥ 7/10 → promotion, with a celebration and the new strand mix.
- Failing has no penalty: the plan continues and the gate reopens in 14 days.
- Hours never go down. Bands never go down automatically. A learner can move themselves down a band in Settings.

## 2.2 Strands and targets by band

Every task belongs to exactly one strand (R1). The planner targets these shares of total minutes, **balanced over a rolling 7 days, not per day**. That is what makes irregular 15–45 minute days work.

| Band | Input | Output | Language-focused | Fluency |
|---|---|---|---|---|
| A1.1 | 55% | 5% | 40% | 0% |
| A1.2 | 55% | 10% | 35% | 0% |
| A2.1 | 55% | 13% | 24% | 8% |
| A2.2 | 55% | 15% | 22% | 8% |
| B1.1 | 55% | 18% | 18% | 9% |
| B1.2 | 55% | 20% | 15% | 10% |
| B2.1 | 55% | 23% | 10% | 12% |
| B2.2 | 55% | 25% | 8% | 12% |

A strand at **0%** (fluency at A1, or one set to 0% in a custom balance) is hidden everywhere: it gets no cards, isn't offered in Keep going or Log other, and has no row on Progress → strand balance.

**Custom plan balance** (Settings → Plan balance, `StrandBalance`): the learner can replace this split with their own, in whole percentages in steps of 5 that always add up to 100. Moving one strand scales the others to fill the rest, keeping their proportions (evenly if they were all 0). The custom split is used for every deficit (`LearnerSnapshot.strandTargets`) until the learner switches back to Rumbo's. A strand at 0% never gets a new card (step 3 and the 10-minute single task skip it). A strand the planner can't fill today (nothing eligible: say Language Transfer and Duolingo are off and no mistake cards are due, `LearnerSnapshot.canPlan`) has its share spread over the others in proportion, with the default split too; if a custom split puts everything on such strands, the band's split is used for the rest, so the plan is never left empty. Settings → Plan balance flags such a strand under its slider, and Progress → strand balance uses the same effective targets; classes/tutoring, the Duolingo warm-up, the mistake review and the travel mission are planned as usual. Tested in `StrandBalanceTests`.

The trend: output grows and language-focused study shrinks as structured courses finish (R4, R5, R15). Why input stays above Nation's 25% is explained in [01-research.md](01-research.md#where-rumbo-deliberately-deviates).

## 2.3 Task catalog

Times are minutes: min / default / max per day.

| Task ID | Strand | Min/Def/Max | Bands | Notes |
|---|---|---|---|---|
| `duo.lesson` | Language | 5 / 5 / 5 (never more) | A2.1–B1.2, optional in B2.1 | Retrieval warm-up (R7, R15) |
| `lt.track` | Language | track's real length, 5–16 (rounded up from the audio) | Until the course is done | Next track. Logging it asks which track the learner is up to now (defaults to the next one; set it back to repeat a track, or on if they did several). |
| `ds.watch` | Input | 8 / 20 / 60 | All | At the suggested difficulty (§2.6) |
| `ds.easy` | Fluency | 8 / 10 / 20 | All | Videos 10–15 points below your level, at normal speed (R8) |
| `extra.intensive` | Input | 10 / 12 / 15 | A2.1–A2.2 | One part = half an episode. Step 1: watch with Spanish subtitles (R9). Step 2: rewatch one scene and shadow it for 2–3 min (R10). Counted as input: it's mostly captioned viewing, and counting it as grammar & vocab crowded out Language Transfer in simulations. |
| `extra.extensive` | Input | 12 / 25 / 30 | B1.1–B1.2 | One episode straight through, can be split over 2 days |
| `content.watch` / `content.listen` | Input | 10 / 20 / 60 | When a source has run out | From the [content catalog](06-content-catalog.md) |
| `write.guided` | Output | 8 / 12 / 20 | All | Words: A2 50–100, B1 120–180, B2 200–300. Write → AI feedback → rewrite (R11). |
| `write.quick` | Fluency | 5 / 5 / 10 | B1.1+ | Timed free-write on an easy topic; no correction, just volume |
| `tandem.text` | Output | 5 / 10 / 15 | All | Message with a prompt. Corrections from the partner can be logged into the mistake deck. |
| `tandem.voice` | Output | 8 / 10 / 15 | From voice stage | Planned: 3 min bullet points → 1–2 min recording (R6) |
| `tandem.call` | Output | 15 / 20 / 30 | From call stage | Includes a 3-question prep card |
| `fluency.432` | Fluency | 10 / 10 / 12 | From voice stage | Same story in 4 → 3 → 2 minutes, recorded in-app (R8) |
| `review.mistakes` | Language | 3 / 5 / 10 | All | Only when cards are due (FSRS scheduling) |
| `mission.travel` | Output | 3 / 3 / 3 | All, Travel mode | Real-world task, e.g. "Ask for a recommendation at the hostel and log two phrases you heard." |

If a source is disabled, its tasks are never planned. Its strand's minutes go to the other tasks in the same strand.

## 2.4 Speaking stages (Tandem)

Staged to reduce anxiety and add planning time (R5, R6):

| Stage | Unlocks when | Tasks |
|---|---|---|
| 1. Text | Start | `tandem.text` |
| 2. Planned voice notes | listening hours ≥ 250 **and** ≥ 8 text exchanges logged over ≥ 3 weeks **and** the learner rates text chats as "comfortable" | adds `tandem.voice`, `fluency.432` |
| 3. Live calls | listening hours ≥ 400 **and** ≥ 6 voice notes logged | adds `tandem.call` |

The learner can always unlock a stage early, or switch one off: Settings → Speaking has toggles, "I'm ready for voice notes" and "I'm ready for live calls". Switching one off also stops Rumbo unlocking it (and the stages after it) by itself, until it's switched back on (`speakingStageCap` on the profile). Autonomy matters more than the gate.

## 2.5 Daily planner

### Inputs
Band, today's budget `B` (10 / 15 / 20 / 30 / 45 / 60 min, plus 90 / 120 on a lesson day, chosen at the start of the day), today's lesson if any, the last 6 days of logged minutes per strand, source states, speaking stage, Travel/offline mode, weekly anchors still due, and the number of due mistake cards.

Settings that shape the plan (travel mode, Always include Duolingo, lessons, speaking stage) re-plan today at the same budget as soon as they change, unless a task has already been started (`AppModel.replanTodayIfNotStarted`).

### Algorithm
Implemented in `RumboCore/DayPlanner.swift`.

0. **Lesson.** On a lesson day (Settings → Lessons: chosen weekdays, a usual length and type, and each day's own length and type when more than one day is chosen; `LessonSchedule`), the lesson is always planned, at that day's length, as `lesson.output` (speaking & writing), `lesson.input` (listening), `lesson.study` (grammar & vocab) or `lesson.mixed` (**All-in-one**). An all-in-one lesson counts a third of its minutes toward each of speaking & writing, listening and grammar & vocab in the day's mix, and is logged as three logs, split evenly (`LessonType.split`: 60 → 20 + 20 + 20, 50 → 17 + 17 + 16). It's **inside** the budget: it uses up part of `B`, and its minutes count in that strand's deficit, so the rest of the day leans to other strands. It doesn't take one of the 4 cards, never gets leftover minutes, and is never offered in Keep going. If it takes the whole budget, the plan is the lesson (plus Duolingo when that's always included). Lessons don't count toward the weekly Tandem or writing anchors.
1. **Warm-up.** Every day the band uses Duolingo and Settings → Habit → **Always include Duolingo** is on (the default; "If you're keeping a streak going"), plan `duo.lesson` first: one lesson, 3 min (it keeps the learner's Duolingo streak; never more than 5). With it off, nothing reserves room for Duolingo: it's just one of the study options. If `B ≥ 20` and ≥ 5 cards are due, plan `review.mistakes` (3 min, or 5 from 30 min).
1b. **Travel mission.** In travel mode, a real-world mission (`mission.travel`, a fixed 3 min: it's one short real-world exchange, and leftover minutes never stretch it) is always planned right after the warm-up, online or offline, on every budget including 10-minute days. Before, it was only the first choice for a speaking & writing card, so whether it appeared depended on which strand got a card.
2. **Deficits.** For each strand: `target = share × (logged last 6 days + B)`, then `deficit = target − logged last 6 days − planned today`.
3. **Fill with new cards.** While there are fewer than 4 cards:
   - Pick the strand with the largest deficit.
   - Within that strand, take the first task not already planned, in this order: a **weekly anchor** that's due (see below), then the next **progression** task (next Language Transfer track, next Extra part), then the defaults.
   - Allocate `clamp(round5(deficit), min, max)`, but never more than what's left. If nothing in the strand fits, move to the next strand.
4. **Leftover.** Minutes too few for a new card go to existing cards that have headroom: input first, then the strand with the largest deficit.
5. **Limits.** At most 4 cards per day (to keep cognitive load low) **[design]**, and at most **one weekly anchor per day (two from 45 min)**, so a fresh week spreads its anchors out instead of crowding out progression **[design]**.
6. **Order.** Warm-up → lesson → mistake review → language-focused → input → output → fluency (R4, R7 **[design]**). The output card's prompt reuses that day's Language Transfer track or Extra episode (R4).
7. **Tiny days.** If `B = 10`: the 3-minute Duolingo lesson (when the band uses it), then one task for the other 7 minutes: the strand with the largest deficit, using its first task that fits, preferring one that fills the time. Once calls are unlocked, the week's call comes before writing in the output queue, so it isn't squeezed out by shorter tasks.
8. **Keep going.** Once every planned card is done or skipped (with at least one done), Today offers every other eligible task not already in the plan, at its standard length and with its progression detail (next track, next Extra part). They're ordered by strand deficit over the last 7 days *including today*, so the most-behind strand comes first. An extra is added to the day as its own card when started; it counts like any other practice (minutes, strand balance, streak, training hours, course progress) but never changes whether the day is complete. (`DayPlanner.extraTasks`)

**Goal advice with lessons** (`BudgetAdvisor`): the minutes still needed this week are shared evenly over the days left (today included), except that a lesson day can't be less than its lesson. Rumbo finds the even level `x` with Σ max(x, lesson that day) = minutes still needed (`BudgetAdvisor.level`): big lessons lower what the other days need, and a lesson shorter than `x` is just part of that day's `x`. If the lessons alone cover what's left, `x` is 0. Today needs `max(x, today's lesson)`, rounded up to a time chip. Example: a 150-minute goal on a Monday with lessons Tuesday (60) and Thursday (45) gives about 9 min on each of the other five days; on Tuesday the advice is the 60-minute lesson.

### Weekly anchors
Planned on the first day the budget allows, so they don't depend on a fixed weekday (which wouldn't survive backpacking).

| Anchor | A2 | B1 | B2 |
|---|---|---|---|
| `write.guided` | 1×/week | 2×/week | 2–3×/week |
| Extra en Español | 1 intensive part/week, on a day with 20+ min (an episode a fortnight) | 1 episode/week, on a day with 20+ min | — |
| Tandem exchange (any stage) | 2×/week | 3×/week | 3×/week |
| `fluency.432` | — | 1×/week once unlocked | 1×/week |
| `tandem.call` | — | 1×/week once calls are unlocked | 1×/week once calls are unlocked |

Dreaming Spanish is the main input source; Extra is a weekly change of pace (it's a weekly anchor, but only on days with at least 20 minutes, so short days stay with Dreaming Spanish). Duolingo is only ever a 5-minute warm-up: leftover minutes never go to it, and a 10-minute day picks a task that fills the whole time.

### Example: A2.1, first day, Language Transfer track 13 next, Extra episode 2 next

Real planner output (no history yet, so every anchor is due; * = weekly anchor):

| Budget | Plan |
|---|---|
| 10 min | Duolingo 3 → Dreaming Spanish 7 |
| 15 min | Duolingo 3 → Dreaming Spanish 12 |
| 20 min | Duolingo 3 → Extra ep. 2 part 1* (12) → Tandem text 5 |
| 30 min | Duolingo 5 → LT track 13 (10) → Extra ep. 2 part 1* (15) |
| 45 min | Duolingo 3 → LT track 13 (10) → Extra ep. 2 part 1* (15) → Dreaming Spanish 17 |
| 60 min | Duolingo 3 → LT track 13 (10) → Extra ep. 2 part 1* (15) → Dreaming Spanish 32 |

Over an irregular fortnight (15/45/20/30/10/45/30, twice) at A2.1 the planner gives 55% input, 14% output, 23% language-focused and 9% fluency, with Duolingo every day, Language Transfer on 4 days, Dreaming Spanish on 11, Extra on 2, guided writing twice and Tandem on 4 days. These are checked by tests at A2.1, B1.1 and B2.2 (within 5 points of every target).

## 2.6 Keeping input comprehensible

After every Dreaming Spanish session (`ds.watch`) the learner rates comprehension in one tap (R3). It isn't asked for easy videos (they should feel easy) or Extra, since nothing uses it there:

| Rating | Meaning |
|---|---|
| 😵 Lost | Understood less than ~70% |
| 🙂 Mostly | Understood ~80–90% |
| 😎 Easy | Understood more than ~95% |

Over the last 5 ratings at the current difficulty: 3 or more "Easy" → suggest raising the Dreaming Spanish difficulty range by 5. Ranges are always 5 points wide (e.g. 40–45); moving one by hand in Settings slides it by 1. Two or more "Lost" → suggest lowering it by 5. The range is shown on the `ds.watch` card ("Look for videos rated 40–48").

## 2.7 Travel mode

- **Offline preference.** Tasks are marked offline-capable or not. Offline: downloaded Language Transfer tracks, Dreaming Spanish downloads (where the user's DS subscription allows), writing with on-device AI feedback. Online-only: LanguageTool, Extra on YouTube (unless downloaded with YouTube Premium).
- **Missions.** `mission.travel` becomes the preferred output task.
- **Log other.** Logging for practice outside the plan, in any strand: Listening (a bus podcast, a tour in Spanish; logged as `content.watch`, so it also counts toward listening hours), Grammar & vocab (`other.study`: a grammar book, a class, another app), Speaking & writing (`other.output`), Fluency practice (`other.fluency`) and All-in-one (split evenly across `other.output`, `content.watch` and `other.study`, like an all-in-one lesson; `LessonType.splitOther`). It counts toward training hours, the weekly goal, the streak and strand balance. The `other.*` kinds are never planned and don't count toward weekly anchors (writing, Tandem).

## 2.8 Streaks, hours and goals

| Mechanic | Rule |
|---|---|
| Weekly goal | Main metric, set on the goal page in onboarding and Settings (default 150 min/week, 10-minute steps from 30 to 900), linked to the target date (§2.9). Shown as a ring. |
| Streak | A day counts if anything is logged: a partial day (even one Duolingo lesson) keeps the streak (R12) |
| Streak freeze | Everyone starts with 1. A 7-day streak earns the first, then every two weeks after that (when it reaches 7, 21, 35, 49… days) earns 1; frozen days keep the streak but don't add to it, and a broken streak starts the count again. Hold at most 3; a reward that comes while full is skipped. Used automatically on a missed day, only when there's a streak to save |
| Training hours | The running total shown in the header (clock badge) instead of XP: every minute logged, plus listening from before Rumbo ÷ 0.55. It's the same number levels are measured in, so it always means something. |

## 2.9 Projection

Weekly training hours = rolling average of everything logged over the last 4 weeks. For a newer learner the average covers only the days since their first log (at least 7), so one short first session isn't read as a month-long pace. Until there's a week of history, the forecast assumes the learner meets their weekly goal (every goal minute counts). Rumbo projects a date for each remaining band threshold and shows it against the learner's target date ("At this pace you'll reach B1.2 by March 2028. +10 min/day → December 2027").

Example (the author, at the time of writing): 154 h. At ~18 min/day of input → ~110 h/year → about 400–450 h by mid-2028 (B1). Logging an extra 30 min/day of outside listening → about 650 h (B2.1).


**Weekly goal ↔ target date** (`GoalPace`). Both assume the weekly goal is met, so training hours a week = weekly minutes ÷ 60. The arrival date for the goal level (B1 → 550 h, B2 → 1,090 h, C1 → B2.2's 1,450 h) is `today + (threshold − current hours) ÷ weekly hours`. The other way, the weekly goal for a date is `(threshold − current hours) ÷ weeks left × 60`, rounded up to 10 minutes and kept within 30–900. When levels moved to training hours, existing target dates were kept and the weekly goal recalculated once. Changing either one on the goal page updates the other.