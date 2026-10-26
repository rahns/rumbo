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
9. Notifications permission.
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
Sources, budget defaults, Travel mode, weekly goal, reminders, AI correction (engine status, optional own API key), reset (start onboarding again).

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
