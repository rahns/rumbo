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
| `sun` | `#FFBE1A` | XP, streak flame, celebrations | Both apps' yellows (Dreaming `#FFB805`) |
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
| Type | SF Pro Rounded, heavy weights for headings and numbers; SF Pro for body | Duolingo's rounded type |
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
2. Name (optional) and goal: B1 / **B2** / C1, plus an optional target date ("Moving to Latin America in 2028").
3. Sources: toggle the ones you use (all on by default). The Tandem row reads "I have a language exchange partner".
4. Progress per source, each on its own card (only for enabled sources):
   - Dreaming Spanish: total hours and the difficulty you're watching (the range is that value + 8)
   - Language Transfer: last finished track (0–90)
   - Duolingo: section and unit
   - Extra en Español: episodes watched (0–13)
   - Not using Dreaming Spanish: estimated hours of Spanish listening
5. Can-do check: 10 statements, one at a time, "¡Sí!" / "Todavía no". 5 come from the band the hours point to and 5 from the next band, interleaved. Placement uses the same thresholds as §2.1 scaled to 5 (≥ 4/5 of the next band → up, < 3/5 of your own → down).
6. Placement reveal: band badge with the reasoning in one line ("154 hours of input and 7 of 10 can-dos").
7. Habit: cue chips ("After breakfast", "On my commute", …), daily reminder toggle and time (asks for notification permission), weekly goal (60/100/150/210/300 min).

### Tabs
**Path** (home), **Progress**, **Settings**. Today isn't a tab: it opens from today's node, like starting a lesson in Duolingo.

### Path (home tab)
Implemented in `Rumbo/Features/Path/PathView.swift`, laid out by `PathLayout` in RumboCore.

- **One node per calendar day** since onboarding, labelled with its weekday and date; 7 nodes per unit ("Unidad N", with its dates). Day complete (its plan finished, or ≥ 10 minutes logged with no plan) = green tick; partly done = yellow; missed = grey moon; upcoming = locked and faded.
- **Today** is the big node with Pico beside it. Unfinished: coral star, pulsing, with a "START"/"CONTINUE" bubble; tapping zooms into Today.
- **Finished today is unmistakable:** the node turns into a big green tick inside a gold ring with sparkles, the bubble says "¡HECHO!", Pico cheers, and the header shows a green "Day done" badge.
- **Working ahead:** finishing today opens tomorrow (blue, pulsing, "KEEP GOING"). Tapping it, or "Keep going: do tomorrow now" on Today, plans tomorrow's session now. It's planned for that day, so everything done so far counts toward the balance, and finishing it marks tomorrow's node complete in advance and opens the day after.
- **The future:** locked units continue at least 4 units after today's, and as far as the last projected level-up (up to about two years). Trophy markers sit on the day each level-up is expected ("Viajero · A2.2, around February 2027"), at the forecast pace: the learner's own after a week of history, the weekly goal before that.
- **Gate node:** when the hours for the next band are reached (and no failed check in the last 14 days), a golden trophy node appears right after today. Today also shows a "Level-up check ready" banner.
- Tapping a past (or early-finished) node shows that day's plan and any other practice.
- The path ends about two years out. Level-ups projected beyond that are listed in a **"Further ahead"** card at the end, and move onto the path (as trophy markers) once they're projected within two years.
- The pulse ring is centred on the node's face and its 3D edge together.

### Level-up check
Intro → the next band's 10 can-do statements one at a time → ≥ 7 "¡Sí!" passes: confetti, proud Pico, new band badge, and the plan's strand mix changes from the next day. Otherwise "Not yet, and that's fine", and the check returns in 14 days.
- Header: streak flame, weekly goal ring, XP.
- Tap today's node → its card **expands into the Today screen** (`matchedGeometryEffect` / zoom navigation transition).

### Today
- Budget picker at the top: chips for 10 / 15 / 20 / 30 / 45 / 60. Changing it reshuffles the cards with a spring animation.
- **Goal advice** above the chips: what's left of the weekly goal, spread over the days left this week, e.g. "To reach your 150-minute goal: about 25 min each of the 4 days left this week. **30 min** keeps you on track." The recommended chip (the smallest choice that covers it, `BudgetAdvisor` in RumboCore) has a gold ring and star. Weeks start on Monday, or Sunday if chosen in Settings → Habit → Week starts on; the weekly goal bar, freezes and this advice all follow it. Once the goal is met, it says any time is a bonus and recommends 10.
- Up to 4 task cards in order. Each card shows: source icon, task title, minutes, strand color strip, and the specific instruction ("Track 13", "Rated 40–48", "Episode 2, part 1: watch with Spanish subtitles").
- Swipe a card left to swap it for an alternative in the same strand. Tap "Busy day" for the minimum dose.
- **Everything can be undone.** Tapping a done or skipped card's grey tick or skip icon (on the left) undoes it. Undo removes the log and writing entry and rolls back what the task moved forward (Language Transfer track, Extra episode, Duolingo position). Extra listening logged today is listed under the plan, each with Undo.
- The Duolingo card shows the learner's section and unit; logging it asks where they are now.

### Task flow
1. Tap **Start** → timer starts, Live Activity appears in the Dynamic Island, the source opens via deep link.
2. Come back to Rumbo → "Done?" sheet with the timer's minutes pre-filled and adjustable.
3. Quick rating: comprehension (input), "solid / shaky" (Language Transfer), or nothing.
4. Card flips to complete, Pico cheers, XP counts up, haptic success.

### Writing
Implemented in `Rumbo/Features/Writing/GuidedWritingView.swift` (guided writing; quick writes are a plain timed editor with no correction).

