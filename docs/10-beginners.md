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
| A1.1 | 45% | 0% | 55% | 0% |
| A1.2 | 55% | 10% | 35% | 0% |
| A2.1 (for comparison) | 55% | 13% | 24% | 8% |

- **A1.1 studies more than it listens (45% listening, 55% grammar & vocab).** At zero, even the easiest videos lean on pictures and gestures; a few hundred common words and the basic patterns (Language Transfer, Duolingo) make every minute of listening worth more. Not further than 55%: listening from day one still works and is the engine for everything later, and there's only so much beginner course (Duolingo is capped at 15 minutes a day and one Language Transfer track is planned a day, so on 45–60-minute days study comes out nearer 35–45%). From A1.2 listening is 55%, as at every later level. A1.1 is the one level where listening isn't 55%, so a learner reaches A1.2 (90 training hours) with about 40 hours of listening rather than 50; the threshold stays at 90 because the extra study counts towards the level too.
- **The course comes first on beginner days.** From 20 minutes, the Language Transfer track goes into the plan before listening takes the rest, so it isn't squeezed out by a longer Duolingo lesson. With **Always include Duolingo** on (the default) the Duolingo lesson is in every day's plan, whatever the length; switched off, it's one of the study options.
- **Study is the biggest it ever gets.** With little that can be understood yet, the language-focused strand carries the early structure: Language Transfer from track 1, and Duolingo.
- **Duolingo is real study at A1, not only a warm-up.** Its daily lesson is 5 minutes instead of 3, and it can grow to 15 minutes when grammar & vocab time has nowhere else to go (no audio course, or the course is done). This lengthening applies only below A2.1, so plans from A2 up are unchanged to the minute (`LearnerSnapshot.minuteRange`, the beginner branch in the planner's `addCard`).
- **Speaking and writing start at A1.2.** At A1.1 there are no separate speaking or writing tasks (0%): Language Transfer and Duolingo already have the learner answering out loud and typing every day, and a writing card at zero is more likely to discourage than help. Travel missions still come if the learner turns on Travel mode. From A1.2, one short write and one message to a partner a week. Guided writing aims for 15–40 words in short sentences ("looking up a word or two is fine"), from 70 A1 prompts; partner messages come from 40 A1 prompts (say hello, ask a name, name a photo). The AI checker explains in English, as at every level below B2.
- **No fluency practice at A1.** Fluency work makes what you already know faster, and a beginner doesn't know enough yet. At 0% it gets no cards and isn't offered in Keep going or Log other; on Progress → strand balance it stays as a greyed-out row saying "Starts at A2.1" (speaking & writing at A1.1 says "Starts at A1.2"). It appears from A2.1 (8%).
- **Later tasks wait.** Extra (intensive viewing) starts at A2.1, quick writes at B1, 4-3-2 stories and voice notes with the speaking stages, as before.

## 10.3 English at A1.1

At A1.1 the app's interface words, otherwise shown in the language being learned, are in English (`Band.usesEnglishInterface`, `LanguagePack.phrases(for:)`). From A1.2 (usually a few months in, rather than the couple of years until A2.1) they're back in the language. That's "Week 3" and "Week complete!" on the path, "Today", "Done!", "Yes!" / "Not yet" in the can-do and level-up checks, "Congratulations!", "Let's go!", "Goal reached!", "7 days in a row!", day and month names on the path, the widgets and the language-switch splash. These stay in the language: **Pico's cheers** ("¡Vamos!", "Allez !"), **the greetings** ("¡Buenos días, Ana!"), **the level names** and **the daily reminder's title**.  The welcome screen ("¡Hola!", "¿Rumbo a dónde?") is Rumbo's brand and stays as it is.

The app follows the level through `ActiveLanguage.band`, set by `AppModel` on every save and language switch; widgets get it in their snapshot (`WidgetSnapshot.band`).

## 10.4 Onboarding and goals

- The progress step starts with **"I'm completely new to Spanish"**. Ticking it skips the numbers and the can-do check, places the learner at A1.1, and starts every source at the beginning (videos 0–5, Language Transfer track 1, Duolingo section 1 unit 1, Extra episode 1).
- Someone who isn't quite new answers as usual: few hours put them in A1.1 or A1.2, and the can-do check (5 statements from their level, 5 from the next) can move them up or down one.
- Goals now include **A2** ("A first milestone…"). A learner placed in A1 is offered A2 as their first goal instead of B2, which would be years away at a usual weekly goal; they can pick a higher one, and change it any time.

## 10.5 Suggested content

Both lists have at least three suggestions for A1.1 and A1.2 (`ContentCatalogTests` checks every level): children's series and songs made for learners first, then beginner podcasts. Spanish: *Plaza Sésamo*, *Pocoyó*, *Señor Wooly*, then *Peppa Pig*, *Super Easy Spanish*, *Coffee Break Spanish*. French: *Petit Ours Brun*, *Trotro*, *Alice Ayel*, then *Peppa Pig*, *Super Easy French*, *Coffee Break French*.

## 10.6 Existing learners

Nothing changes for anyone already at A2.1 or above: their level isn't recalculated and their plans are the same. A learner placed at A2.1 before this, with fewer hours than A2.1 needs, stays at A2.1 (levels never go down by themselves).

## 10.7 Judgement calls

These rest on reasoning rather than a source, and are the first things to revisit with real beginners:
- The A1 strand shares (A1.1 45% listening and 55% study; A1.2 35% study and 10% speaking & writing).
- Duolingo's longer range at A1 (5 minutes daily, up to 15).
- No weekly writing or partner anchors at A1.1.
- A2 as a beginner's suggested first goal.
- The beginner suggestions, chosen from general knowledge (well-known children's shows and learner podcasts), not yet checked level by level.
- The level names (Novato / Aprendiz, Débutant / Apprenti).
