# 3. Experience: screens, animation and the mascot

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
The first screen also offers "Restore from a backup". Without a backup, onboarding again is the recovery path (see [04-data-model.md](04-data-model.md#43-no-sync-manual-backup)).

1. Welcome: Pico bobs in. "¿Rumbo a dónde?"
2. Name (optional).
3. Sources: toggle the ones you use (all on by default). The Tandem row reads "I have a language exchange partner".
4. Progress per source, each on its own card (only for enabled sources):
   - Dreaming Spanish: total hours and the difficulty you're watching, as a 5-point range ("40–45") that the stepper slides by 1
   - Language Transfer: last finished track (0–90)
   - Duolingo: section and unit
   - Extra en Español: episodes watched (0–13)
   - Not using Dreaming Spanish: estimated hours of Spanish listening
5. Can-do check: 10 statements, one at a time, "¡Sí!" / "Todavía no". 5 come from the band the hours point to and 5 from the next band, interleaved. Placement uses the same thresholds as §2.1 scaled to 5 (≥ 4/5 of the next band → up, < 3/5 of your own → down).
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

- **One node per calendar day** since onboarding, labelled with its weekday in Spanish and its date ("Lun 26", "Mié 28", and "Hoy" for today; the day summary reads "Lunes 26 de octubre"); 7 nodes per unit, each called a week ("Semana N", with its dates; a date outside the current year includes the year, e.g. "29 dic 2025 – 4 ene"). Weeks line up with the weekly goal's week: they start on Monday, or Sunday if chosen in Settings, so the first week starts on that day before onboarding; its days before the start date show as faint dashes and can't be opened, and don't count against the week.
- **Week banners:** a week that's over says "Semana completa" with a tick, whatever happened in it. It turns gold ("¡Semana completa!" with a seal) when every day had practice or a streak freeze: green, yellow and snowflake days all count; only a missed (grey moon) day stops it. The current week can turn gold once its last day is finished. Day complete (its plan finished, or ≥ 10 minutes logged with no plan) = green tick; partly done = yellow; missed = grey moon; missed but saved by a streak freeze = ice-blue snowflake; upcoming = locked and faded.
- **Back to today:** scrolled down past the current week, a round coral ↑ button appears in the bottom-right corner; scrolled up above it, a ↓ button. Tapping it scrolls back to today. It goes away when the current week is back in view.
- **Time to goal:** small text at the end of each unit: "Time to goal (B2.1): 712 hours", the training hours still needed for the goal's level (`goalBand`) as of the unit's last day. Finished units use what was logged by their last day; today's unit and the ones ahead are projected to their last day at the forecast pace and say "about" (the same pace as "Where you're heading"). For today's unit and those ahead, a second line: "At your current pace, that's 140 more weeks" (the hours left ÷ the forecast weekly hours, rounded up); finished units don't have it. Both lines are small, light and faded, a footnote to the unit. Once the goal level's hours are reached: "Goal (B2.1) reached". Logic: `AppModel.GoalCountdown`.
- **Streak freezes on the path:** after the day the streak reached 14, 28… days and earned a freeze, a snowflake row "+1 streak freeze · Earned for keeping your streak" (the streak length itself isn't celebrated; it's just the trigger). Ahead, a faded row marks the next one on the day it can be earned if practice continues every day: "Keep your streak 5 more days" (none while holding the maximum of 2).
- **Today** is the big node with Pico beside it. Unfinished: coral star, pulsing, with a "START"/"CONTINUE" bubble; tapping zooms into Today.
- **Finished today is unmistakable:** the node turns into a big green tick inside a gold ring with sparkles, the bubble says "¡HECHO!", Pico cheers, and the header shows a green "Day done" badge.
- **Keep going:** once every task in today's plan is done or skipped (at least one done), a **Keep going** section appears under the plan on Today. It lists every other task you can do that isn't in today's plan, each with its length, detail (next track, next Extra part) and strand, most-behind strand first, with a Start button. A started extra becomes a card like any other (timer, logging, undo by tapping the grey tick, which puts it back in the list; undoing a mistake review also makes the cards it reviewed due again, so it's offered again). Extras count toward minutes, streak, training hours and course progress, but don't change whether the day is complete. Future days on the path stay locked: there is no working ahead. (A day finished early in an older version still shows as done and opens in Today.) Widgets list done extras ("Extra: …") and show "¡Hecho! +2 extra".
- **The future:** locked units continue at least 4 units after today's, and as far as the last projected level-up (up to about two years). Trophy markers sit on the day each level-up is expected ("Viajero · A2.2, around February 2027"), at the forecast pace: the learner's own after a week of history, the weekly goal before that.
- **Gate node:** when the hours for the next band are reached (and no failed check in the last 14 days), a golden trophy node appears right after today. Today also shows a "Level-up check ready" banner.
- Tapping a past (or early-finished) node shows that day's plan and any other practice.
- The path ends about two years out. Level-ups projected beyond that are listed in a **"Further ahead"** card at the end, and move onto the path (as trophy markers) once they're projected within two years.
- The pulse ring is centred on the node's face and its 3D edge together.

### Level-up check
Intro → the next band's 10 can-do statements one at a time → ≥ 7 "¡Sí!" passes: confetti, proud Pico, new band badge, and the plan's strand mix changes from the next day. Otherwise "Not yet, and that's fine", and the check returns in 14 days.
- Header: level chip, "Day done" when today is finished, streak flame, streak freezes (snowflake with the number held; tapping shows "1 of 2 streak freezes") and training hours (clock badge). On narrow screens the left chips shorten ("A2.1" + "Day done", then "A2.1" + "Hoy", then just a tick) rather than squashing or pushing the path off screen.
- Tap today's node → its card **expands into the Today screen** (`matchedGeometryEffect` / zoom navigation transition).

### Today
- Budget picker at the top: chips for 10 / 15 / 20 / 30 / 45 / 60. Changing it reshuffles the cards with a spring animation.
- **Goal advice** above the chips: what's left of the weekly goal, spread over the days left this week, e.g. "To reach your 150-minute goal: about 25 min each of the 4 days left this week. **30 min** keeps you on track." The recommended chip (the smallest choice that covers it, `BudgetAdvisor` in RumboCore) has a gold ring and star. Weeks start on Monday, or Sunday if chosen in Settings → Habit → Week starts on; the weekly goal bar, freezes and this advice all follow it. Once the goal is met, it says any time is a bonus and recommends 10. The advice stays visible while switching between times, and goes away with the chips once a task is started.
- **Today bar:** once the plan has started, a blue bar under "Today's plan" shows today's minutes against the plan's ("25 / 30 min"): plan tasks, Keep going extras and extra listening logged today all count, skipped tasks stay in the total, and going over shows "+N extra".
- Up to 4 task cards in order. Weekly tasks (the Extra part, guided writing, Tandem exchanges) are still planned as before but aren't marked as weekly. Each card shows: source icon, task title, minutes, strand color strip, and the specific instruction ("Track 13", "Videos rated 40–45", "Episode 2, part 1: watch with Spanish subtitles").
- Swipe a card left to swap it for an alternative in the same strand. Tap "Busy day" for the minimum dose.
- **Why, where it isn't obvious.** Tasks whose point isn't clear from the name carry a one-line reason under the title, on plan cards and in Keep going. Easy Dreaming: "Below your level on purpose: easy listening makes what you know come faster."
- **Logged time on done cards.** When the time logged differs from the plan, the card shows the planned minutes struck through, then the logged minutes ("~~15 min~~ 22 min"). Widgets list the logged minutes for done tasks.
- **Everything can be undone.** Tapping a done or skipped card's grey tick or skip icon (on the left) undoes it. Undo removes the log and writing entry and rolls back what the task moved forward (Language Transfer track, Extra episode, Duolingo position). Extra listening logged today is listed under the plan, each with Undo.
- The Duolingo card shows the learner's section and unit; logging it asks where they are now.

### Task flow
1. Tap **Start** → timer starts, Live Activity appears in the Dynamic Island, the source opens via deep link.
2. Come back to Rumbo → "Done?" sheet with the timer's minutes pre-filled and adjustable.
3. Quick rating, asked only where the answer changes something, each with small print saying what it does: comprehension after Dreaming Spanish (tunes the difficulty range), "What level did you watch?" after Dreaming Spanish and Easy Dreaming (difficulty 0–100, pre-filled with the middle of the planned range; feeds the Progress chart), "Which track are you up to now?" after Language Transfer (defaults to the next track; set it back to repeat one), "How did it feel?" Hard / OK / Easy (left to right) after a Tandem text message (Easy or OK on the latest one is needed to unlock voice notes), and the Duolingo position after the warm-up. Extra, voice notes and calls ask nothing beyond minutes.
4. Card flips to complete, Pico cheers, "+22 min" flies into the training-hours badge, haptic success.

### Writing
Implemented in `Rumbo/Features/Writing/GuidedWritingView.swift` (guided writing; quick writes are a plain timed editor with no correction).

1. **Write:** prompt card (with the reuse hint), editor, live word count against the band's target. "Write first, without looking things up."
2. **Check:** "Pico is reading your Spanish…" ("A careful check can take up to a minute.") while `CorrectionService` runs (§5.3).
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
- Due cards feed the planner (`review.mistakes`: a warm-up from 5 due cards and 20 minutes; otherwise planned when language study is behind). The card shows "N cards due".
- **The Mistakes tab** lists every card with when it's next due, reviews what's due, adds and deletes cards.
- Undoing a writing task removes its cards.

### Progress tab
- Hours ring toward the next band.
- **Strand balance:** one row per strand, named Listening, Speaking & writing, Study and Fluency practice, each with what counts toward it (e.g. "Easy videos, quick writes and 4-3-2 talks"). Shows the last 7 days' minutes and share, a bar for the share, and a tick at the band's target share.
- **Where you're heading:** a timeline from now (current level and hours) through each level's expected arrival, with the target as a flag in date order ("Your target: B2 · Jul 2028", what the goal needs in hours, and the hours and level the current pace reaches by then, or "on track"); the goal's level is starred; levels after the target are faded. Below it: what 10 more minutes a day would reach by the target.
- **Level you watch** (shown when Dreaming Spanish is on): the average Dreaming Spanish difficulty watched, weighted by minutes, with a 14d / 1m / 3m / 6m / 1y / All picker (remembered). All starts at the first logged session (at least 14 days). Spans up to a month plot one point per day, up to a year one per week, and longer (All only) one per 30 days. Days or weeks with nothing watched are left out, not drawn as zero. Older logs without a level use the middle of their range. A line above says the change, e.g. "Level 42 → 45, up 3 over 3m" ("since you started" for All). Logic: `WatchedLevel.series` in RumboCore.
- Streak, freezes held ("1 of 2"), training hours.
- **Heat map:** the last 12 calendar weeks, one square per day (weeks start on the learner's chosen day), shaded by minutes, today outlined.
- Source progress: Language Transfer track bar, Extra episodes, Duolingo section.

### Library tab
- **Watching now:** the item marked "Watch this"; `content.watch` tasks point at it.
- **For your level** and **Coming up** (the next band), each card with format, accent, band range, why, where to find it, Watch this and Open.
- Pull to refresh fetches a newer catalog (see [06](06-content-catalog.md)).

### Travel mode on Today
A card at the very bottom of Today (below "Log extra listening", since it isn't needed most days) toggles Travel mode, explaining what it does: a real-world mission joins the plan, and offline days only get offline-capable tasks. It applies to the next plan (re-pick today's time to use it today). Pico wears the backpacker look while it's on.

### Settings
Share (send a friend the latest release, see what's new), Goal (opens the goal page: level, weekly goal and target date, linked), sources, Travel mode, progress fixes (the Dreaming Spanish range slides by 1 and is always 5 wide; Language Transfer shows the last track finished, "finished Track 13"; Duolingo shows where you are, "doing section 4", "doing unit 42"; Extra en Español moves one part at a time and shows the last part seen, "seen Ep 3 Part 2"), Writing feedback (the Gemini API key: "Connected" or "Not set up"; opens the same setup as onboarding, plus a Low / Medium / High thinking picker, medium by default, and Remove key), week start, reminders, backup (save a file / restore from a file), reset (start onboarding again).

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
| Streak milestone (7, 30, 100, 365 days) | A big flame swells and beats twice with the day count; Pico's message as a banner on Today; once per milestone | Heartbeat (heavy–medium, twice) |
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
- **Evening nudge** at 8 pm on days with nothing logged ("Pico's still awake 🌙 Nothing logged today yet. Even one quick lesson keeps your streak going."). Scheduled for the coming week and removed for today as soon as anything is logged. Not sent if the daily reminder is itself set for 8 pm or later.
- **Cleared once you practise:** as soon as anything is logged today (or the app opens on a day with practice), Rumbo removes its reminders and nudges already sitting in Notification Centre. The test notification is left alone.
- Notifications also appear while Rumbo is open (a notification-centre delegate allows banners in the foreground).
- Settings → Habit → **Send a test notification** sends one after 5 seconds, or explains how to turn notifications on if they're off.
- No marketing-style notifications.

## 3.8 App icon

Pico (idle) on a warm sun-to-coral gradient with a soft sun disc behind his beak. Rendered from the same reference geometry as the in-app mascot: `docs/art/icon-render.py` (options compared in `docs/art/icon-options.png`).
