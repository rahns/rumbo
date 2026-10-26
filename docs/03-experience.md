# 3. Experience: screens, animation and the mascot

## 3.1 Design principles

- **One obvious next action.** Opening the app always shows what to do now.
- **Fast feedback.** Every tap gets an animation and a haptic within 100 ms.
- **Calm, not guilty.** Missed days lead to a fresh plan, not a pile of overdue tasks or a crying mascot.
- **Native feel.** SwiftUI, Liquid Glass materials, SF Symbols, Dynamic Type, VoiceOver labels on every control.

## 3.2 Visual language

| Element | Choice |
|---|---|
| Palette | Warm Latin American palette: terracotta (primary), jade (success), sunflower (XP/streak), deep indigo (night/dark mode). One accent per strand: Input = jade, Output = coral, Language = indigo, Fluency = sunflower. |
| Type | SF Pro Rounded for headings and numbers, SF Pro for body |
| Shapes | Large rounded cards (continuous corners), glass tab bar, chunky path nodes |
| Light/dark | Both, from the first build |

## 3.3 The mascot: Pico 🐦

Pico is a **colibrí** (hummingbird), common across Latin America. Hummingbirds are small, fast and tireless, which fits short daily sessions.

| State | When | Animation |
|---|---|---|
| Hovering | Idle on the path | Fast wing blur, gentle bob |
| Cheering | A card is completed | Loop-de-loop, sparkle trail |
| Proud | Level-up gate passed | Spins, confetti burst from wings |
| Backpacker | Travel mode on | Tiny backpack and hat |
| Sleepy | Late in the day with nothing logged | Perched, slow blink. Never sad or guilt-tripping. |
| Reading/Listening | During a timer | Headphones or a book |

**Built in code:** Pico is drawn with SwiftUI shapes and `Canvas`, animated with `KeyframeAnimator` and `PhaseAnimator`. No third-party runtime and no design tool needed; easy to add new poses. Could move to Rive later if a hand-animated version is wanted.

Pico also appears in the Live Activity and widgets as a small static pose.

## 3.4 Screens

### Onboarding (first launch, about 2 minutes)
1. Welcome: Pico flies in. "¿Rumbo a dónde?"
2. Name (optional) and goal: B1 / **B2** / C1, plus an optional target date ("Moving to Latin America in 2028").
3. Sources: toggle the ones you use (all on by default).
4. Progress per source, each on its own card:
   - Dreaming Spanish: total hours and the difficulty range you're watching
   - Language Transfer: last finished track (slider, 0–90)
   - Duolingo: section and unit
   - Extra en Español: episodes watched (0–13)
   - Not using Dreaming Spanish: estimated hours of Spanish listening
5. Can-do check: 10 statements, swipe right "Sí" / left "Todavía no".
6. Placement reveal: animated band badge, with the reasoning in one line ("154 hours + 9/10 can-dos → Explorador (A2.1)").
7. Habit cue: "When will you usually study?" Pick a cue and time (R13). Weekly goal.
8. Tandem: "Do you have a language partner?" Yes/no. No → tips for finding one.
9. Notifications and iCloud backup permission.
10. The path builds itself on screen, node by node.

### Path (home tab)
- A vertical, winding scroll of nodes. One node = one day's session; 7 nodes = one unit, with a unit banner ("Unidad 4 · Pasado vs. imperfecto").
- Past nodes are filled, today's node pulses with Pico hovering by it, and upcoming nodes are faded but show icons for anchors (✍️ writing, 📺 Extra, 🎙 4/3/2).
- **Gate nodes** are big, with a lock that shatters when passed.
- Header: streak flame, weekly goal ring, XP.
- Tap today's node → its card **expands into the Today screen** (`matchedGeometryEffect` / zoom navigation transition).

### Today
- Budget picker at the top: chips for 10 / 15 / 20 / 30 / 45 / 60. Changing it reshuffles the cards with a spring animation.
- Up to 4 task cards in order. Each card shows: source icon, task title, minutes, strand color strip, and the specific instruction ("Track 13", "Rated 40–48", "Episode 2, part 1: watch with Spanish subtitles").
- Swipe a card left to swap it for an alternative in the same strand. Tap "Busy day" for the minimum dose.

### Task flow
1. Tap **Start** → timer starts, Live Activity appears in the Dynamic Island, the source opens via deep link.
2. Come back to Rumbo → "Done?" sheet with the timer's minutes pre-filled and adjustable.
3. Quick rating: comprehension (input), "solid / shaky" (Language Transfer), or nothing.
4. Card flips to complete, Pico cheers, XP counts up, haptic success.

### Writing
- Prompt card with target words and "use today's structure" hint.
- Editor with a live word counter.
- **Check** → errors are underlined in place with severity colors. Tap one for a short explanation at your level.
- **Rewrite** step: fix with the feedback visible, then compare before/after.
- Each fixed error becomes a mistake-deck card.

### Mistake deck
- Card review in one-tap Again / Good / Easy. Cards come from writing feedback, Tandem corrections and manual "save this phrase".
- Front: your original sentence with a gap. Back: the correction plus an explanation.

### Progress tab
- Hours ring toward the next band.
- **Strand balance:** a 7-day stacked bar showing actual vs target per strand.
- **Projection chart:** hours over time with band thresholds and the target date marked.
- Source progress: Language Transfer track bar, Extra episodes, Duolingo section.
- Heat-map calendar of minutes.

### Library tab
- Your sources with their status.
- Suggested content filtered by band, with "Add to my plan".

### Settings
Sources, budget defaults, Travel mode, weekly goal, reminders, AI correction (engine status, optional own API key), backup and sync, export, reset.

## 3.5 Motion and haptics catalog

| Moment | Animation | Haptic |
|---|---|---|
| App open | Path scrolls to today with a soft spring; Pico flies in | — |
| Budget chip change | Cards reflow (`.spring(response: 0.35, dampingFraction: 0.8)`) | `.selection` |
| Card complete | Card flips, checkmark draws itself, XP number rolls (`.contentTransition(.numericText())`) | `.success` |
| Streak +1 | Flame grows and flickers (`PhaseAnimator`) | `.impact(weight: .light)` |
| Weekly goal met | Ring closes with a sparkle burst | `.success` |
| Gate passed | Lock shatters (particle `Canvas`), confetti, Pico spin | Custom pattern |
| Error tapped in writing | Underline expands into an explanation bubble | `.selection` |
| Pull to refresh path | Pico pulls the path down | — |

Every animation respects **Reduce Motion** (switches to fades).

## 3.6 Widgets and Live Activity

| Surface | Content |
|---|---|
| Small widget | Streak, weekly ring, Pico pose |
| Medium widget | Today's tasks with checkmarks; tap a task → opens it |
| Lock Screen (circular/rectangular) | Weekly ring; next task |
| Live Activity (Lock Screen) | Task name, source icon, elapsed/target time, progress bar, Pause / Done buttons (App Intents) |
| Dynamic Island compact | Source icon + countdown |
| Dynamic Island expanded | Task, progress bar, Pause / Done |
| Dynamic Island minimal | Progress ring |

The Live Activity ends when the task is logged, or after the planned time + 30 min with a "Still going?" prompt.

## 3.7 Notifications

At most one per day, at the time chosen during onboarding, using the habit cue ("After breakfast: 15 minutes with Pico?"). An evening nudge only if the streak would break and no freeze is left. No marketing-style notifications.
