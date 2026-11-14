# 10. Complete beginners (A1)

Rumbo started at A2.1 (about 150 hours of listening). It now goes down to a learner's very first word, with two levels below A2.1. Everything else (the four strands, the 7-day balance, streaks, goals, the path) works as before.

## 10.1 Levels

| Band | Spanish label | French label | Starts at (training hours) | Listening milestone |
|---|---|---|---|---|
| A1.1 | Novato | Débutant | 0 | 0 (Dreaming's level 1) |
| A1.2 | Aprendiz | Apprenti | Spanish 90, French 100 | 50 (Dreaming's level 2) |
| A2.1 | Explorador | Explorateur | Spanish 270, French 310 | 150 |

A1.2's hours follow the same rule as every other level: Dreaming's listening milestone ÷ the 55% listening share, rounded to 10 (50 ÷ 0.55 ≈ 90), and French's are Spanish's plus 15%. The first level-up check (A1.1 → A1.2) opens at those hours and uses the A1.2 can-do statements.

Can-do statements for A1.1 and A1.2 (10 each) follow the CEFR's "Basic user" descriptors: greetings, names, numbers, ordering, simple questions, very slow videos with pictures (`CanDo.swift`).

## 10.2 The plan at A1

| Band | Input | Output | Language-focused | Fluency |
|---|---|---|---|---|
| A1.1 | 55% | 4% | 36% | 5% |
| A1.2 | 55% | 8% | 30% | 7% |
| A2.1 (for comparison) | 55% | 13% | 24% | 8% |

- **Listening stays at 55%.** Comprehensible input works from day one if it's easy enough (Dreaming's Superbeginner videos, children's series), and keeping one listening share means level hours stay one rule.
- **Study is the biggest it ever gets.** With little that can be understood yet, the language-focused strand carries the early structure: Language Transfer from track 1, and Duolingo.
- **Duolingo is real study at A1, not only a warm-up.** Its daily lesson is 5 minutes instead of 3, and it can grow to 15 minutes when grammar & vocab time has nowhere else to go (no audio course, or the course is done). This lengthening applies only below A2.1, so plans from A2 up are unchanged to the minute (`LearnerSnapshot.minuteRange`, the beginner branch in the planner's `addCard`).
- **Speaking and writing start small.** No weekly anchors at A1.1; at A1.2, one short write and one message to a partner a week. Guided writing aims for 15–40 words in short sentences ("looking up a word or two is fine"), from 70 A1 prompts; partner messages come from 40 A1 prompts (say hello, ask a name, name a photo). The AI checker explains in English, as at every level below B2.
- **Later tasks wait.** Extra (intensive viewing) starts at A2.1, quick writes at B1, 4-3-2 stories and voice notes with the speaking stages, as before.
- **Easy videos** for the fluency strand are the easiest window on the scale (0–5) when the learner's own range is already near the bottom.

## 10.3 Onboarding and goals

- The progress step starts with **"I'm completely new to Spanish"**. Ticking it skips the numbers and the can-do check, places the learner at A1.1, and starts every source at the beginning (videos 0–5, Language Transfer track 1, Duolingo section 1 unit 1, Extra episode 1).
- Someone who isn't quite new answers as usual: few hours put them in A1.1 or A1.2, and the can-do check (5 statements from their level, 5 from the next) can move them up or down one.
- Goals now include **A2** ("A first milestone…"). A learner placed in A1 is offered A2 as their first goal instead of B2, which would be years away at a usual weekly goal; they can pick a higher one, and change it any time.

## 10.4 Suggested content

Both lists have at least three suggestions for A1.1 and A1.2 (`ContentCatalogTests` checks every level): children's series and songs made for learners first, then beginner podcasts. Spanish: *Plaza Sésamo*, *Pocoyó*, *Señor Wooly*, then *Peppa Pig*, *Super Easy Spanish*, *Coffee Break Spanish*. French: *Petit Ours Brun*, *Trotro*, *Alice Ayel*, then *Peppa Pig*, *Super Easy French*, *Coffee Break French*.

## 10.5 Existing learners

Nothing changes for anyone already at A2.1 or above: their level isn't recalculated and their plans are the same. A learner placed at A2.1 before this, with fewer hours than A2.1 needs, stays at A2.1 (levels never go down by themselves).

## 10.6 Judgement calls

These rest on reasoning rather than a source, and are the first things to revisit with real beginners:
- The A1 strand shares (36% and 30% study).
- Duolingo's longer range at A1 (5 minutes daily, up to 15).
- No weekly writing or partner anchors at A1.1.
- A2 as a beginner's suggested first goal.
- The beginner suggestions, chosen from general knowledge (well-known children's shows and learner podcasts), not yet checked level by level.
- The level names (Novato / Aprendiz, Débutant / Apprenti).
