# 3. Experience: screens, animation and the mascot

> **Beginners.** At A1.1 the app's interface words that are normally in the language being learned are in English instead, apart from Pico's cheers, the greetings, the level names and the reminder title ([10-beginners.md](10-beginners.md) §10.3).

> **Languages.** Examples below use Spanish. Everything that names a language, its sources or its words follows the language being learned (see [09-multi-language.md](09-multi-language.md)); the app's own text is English.

## 3.1 Design principles

- **One obvious next action.** Opening the app always shows what to do now.
- **Fast feedback.** Every tap gets an animation and a haptic within 100 ms.
- **Calm, not guilty.** Missed days lead to a fresh plan, not a pile of overdue tasks or a crying mascot.
- **Native feel.** SwiftUI, Liquid Glass materials, SF Symbols, Dynamic Type, VoiceOver labels on every control.

## 3.2 Visual language

Rumbo takes a light nod from the two apps it sits between, without copying either: **Duolingo's** playful, tactile game feel, and **Dreaming Spanish's** warm coral-and-navy calm. The tactile, game-like parts lean Duolingo; everything to do with watching and listening leans Dreaming.

### Palette

| Token | Hex | Role | Nod to |
|---|---|---|---|
| `coral` | `#F25C4A` | Brand primary, Input strand, primary buttons | Dreaming's coral (`#FA594B`), shifted slightly warmer |
| `ink` | `#1E2A4A` | Text, dark surfaces, dark-mode background base | Dreaming's navy (`#1F2847`) |
| `sun` | `#FFBE1A` | Streak flame, celebrations | Both apps' yellows (Dreaming `#FFB805`) |
| `lavender` | `#A98BEB` | All-in-one lessons (they span three strands) | Pastel purple, apart from the four strand colours |
| `leaf` | `#5BC236` | Success, completed nodes, Language-focused strand | Duolingo's green |
| `sky` | `#2FA6EE` | Output strand, links | Duolingo's blue |
| `lilac` | `#DEE4FF` | Soft card backgrounds, unselected chips (light mode) | Dreaming's pale periwinkle |
| `cream` | `#FFF3D6` | Highlight panels, Pico's speech bubbles | Dreaming's cream |

Strand accents: **Input = coral, Output = sky, Language-focused = leaf, Fluency = sun.**

### Elements

| Element | Choice | Nod to |
|---|---|---|
| Buttons | Chunky "3D" buttons: a solid face over a darker bottom edge (4 pt) that presses down on tap with a quick spring | Duolingo |
| Path nodes | Round, raised nodes with the same pressable bottom edge; locked nodes are flat and grey | Duolingo |
| Input cards (Dreaming, Extra, podcasts) | Rounded, ink-on-lilac or coral-on-ink cards with a thumbnail feel, calm and spacious | Dreaming |
| Level badges | Small animated badge per band, like Dreaming's animated level icons | Dreaming |
| Progress | Thick rounded progress bars with a highlight stripe | Duolingo |
| Type | SF Pro Rounded throughout (`.fontDesign(.rounded)` at the root, rounded navigation titles), heavy weights for headings and numbers | Duolingo's rounded type |
| Surfaces | Continuous-corner cards, glass tab bar (iOS 27 Liquid Glass) | iOS |
| Light/dark | Both from the start. Dark mode uses `ink` as the base, which reads as Dreaming's night-time look. | |

Brand names, logos, mascots and exact colors from either app are never used.

## 3.3 The mascot: Pico 🐦

Pico is a chubby cartoon **toucan**. *Pico* is Spanish for "beak", and toucans are an icon of Latin America, so the big gradient beak (sun yellow to coral on top, sky blue underneath) is the character. Navy body with a radial sheen, a three-tuft crest, a cream-to-amber chest with scalloped feathers and a coral sash, a feathered wing with sky-blue tips, a sky-blue eye ring around a big brown eye with highlights, a cheeky brow, blush, little blue feet. Dark outlines and gradients give it a proper cartoon look.

| Mood | When | Look and motion |
|---|---|---|
| Idle | Default | Breathes, blinks every few seconds |
| Cheering | A task is done; today's node once the day is complete | Wing up and waving, happy squint, beak open, twinkling stars; loop-de-loop on each completed task |
| Proud | Level-up gate passed | Like cheering |
| Backpacker | Travel mode on | Leather backpack, safari hat with a coral band (replaces the crest) |
| Sleepy | After 8 pm with nothing logged | Eyes closed, gentle sway, floating z's |
| Listening | Input and Language Transfer sessions | Coral headphones, bobbing music notes |

**Built in code** (`Rumbo/Pico/PicoView.swift`): a 100 × 100 `Canvas` of cubic Bézier shapes with gradient fills and round-capped outlines, animated by `TimelineView`, plus a `keyframeAnimator` hop-and-spin. The geometry matches a reference render (`docs/art/pico-preview.png`, made with `docs/art/pico-render.py`) point for point, so the design can be iterated on as an image first. Reduce Motion freezes the animation.

## 3.4 Screens