1. **Write:** prompt card (with the reuse hint), editor, live word count against the band's target. "Write first, without looking things up."
2. **Check:** "Pico is reading your Spanish…" while `CorrectionService` runs (§5.3).
3. **Feedback:** one or two specific strengths, the draft with each error highlighted in place, a card per correction (wrong words struck through in coral → fix in green, one-line explanation at the learner's level), and "A native speaker might say…" with the model's natural rewrite. Shows which checker ran.
4. **Rewrite:** an editor prefilled with the draft, with the corrections listed above it (R11).
5. **Compare:** before and after.
6. **I'm done** saves the draft, feedback and rewrite, logs the time, and turns every correction into a mistake-deck card. A rewrite earns +25 XP.

If the check can't run (offline with no on-device model), the writing is still saved and logged.

### Mistake deck
Implemented in `Rumbo/Features/Review/MistakeDeckViews.swift`; cards are `ReviewCard`s scheduled by FSRS (R7).

- **Cards from writing:** a cloze built from the learner's own sentence. The front shows the sentence with the error blanked plus "(you wrote: voy)"; the back shows the correct words and the corrected sentence, with the explanation.
- **Cards from Tandem:** after a Tandem task, "Save a correction from your partner" adds a card (what you said → the correct version, optional why). Also available with + in the deck.
- **Review:** one card at a time, "Show answer", then Again / Good / Easy. Again brings the card back in 10 minutes; Good/Easy schedule it by FSRS.
- Due cards feed the planner (`review.mistakes`: a warm-up from 5 due cards and 20 minutes; otherwise planned when language study is behind). The card shows "N cards due".
- **Progress → Mistake deck** lists every card with when it's next due, reviews what's due, adds and deletes cards.
- Undoing a writing task removes its cards.

### Progress tab
- Hours ring toward the next band.
- **Strand balance:** the last 7 days' share per strand as bars, with each band target marked.
- **Projection chart:** input hours from now to the target date (or a year out), with dashed band thresholds and the target date marked; the arrival dates and "+10 min a day" line sit under it.
- Streak, freezes, XP; mistake deck.
- **Heat map:** the last 12 calendar weeks, one square per day (weeks start on the learner's chosen day), shaded by minutes, today outlined.
- Source progress: Language Transfer track bar, Extra episodes, Duolingo section.

### Library tab
- **Heading to** chips (Anywhere, Mexico, Colombia, Argentina, Peru, Chile, Spain): that accent comes first.
- **Watching now:** the item marked "Watch this"; `content.watch` tasks point at it.
- **For your level** and **Coming up** (the next band), each card with format, accent, band range, why, where to find it, Watch this and Open.
- Pull to refresh fetches a newer catalog (see [06](06-content-catalog.md)).

### Travel mode on Today
A card under the header toggles Travel mode, explaining what it does: a real-world mission joins the plan, and offline days only get offline-capable tasks. It applies to the next plan (re-pick today's time to use it today). Pico wears the backpacker look while it's on.

### Settings
Share (send a friend the latest release, see what's new), sources, Travel mode and where you're heading, weekly goal, reminders, AI correction (engine status, optional own API key), backup (save a file / restore from a file), reset (start onboarding again).

## 3.5 Motion and haptics catalog

| Moment | Animation | Haptic |
|---|---|---|
| App open | Path scrolls to today with a soft spring; Pico flies in | — |
| Budget chip change | Cards reflow (`.spring(response: 0.35, dampingFraction: 0.8)`) | `.selection` |
| Any chunky button | Face drops 4 pt onto its bottom edge, springs back | `.impact(weight: .light)` |
| Card complete | Card flips, checkmark draws itself, XP number rolls (`.contentTransition(.numericText())`) | `.success` |
| Streak +1 | Flame grows and flickers (`PhaseAnimator`) | `.impact(weight: .light)` |
| Weekly goal met | Ring closes with a sparkle burst | `.success` |
| Gate passed | Lock shatters (particle `Canvas`), confetti, Pico spin | Custom pattern |
| Error tapped in writing | Underline expands into an explanation bubble | `.selection` |
| Pull to refresh path | Pico pulls the path down | — |

Every animation respects **Reduce Motion** (switches to fades).

## 3.6 Widgets and Live Activity

Implemented in `RumboWidgets/`. Widgets read a `WidgetSnapshot` the app writes after every change (streak, this week's minutes and goal, today's tasks, whether the day is complete, Pico's mood), shared through the Keychain's default group. A plan from yesterday never shows today; the timeline refreshes just after midnight. Tapping any widget opens Rumbo.

| Surface | Content |
|---|---|
| Small widget | Pico (cheering once the day is complete), weekly ring with %, streak, and "Next: …" or "¡Hecho! Day complete" |
| Medium widget | The same, plus today's tasks with ticks, colour-coded by strand, and minutes |
| Lock Screen circular | Weekly-goal gauge with the streak number |
| Lock Screen rectangular | "🔥 5 · 85/150 min", then the next task (or "Day complete ✓") |
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

- **Daily reminder** at the learner's chosen time, phrased around their habit cue ("After breakfast: time for Spanish with Pico. Even 10 minutes counts."). Repeats every day.
- **Evening nudge** at 8 pm on days with fewer than 10 minutes logged ("Pico's still awake 🌙"). Scheduled for the coming week and removed for today as soon as today reaches 10 minutes. Not sent if the daily reminder is itself set for 8 pm or later.
- Notifications also appear while Rumbo is open (a notification-centre delegate allows banners in the foreground).
- Settings → Habit → **Send a test notification** sends one after 5 seconds, or explains how to turn notifications on if they're off.
- No marketing-style notifications.

## 3.8 App icon

Pico (idle) on a warm sun-to-coral gradient with a soft sun disc behind his beak. Rendered from the same reference geometry as the in-app mascot: `docs/art/icon-render.py` (options compared in `docs/art/icon-options.png`).