### Onboarding (first launch, about 2 minutes)

After the welcome, the first step is **"What are you learning?"**: one row per language Rumbo can teach, Spanish and French (its English name, its own name, a tick on the chosen one); a language still on the way would show greyed with "Coming soon". The steps after it follow the choice: the sources offered are the ones that language has, the progress step asks for each of those sources' numbers, the can-do questions name the language, and placement uses that language's level hours. The welcome itself doesn't name a language. Settings has a **Language** section at the top: a "Learning" picker (each language keeps its own level, plan, goal and streak). The footer says each language keeps its own level, plan, goal and streak. Choosing one that isn't set up starts its setup at the sources step: no welcome, no language question (it was just chosen) and no name question (the name carries over), and no writing-feedback step if a Gemini or GroqCloud key is already set up (keys are shared by every language), with a **Cancel** at the top that goes back to the language already being learned. Choosing one that is set up plays a short **switch splash** over the whole screen (`LanguageSwitchSplash`, about two seconds, a tap ends it): Pico swoops in onto a card showing the old language's flag, the card flips to the new flag (🇪🇸 / 🇫🇷, `LanguagePack.flag`) with a sun-yellow ring pulsing out and a success haptic, Pico does a loop-de-loop, and the new language's "let's go" ("C'est parti !", "¡Vamos!") appears with "Now learning French". The app underneath has already switched. With Reduce Motion, the new flag and words just fade in. Deleting a language when another is set up plays the same splash, except the old flag swells, blurs and vanishes in a burst of grey smoke puffs, the new flag pops in after a beat, and the line under "¡Vamos!" reads "French deleted · back to Spanish". Everywhere below, "Spanish", the source names and the Spanish words on screen are the active language's (`LanguagePack`, [09-multi-language.md](09-multi-language.md)).
The first screen also offers "Restore from a backup". Without a backup, onboarding again is the recovery path (see [04-data-model.md](04-data-model.md#43-no-sync-manual-backup)).

1. Welcome: Pico bobs in under a speech bubble introducing himself ("¡Hola! I'm Pico 👋 I'll turn the language learning you already do into one simple plan each day, and cheer you on."), then "¿Rumbo a dónde?" (Rumbo's name and welcome stay in Spanish whatever the language).
   - Then "What are you learning?" (above).
2. Name (optional).
3. Sources: "Which sources do you want to use?" Tick the ones you use already or want to start (all on by default). Tapping a source's name or icon (it has a small ⓘ) opens an info sheet (`SourceInfoSheet`): what it is and where to find it (with a link), for anyone who hasn't heard of it. The tick on the right turns it on or off. Settings → Sources works the same way: the name opens the sheet, the switch is separate. The Tandem row is named "Tandem/HelloTalk partner" and reads "I have a language exchange partner". Throughout the app, Tandem tasks and wording say "Tandem/HelloTalk" (e.g. "Tandem/HelloTalk message"), since either app works for these exchanges.
4. Progress: at the top, **"I'm completely new to Spanish"** ("Start from the very first words"). Ticking it hides the numbers below, skips the can-do check and places the learner at A1.1 with the easiest videos (0–5) and every course at its start; the placement reveal says "Starting from zero…", and the goal step suggests A2 as a first goal. Otherwise, progress per source, each on its own card (only for enabled sources; named after the language's own sources, Spanish shown here):
   - Dreaming Spanish: total hours and the difficulty you're watching, as a 5-point range ("40–45") that the stepper slides by 1
   - Language Transfer: last finished track (0–90)
   - Duolingo: section and unit
   - Extra en Español: episodes watched (0–13)
   - Not using Dreaming Spanish: estimated hours of listening in the language
5. Can-do check: 10 statements, one at a time, "¡Sí!" / "Todavía no" (French: "Oui !" / "Pas encore"). 5 come from the band the hours point to and 5 from the next band, interleaved. Placement uses the same thresholds as §2.1 scaled to 5 (≥ 4/5 of the next band → up, < 3/5 of your own → down).
6. Placement reveal: band badge with the reasoning in one line ("154 hours of listening (≈ 280 training hours) and 7 of 10 can-dos").
7. Goal: the same goal editor as Settings → Goal (below). It comes after placement so the date can be worked out from the learner's hours; the date starts where the default 150 min a week leads.
8. Better writing feedback (skippable, "Skip for now"): how to get a free Gemini API key, a field with Paste and Test (§5.3).
9. Reminder: daily reminder toggle and time (asks for notification permission), and which day the week starts on. The reminder time is the learner's study time; there's no separate "study time" setting.

### Goal (onboarding step and Settings → Goal)
Implemented in `Rumbo/Features/Goal/GoalEditor.swift`, with `GoalPace` in RumboCore (§2.9).
- **Goal level:** B1 / **B2** / C1 chips with a one-line description. C1 is measured against B2.2, the end of Rumbo's path.
- **Weekly goal:** a big number with − and + buttons, 10 minutes per tap (hold to repeat), from 30 to 900 min a week, with the daily average and how much of it is listening.
- **Target date:** "Reach B2 by …". The two are **linked**: changing the weekly goal moves the date to when that pace reaches the goal; picking a date sets the weekly goal (rounded up to 10 minutes) that gets there. A date too soon for even 900 min a week is flagged.
- **At this pace:** the same level timeline as Progress, updating as you change things.
- In Settings it's its own page, opened from the Goal row ("B2 by Jun 2034 · 150 min a week"), and saves as it changes. Profiles from before this have a target date filled in from their weekly goal.

### Tabs
**Path** (home), **Progress**, **Mistakes**, **Library**, **Settings**. Today isn't a tab: it opens from today's node, like starting a lesson in Duolingo.

### Path (home tab)
Implemented in `Rumbo/Features/Path/PathView.swift`, laid out by `PathLayout` in RumboCore.

- **One node per calendar day** since onboarding, labelled with its weekday in the language being learned and its date (Spanish: "Lun 26", "Mié 28", and "Hoy" for today, the day summary reading "Lunes 26 de octubre"; French: "Lun. 26" and "Aujourd'hui"); 7 nodes per unit, each called a week ("Semana N" or "Semaine N", with its dates; a date outside the current year includes the year, e.g. "29 Dec 2025 – 4 Jan", in the phone's language). Weeks line up with the weekly goal's week: they start on Monday, or Sunday if chosen in Settings, so the first week starts on that day before onboarding; its days before the start date show as faint dashes and can't be opened, and don't count against the week.
- **This week's banner** also has a subtle weekly-goal bar under its dates: a thin translucent line with "85 / 150 min" in small type (the same minutes as the weekly goal elsewhere).
- **Travel mode on the path:** while it's on (it stays on across days until switched off), this week's banner has a small sun-yellow "🎒 Travel mode" tag (white on a gold, finished week), and Pico carries a big backpacking pack with a rolled blue yoga mat on top (no shoulder strap; his tail is hidden behind it; preview in `docs/art/pico-backpack-preview.png`), on top of whatever mood he's in (sleepy, cheering…). Widgets show the backpacker look (pack and hat).
- **Week banners:** a week that's over says "Semana completa" with a tick, whatever happened in it. It turns gold ("¡Semana completa!" with a seal) when every day had practice or a streak freeze: green, yellow and snowflake days all count; only a missed (grey moon) day stops it. The current week can turn gold once its last day is finished. A day is judged by time against the weekly goal: green tick when its minutes reached what the goal needed that day (Today's goal advice for it, `BudgetAdvisor.minutesToday`: what was left of the weekly goal at the start of the day, spread over the days left, counting classes/tutoring; once the week's goal is met, any practice is enough), whether or not the plan was finished; yellow when it had some practice but less than that, even with the plan finished; today stays the current node until its plan is finished, then gets the same check. A day's colour is **saved once and never changes** (`PathLayout.PathHistory` on the profile, in backups): each day's need is recorded while it's today, and once the day is over its colour is stored the next time Rumbo saves, so later changes to the weekly goal or classes never recolour it. Days that ended before this existed were settled with the goal at the time of the update; missed = grey moon; missed but saved by a streak freeze = ice-blue snowflake; upcoming = locked and faded.
- **Back to today:** scrolled down past the current week, a coral rounded-square ↑ button appears in the bottom-right corner; scrolled up above it, a ↓ button. Tapping it glides back to today, even mid-flick: SwiftUI ignores a scroll-to while a flick is still coasting, so Rumbo first stops the coasting through the underlying UIKit scroll view (setting its current offset without animation), then glides back on the next frame. If that scroll view can't be found, it jumps straight to today instead. It goes away when the current week is back in view.
- **Time to goal:** small text at the end of each unit: "Time to goal (B2.1): 712 hours", the training hours still needed for the goal's level (`goalBand`) as of the unit's last day. Finished units use what was logged by their last day; today's unit and the ones ahead are projected to their last day at the forecast pace and say "about" (the same pace as "Where you're heading"). For today's unit and those ahead, a second line: "At your current pace, that's 140 more weeks" (the hours left ÷ the forecast weekly hours, rounded up); finished units don't have it. Both lines are small, light and faded, a footnote to the unit. Once the goal level's hours are reached: "Goal (B2.1) reached". Logic: `AppModel.GoalCountdown`.
- **Streak freezes on the path:** after the day the streak reached 7, 21, 35… days and earned a freeze, a snowflake row "+1 streak freeze · Earned for keeping your streak" (the streak length itself isn't celebrated; it's just the trigger). Ahead, a faded row marks the next one on the day it can be earned if practice continues every day: "Keep your streak 5 more days" (none while holding the maximum of 3).
- **Today** is the big node with Pico beside it. Unfinished: coral star, pulsing, with a "START"/"CONTINUE" bubble; tapping zooms into Today.
- **Finished today is unmistakable:** the node turns into a big green tick inside a gold ring with sparkles, the bubble says "¡HECHO!", Pico cheers, and the header shows a green "Day done" badge.
- **Keep going:** once every task in today's plan is done or skipped (at least one done), a **Keep going** section appears under the plan on Today. It lists every other task you can do that isn't in today's plan, each with its length, detail (next track, next Extra part) and strand, most-behind strand first, with a Start button. A started extra becomes a card like any other (timer, logging, undo by tapping the grey tick, which puts it back in the list; undoing a mistake review also makes the cards it reviewed due again, so it's offered again). Extras count toward minutes, streak, training hours and course progress, but don't change whether the day is complete. Future days on the path stay locked: there is no working ahead. (A day finished early in an older version still shows as done and opens in Today.) Widgets list done extras ("Extra: …") and show "¡Hecho! +2 extra".
- **The future:** locked units continue at least 4 units after today's, and as far as the last projected level-up (up to about two years). Trophy markers sit on the day each level-up is expected ("Viajero · A2.2, around February 2027"), at the forecast pace: the learner's own after a week of history, the weekly goal before that.
- **Gate node:** when the hours for the next band are reached (and no failed check in the last 14 days), a golden trophy node appears right after today. Today also shows a "Level-up check ready" banner.
- Tapping a past (or early-finished) node shows that day's plan and any other practice. The minutes line follows the day's dot: "· day complete" in green on a green day; on a yellow day it's plain and the sheet adds, in sun yellow, "Less time than needed to meet your weekly goal".
- The path ends about two years out. Level-ups projected beyond that are listed in a **"Further ahead"** card at the end, and move onto the path (as trophy markers) once they're projected within two years.
- The pulse ring is centred on the node's face and its 3D edge together.

### Level-up check
Intro → the next band's 10 can-do statements one at a time → ≥ 7 "¡Sí!" passes: confetti, proud Pico, new band badge, and the plan's strand mix changes from the next day. Otherwise "Not yet, and that's fine", and the check returns in 14 days.
- Header: level chip, "Day done" when today is finished, streak flame, streak freezes (snowflake with the number held; tapping shows "1 of 3 streak freezes") and training hours (clock badge). On narrow screens the left chips shorten ("A2.1" + "Day done", then "A2.1" + "Hoy", then just a tick) rather than squashing or pushing the path off screen.
- Tap today's node → its card **expands into the Today screen** (`matchedGeometryEffect` / zoom navigation transition).

### Today
- Budget picker at the top: chips for 10 / 15 / 20 / 30 / 45 / 60. Changing it reshuffles the cards with a spring animation.
- **Goal advice** above the chips: what's left of the weekly goal, spread over the days left this week, e.g. "To reach your 150-minute goal: about 25 min each of the 4 days left this week. **30 min** keeps you on track." The recommended chip (the smallest choice that covers it, `BudgetAdvisor` in RumboCore) has a gold ring and star. Weeks start on Monday, or Sunday if chosen in Settings → Habit → Week starts on; the weekly goal bar, freezes and this advice all follow it. Once the goal is met, it says any time is a bonus and recommends the smallest time. With classes/tutoring it counts them: "To reach your 150-minute goal: about 9 min a day for the 7 days left this week, accounting for 105 min of classes/tutoring still to come." (or "Your classes/tutoring this week cover the rest of your goal." when they do). The recommended time is never less than today's lesson. The advice stays visible while switching between times, and goes away with the chips once a task is started.
- **Today bar:** once the plan has started, a blue bar under "Today's plan" shows today's minutes against the plan's ("25 / 30 min"): plan tasks, Keep going extras and other practice logged today ("Log other") all count, skipped tasks stay in the total, and going over shows "+N extra".
- Up to 4 task cards in order. Weekly tasks (the Extra part, guided writing, Tandem exchanges) are still planned as before but aren't marked as weekly. Each card shows: source icon, task title, minutes, strand color strip, and the specific instruction ("Track 13", "Videos rated 40–45", "Episode 2, part 1: watch with Spanish subtitles").
- Swipe a card left to swap it for an alternative in the same strand. Tap "Busy day" for the minimum dose.
- **Why, where it isn't obvious.** Tasks whose point isn't clear from the name carry a one-line reason under the title, on plan cards and in Keep going. Easy Dreaming: "Below your level on purpose: easy listening makes what you know come faster."
- **Plan length:** the minutes next to "Today's plan" are the plan's real total (every planned card, skipped ones included), not the time picked, since a class plus the daily Duolingo warm-up can run past it. Once the day is complete ("Day complete! 🎉"), it shows the minutes actually logged today instead (the Today bar's total).
- **Class/Tutoring card** (lesson days; "lessons" in the engine, "Classes/Tutoring" everywhere in the app): "Class/Tutoring" with a two-people icon, coloured by its type (All-in-one lessons are pastel purple, `Palette.lavender`, since they span three areas), with its length and "Speaking & writing · counts toward today's time". Its button is **Log it**: there's no timer, and it opens straight on the log form with the minutes pre-filled from its usual length, plus "What kind of class/tutoring was it?" with the four types (pre-set from the schedule; changing it logs this lesson as that type, this time only). An all-in-one lesson is saved as three logs, one per area, which undo removes together; the card, path and Today bar show the lesson's total. Opening it doesn't count as starting the day (there's no timer), so backing out without logging leaves the plan changeable and the lesson skippable. It can be skipped (class cancelled) and undone like any card.
- **Logged time on done cards.** When the time logged differs from the plan, the card shows the planned minutes struck through, then the logged minutes ("~~15 min~~ 22 min"). Widgets list the logged minutes for done tasks.
- **Everything can be undone.** Tapping a done or skipped card's grey tick or skip icon (on the left) undoes it. Undo removes the log and writing entry and rolls back what the task moved forward (Language Transfer track, Extra episode, Duolingo position). Other practice logged today is listed under the plan ("Other practice today": its kind, e.g. "Grammar & vocab · 20 min", and time), each with Undo.
- The Duolingo card shows the learner's section and unit; logging it asks where they are now.

### Task flow
1. Tap **Start** → timer starts, Live Activity appears in the Dynamic Island, the source opens via deep link.
2. Come back to Rumbo → "Done?" sheet with the timer's minutes pre-filled and adjustable.
3. Quick rating, asked only where the answer changes something, each with small print saying what it does: comprehension after Dreaming Spanish (tunes the difficulty range), "What level did you watch?" after Dreaming Spanish (difficulty 0–100, pre-filled with the middle of the planned range; feeds the Progress chart; not asked after Easy Dreaming, which is below level on purpose), "Which track are you up to now?" after Language Transfer (defaults to the next track; set it back to repeat one), "How did it feel?" Hard / OK / Easy (left to right) after a Tandem text message (Easy or OK on the latest one is needed to unlock voice notes), and the Duolingo position after the warm-up. Easy Dreaming, Extra, voice notes and calls ask nothing beyond minutes.
4. Card flips to complete, Pico cheers, "+22 min" flies into the training-hours badge, haptic success.

### Writing
Implemented in `Rumbo/Features/Writing/GuidedWritingView.swift` (guided writing; quick writes are a plain timed editor with no correction).

1. **Write:** prompt card (with the reuse hint), editor, live word count against the band's target. "Write first, without looking things up."
2. **Check:** "Pico is reading your Spanish…" (or French…) ("A careful check can take up to a minute.") while `CorrectionService` runs (§5.3).
3. **Feedback:** one or two specific strengths, the draft with each error highlighted in place, a card per correction (wrong words struck through in coral → fix in green, one-line explanation at the learner's level), and "A native speaker might say…" with the model's natural rewrite. Shows which checker ran ("Gemini Flash-Lite" or the basic checker). When Gemini is set up but couldn't answer, a small warning above the feedback says why the basic checker was used.
4. **Rewrite:** an editor prefilled with the draft, with the corrections listed above it (R11).
5. **Compare:** before and after.
6. **I'm done** asks first ("Finish without checking?" before a check, "Finish writing?" after), then opens the log form, which says the writing is saved with the task and has a **Back** button to return to it. **Save** stores the draft, feedback and rewrite, logs the time, and turns every correction into a mistake-deck card.

Writing is never lost: the draft, rewrite and feedback are kept on the task as they're typed (closing the task screen keeps them, and coming back picks up at the same stage), and undoing a logged writing task turns its text back into the draft. While the keyboard is up, the bottom bar shows only "Hide keyboard", so "I'm done" can't be tapped by accident.

If no checker can run (offline with no on-device model), the writing is still saved and logged.

### Mistake deck
Implemented in `Rumbo/Features/Review/MistakeDeckViews.swift`; cards are `ReviewCard`s scheduled by FSRS (R7).

- **Cards from writing:** a cloze built from the learner's own sentence. The front shows the sentence with the error blanked plus "(you wrote: voy)"; the back shows the correct words and the corrected sentence, with the explanation.
- **Cards from Tandem:** after a Tandem task, "Save a correction from your partner" adds a card (what you said → the correct version, optional why). Also available with + in the deck.
- **Review:** one card at a time, "Show answer", then Again / Good / Easy. Again brings the card back in 10 minutes; Good/Easy schedule it by FSRS.
- Due cards feed the planner (`review.mistakes`: a warm-up from 5 due cards and 20 minutes; otherwise planned when grammar & vocab is behind). The card shows "N cards due".
- **The Mistakes tab** lists every card with when it's next due, reviews what's due, adds and deletes cards.
- Undoing a writing task removes its cards.

### Progress tab
- Hours ring toward the next band.
- **Strand balance:** one row per strand, named Listening, Speaking & writing, Grammar & vocab and Fluency practice, each with what counts toward it (e.g. "Easy videos, quick writes and 4-3-2 talks"). Shows the last 7 days' minutes and share, a bar for the share, and a tick at the band's target share.
- **Where you're heading:** a timeline from now (current level and hours) through each level's expected arrival, with the target as a flag in date order ("Your target: B2 · Jul 2028", what the goal needs in hours, and the hours and level the current pace reaches by then, or "on track"); the goal's level is starred; levels after the target are faded. Below it: what 10 more minutes a day would reach by the target.
- **Level you watch** (shown when the graded video library is on and has a difficulty scale, as Dreaming Spanish and Dreaming French do): the average difficulty watched, weighted by minutes, with a 14d / 1m / 3m / 6m / 1y / All picker (remembered). All starts at the first logged session (at least 14 days). Spans up to a month plot one point per day, up to a year one per week, and longer (All only) one per 30 days. Days or weeks with nothing watched are left out, not drawn as zero. Only regular Dreaming Spanish is charted: Easy Dreaming (fluency practice, below level on purpose) is left out, including older logs. Older logs without a level use the middle of their range. A line above says the change, e.g. "Level 42 → 45, up 3 over 3m" ("since you started" for All). Logic: `WatchedLevel.series` in RumboCore.
- Streak, freezes held ("1 of 3"), training hours.
- **Your sources:** one row per source the learner uses and their level includes now (hours and range, course track, Duolingo unit, Extra episode, speaking stage); a source their level leaves out (Extra before A2.1, say) isn't listed.
- **Heat map:** the last 12 calendar weeks, one square per day (weeks start on the learner's chosen day), shaded by minutes, today outlined.
- Source progress: Language Transfer track bar, Extra episodes, Duolingo section.

### Library tab
- **Watching now:** the item marked "Watch this"; `content.watch` tasks point at it.
- **For your level** and **Coming up** (the next band), each card with format, accent, band range, why, where to find it, Watch this and Open.
- Pull to refresh fetches a newer catalog (see [06](06-content-catalog.md)).

### Travel mode on Today
**Log other** (a button under the plan) opens a sheet sized to its form, with a solid background: what kind of practice (Listening / Grammar & vocab / Speaking & writing / Fluency practice / All-in-one, with examples of each; All-in-one, pastel purple, is split evenly across speaking & writing, listening and grammar & vocab as three logs with one timestamp, which "Other practice today" shows and undoes as one "All-in-one · 30 min" row), minutes (10 / 20 / 30 / 60 or the stepper), and Log it. The day summary on the path lists it as "Other: grammar & vocab" and so on.

A card at the very bottom of Today (below "Log other", since it isn't needed most days) toggles Travel mode, explaining what it does: a real-world mission joins the plan, and offline days only get offline-capable tasks. If today's plan hasn't started (nothing logged or begun), switching it re-plans today by itself at the same time; once a task has been started, the card isn't shown on Today, and the Settings switch says the change applies from tomorrow. Pico wears the backpacker look while it's on.

### Settings
Settings starts with the **Language** picker, then two groups, each with a heading in the header of its first section ("Settings for Spanish 🇪🇸" above "Sources", "Settings across all languages" above "Writing feedback"). **"Settings for Spanish 🇪🇸"** (the language being learned) holds what each language keeps for itself: sources, goal, classes/tutoring, plan balance, travel mode, progress, speaking, habit (Always include Duolingo, week start, reminders) and, last, Start over / Delete. **"Settings across all languages"** holds what's shared: a **Credits** page (CEFR levels and can-do questions adapted © Council of Europe; Nation's four strands; the named learning sources are trademarks of their owners and Rumbo isn't affiliated with or endorsed by them; Library titles belong to their owners; Gemini, GroqCloud, LanguageTool and Apple's on-device model for writing feedback), next to Diagnostics; writing feedback (AI keys), **Appearance** (a "Theme" menu: System / Light / Dark, System by default, stored on the device with `@AppStorage("appearance")` and applied with `preferredColorScheme` at the root; not in backups; widgets follow the phone), backup (one file for every language), share and Diagnostics, with the version and credit at the very bottom. In detail:

Share (send a friend the latest release, and **Report a bug or suggest something**, which opens a new email to contact@rahnstavar.com with the subject "Rumbo feedback" and the app and iOS version filled in), Goal (opens the goal page: level, weekly goal and target date, linked), sources (each row opens what the source is and where to find it; a source the learner's level leaves out shows a small note under its name, "Starts at A2.1" (Extra below A2.1, writing and an exchange partner at A1.1) or "Not planned from B2.2" (Duolingo at B2.2), from `LanguagePack.levelNote`; "Suggested shows & podcasts" has an extra "In your plan" part in its info sheet, since that is what the switch controls: `content.watch` joins the plan from B1 once Extra is finished or unused, or at any level without Dreaming Spanish; the Library is there either way), **Classes/Tutoring** (the row reads "Tue, Thu · 60 min" or "None"; opens: "Choose each day you have lessons" as weekday chips in the order of the learner's week, "Usual lesson duration" (15–180 min in 5s) and "Usual lesson type" (Speaking & writing / Listening / Grammar & vocab / All-in-one, which splits the lesson's time evenly between the other three); with more than one day chosen, an "Each day" list where any day can have its own duration and type), **Custom plan balance** (a toggle, off by default: "Rumbo splits each day … by your level". Switching it on starts the custom split from the level's, rounded to 5s, and shows a **Plan balance** row beneath it with the split at a glance, each number in its strand's colour, coral listening, green grammar & vocab, blue speaking & writing, yellow fluency. Switching it off goes back to Rumbo's split. The page has one bar showing the split in those colours with each percentage inside it, then a row per strand with its colour dot, name, what counts toward it, its percentage in its colour and a slider tinted in its colour, in steps of 5%: moving one makes the others room so the total stays 100%, with a light tick per step; it saves (and re-plans today if not started) when a slider is let go. Then **Reset to the default balance** (disabled while it matches), and "About the balance": what it does (each day's plan moves the past week toward this split; classes/tutoring, the Duolingo warm-up, mistake review and travel missions are planned as usual), the default for the learner's level ("Listening 55% · Grammar & vocab 20% · …"), and why it's recommended (the four strands research: lots of listening moves the level most; grammar early, more speaking later, a little fluency; the default follows the level while a custom one stays fixed; below about 40% listening tends to slow progress). Progress → strand balance compares against the custom split when there is one. In backups), Travel mode (adds a real-world mission every day). Changing travel mode, Always include Duolingo, the lessons or a speaking stage re-plans today automatically at the same time if no task has been started yet; otherwise it applies from the next plan, progress fixes (the Dreaming Spanish range slides by 1 and is always 5 wide; Language Transfer shows the last track finished, "finished Track 13"; Duolingo is one row titled "Duolingo" with two full steppers under it, "Section 4" and "Unit 42", so they read as one entry; Extra en Español moves one part at a time and shows the last part seen, "seen Ep 3 Part 2"), Writing feedback (the row reads "Gemini, then GroqCloud", "GroqCloud" or "Not set up"; GroqCloud is what the app calls Groq, so it isn't mistaken for Grok, and its setup says "Groq with a Q, not Grok"; opens: Default checker, Gemini Flash-Lite or GroqCloud, with a line saying the order that will be used; a Low / Medium / High thinking picker, medium by default; then a Gemini Flash-Lite section with the same key setup as onboarding and Remove Gemini key, and a GroqCloud section with its key setup and Remove GroqCloud key), Speaking ("I'm ready for voice notes" and "I'm ready for live calls" toggles; switching one off keeps it off), Habit (**Always include Duolingo**, on by default, "If you're keeping a streak going"; week start), reminders, backup (save a file / restore from a file), reset ("Start over", which starts onboarding again; with another language set up it reads "Delete French progress and switch back to Spanish", deletes only the language being learned and switches to the other. Either way it asks twice: a confirmation sheet (a blank line between its title and message gives it room), then an "Are you sure?" alert that spells out what will be lost (streak, hours logged and over how many days, level and plan history, mistake cards), says it can't be undone and urges a backup, with **Save a backup first** (opens the save dialog and deletes nothing), **Delete French for good** and **Keep it**). At the very bottom, under the version and in the same type: "Made out of necessity (and with ❤️) by Rahn", with some space below it before the tab bar.

## 3.5 Motion and haptics catalog

| Moment | Animation | Haptic |
|---|---|---|
| App open | Path scrolls to today with a soft spring; Pico flies in | — |
| Budget chip change | Cards reflow (`.spring(response: 0.35, dampingFraction: 0.8)`) | `.selection` |
| Any chunky button | Face drops 4 pt onto its bottom edge, springs back | `.impact(weight: .light)` |
| Card complete | Card flips, checkmark draws itself, hours number rolls (`.contentTransition(.numericText())`) | `.success` |
| Streak +1 | Flame grows and flickers (`PhaseAnimator`) | `.impact(weight: .light)` |
| Task logged | On Today, "+22 min" rises from below into the training-hours badge, whose clock bounces (`TimeFlyUp`); the hours number rolls up. On the path header, the clock bounces and the number rolls whenever a new whole hour is reached | Soft tap as it lands |
| Weekly minutes go up | A light sweep runs along the "This week" bar | A light tap for each 25% of the weekly goal just passed |
| Weekly goal met | Fireworks (particle `Canvas`) behind a "¡Meta cumplida!" card with Pico cheering; over any tab, once a week | `.success`, then a tap per burst |
| Streak milestone (7, 30, 100, 365 days) | The screen dims behind it (the app background at 92%), then a big flame swells and beats twice with the day count; Pico's message as a banner on Today; once per milestone | Heartbeat (heavy–medium, twice) |
| Streak freeze used | On the next visit to the path, an ice crystal forms over the flame and shatters and the freeze count drops; a banner on Today says which day it saved | Crack (rigid, then light) |
| Streak freeze earned | The snowflake in the path header bounces; a banner on Today that just says "🧊 +1 streak freeze" (once, within a week of earning it) | — |
| Week turns gold | The week banner flips over to its gold "¡Semana completa!" side and the seal stamps down; once, the first time the path shows it | Stamp (heavy + rigid) |
| Pico tapped | A random trick: a flip, a spin, a squash-and-stretch hop, or a speech bubble ("¡Vamos!", "¡Olé!"…) | Light tap |
| Gate passed | Lock shatters (particle `Canvas`), confetti, Pico spin | Custom pattern |
| Error tapped in writing | Underline expands into an explanation bubble | `.selection` |
| Pull to refresh path | Pico pulls the path down | — |

Every animation respects **Reduce Motion** (switches to fades).

## 3.6 Widgets and Live Activity

Implemented in `RumboWidgets/`. Widgets read a `WidgetSnapshot` the app writes after every change (streak, this week's minutes and goal, today's tasks, whether the day is complete, Pico's mood), shared through the Keychain's default group. A plan from yesterday never shows today. Each save also works out the next 3 days (`upcoming`) as they'll stand if nothing more is logged: the suggested plan and budget, that week's minutes (a new week starts at zero) and the streak. So just after midnight the widget switches to the new day by itself, before the app is opened. Pico turns sleepy at 8 pm on a day with nothing logged, like in the app. The timeline has an entry for each of these moments, which don't use WidgetKit's refresh budget; any change in the app republishes and reloads it. If the app isn't opened for more than 3 days, the widget falls back to an empty day. Tapping a widget opens Today (`rumbo://today`).

**Before today's time is picked**, the widgets show the **suggested plan**: the plan the gold-starred, on-track budget would give ("★ Suggested: 30 min · Keeps you on track for your weekly goal" and its tasks). Tapping it (`rumbo://plan?minutes=30`) picks that time and opens Today; if a plan already exists by then, it just opens Today.

| Surface | Content |
|---|---|
| Small widget | Pico (cheering once the day is complete), the weekly-goal ring (minutes this week ÷ weekly goal, labelled "this week"; the large widget adds "85/150 min"), streak, and "Next: …", "Suggested: 30 min, tap to start" or "¡Hecho! Day complete" |
| Medium widget | The same, plus today's tasks (or the suggested plan) with ticks, colour-coded by strand, and minutes |
| Large widget | Pico, streak, this week's minutes, level and weekly ring, then up to 7 tasks; for a suggestion, a "Tap to start this plan" button |
| Lock Screen circular | Weekly-goal gauge: "57%" with "WEEK" |
| Lock Screen rectangular | "🔥 5 · 85/150 min this week", then the next task ("Suggested: 30 min" before a plan, or "Day complete ✓") |
| Lock Screen inline | "🔥 5 · 85/150 min this week" |
| Live Activity (Lock Screen) | Task icon in its strand colour, title, elapsed time, progress bar, **Pause/Resume** and **Done** |
| Dynamic Island compact | Task icon (pause icon while paused) + elapsed time |
| Dynamic Island expanded | Title, elapsed time, progress bar, Pause/Resume and Done |
| Dynamic Island minimal | Timer (or pause) icon |

**Timer rules**
- Starting a task shows the timer; switching to the source app (e.g. Dreaming Spanish) keeps it.
- **Leaving the task screen** without logging (⌄) removes the timer; the task stays started, and "Continue" brings the timer back with the right elapsed time.
- **Pause** (in the app or on the Live Activity) freezes the timer everywhere; paused time isn't counted when logging.
- **Done** on the Live Activity opens Rumbo straight to that task's log screen.
- **Quitting the app** removes the timer. iOS doesn't always tell an app it's being quit, so Rumbo also clears leftover timers every time it starts, and a forgotten timer is marked stale 30 minutes after its planned end.

## 3.7 Notifications

Implemented in `Reminders` (`Rumbo/Services/Platform.swift`), rescheduled after every change to the reminder settings or today's practice, and whenever the app comes back to the foreground.

- **Daily reminder** at the learner's chosen time ("Pico has today's plan ready. Even 10 minutes counts."). Scheduled one by one for the next 30 days and rescheduled whenever anything changes, so each day's text can differ: on the day after a streak freeze was used it reads "🧊 Streak freeze used: Your 12-day streak is safe. A little Spanish today keeps it going." Each day's text is worked out ahead assuming nothing more is logged, and logging anything reschedules it.
- **Evening nudge** at 8 pm on days with nothing logged ("Pico's still awake 🌙 Nothing logged today yet. Even one quick lesson keeps your streak going."). Scheduled for the coming week. Once something is logged today, today's nudge becomes one about finishing the plan if it has been started but not finished ("So close 🌙 You've done 20 min today. Two tasks (about 25 min) and today's plan is finished."; tasks left are the plan's planned or started ones, skipped ones don't count), and is dropped if the plan is finished or there isn't one. Not sent if the daily reminder is itself set for 8 pm or later.
- **Cleared once you practise:** as soon as anything is logged today (or the app opens on a day with practice), Rumbo removes its reminders and nudges already sitting in Notification Centre. The test notification is left alone.
- Notifications also appear while Rumbo is open (a notification-centre delegate allows banners in the foreground).
- Settings → Habit → **Send a test notification** sends one after 5 seconds, or explains how to turn notifications on if they're off.
- No marketing-style notifications.

## 3.8 App icon

Pico (idle) on a warm sun-to-coral gradient with a soft sun disc behind his beak. Rendered from the same reference geometry as the in-app mascot: `docs/art/icon-render.py` (options compared in `docs/art/icon-options.png`).
