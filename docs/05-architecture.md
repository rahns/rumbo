# 5. Architecture

## 5.1 Stack

| Layer | Choice |
|---|---|
| Language/UI | Swift 6, SwiftUI, iOS 27 minimum |
| Persistence | SwiftData, on device only (see [04-data-model.md](04-data-model.md)) |
| AI | Gemini API with the learner's own free key; fallback: LanguageTool public API + Foundation Models on-device |
| Widgets / Live Activity | WidgetKit, ActivityKit, App Intents |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`). No `.xcodeproj` in git, so the project can be edited from any machine. |
| CI | GitHub Actions, `runs-on: xcode-27` (Apple Silicon, macOS 27, Xcode 27) |
| Third-party dependencies | None in v1 |

## 5.2 Repository layout

```
rumbo/
├─ project.yml                   # XcodeGen spec
├─ Packages/
│  └─ RumboCore/                 # Pure Swift: bands, planner, FSRS, projection, catalogs
│     ├─ Sources/RumboCore/
│     └─ Tests/RumboCoreTests/   # Planner rules from 02-learning-engine.md as tests
├─ Rumbo/                        # App target
│  ├─ App/                       # RumboApp, routing, environment
│  ├─ Models/                    # SwiftData @Model types
│  ├─ Features/
│  │  ├─ Onboarding/
│  │  ├─ Goal/                  # Goal editor (onboarding + Settings → Goal)
│  │  ├─ Path/
│  │  ├─ Today/
│  │  ├─ TaskFlow/
│  │  ├─ Writing/
│  │  ├─ Review/
│  │  ├─ Progress/
│  │  ├─ Library/
│  │  └─ Settings/
│  ├─ Pico/                      # Mascot shapes + animations
│  ├─ Services/                  # Correction, DeepLinks, Notifications, LiveActivity, Backup, ContentLibrary
│  ├─ DesignSystem/              # Colors, type, cards, haptics, motion presets
│  └─ Resources/                 # catalog/content.json (Library suggestions), assets
├─ RumboWidgets/                 # Widget + Live Activity extension
├─ Shared/                       # ActivityAttributes, App Intents, App Group store
├─ docs/
└─ .github/workflows/build.yml
```

`RumboCore` has no dependency on SwiftUI, SwiftData or Apple-only frameworks, so its tests also run on Linux.

The content catalog degrades gracefully: with no network (or a failed fetch) the Library uses the cached copy, then the bundled one.

## 5.3 AI writing correction (free, no billing)

**Main checker: Gemini, with the learner's own free API key.** The on-device Apple model was too weak (it missed tense errors and "corrected" words into themselves), so Gemini replaced it. Each learner pastes their own key, so nothing is billed and nobody shares a quota.

- **Key:** pasted in onboarding (the "Better writing feedback" step, skippable) or Settings → Writing feedback, with step-by-step instructions to create one free at Google AI Studio (`https://aistudio.google.com/apikey`, no billing needed), a Paste button and a Test button. Stored in the Keychain on this phone only, never in backups. An empty field removes it.
- **Request:** the Interactions API (`POST https://generativelanguage.googleapis.com/v1beta/interactions`, header `x-goog-api-key`) with `store: false`, a JSON schema (`response_format`) for errors, natural rewrite and strengths, and thinking level `medium` (catches more tense, agreement and naturalness errors; the learner preferred better feedback over speed). The answer is the text of the `model_output` step.
- **Models:** `gemini-3.5-flash-lite` first: short A2–B1 corrections are well within its reach, and Flash was busy almost every time in testing. If it's rate-limited (429), busy (500/502/503/504, e.g. "currently experiencing high demand") or unavailable (404), `gemini-3.8-flash`, which has its own free quota. Answers are **streamed** (`stream: true`, server-sent events, with `thinking_summaries: "auto"` so thought summaries keep arriving while the model thinks), which tells a model that's thinking apart from one that's stuck. `Gemini.StreamLimits`: the first event must arrive within 10 s, then no more than 25 s may pass between events, and 90 s in all. A stalled stream counts as busy, so the next model gets its turn straight away. `Gemini.StreamReader` takes text only from the `model_output` step, and an `error` event mid-stream is classified like an HTTP error. If streaming fails in any unexpected way (not busy, limited or stuck), that model is asked once more without streaming (50 s timeout). If every model is only busy and less than 30 s have passed, Rumbo waits 2 seconds and tries them once more. A model that was busy, too slow or out of free requests rests for 30 minutes (`Gemini.restAfterFailure`, kept across launches): it's tried last, so checks go straight to the other model instead of waiting on it, and it goes first again afterwards. The key test counts a busy or rate-limited reply as a working key (Google accepted it) and says so. Both are on the free tier (Oct 2026). Free limits are per Google project and reset at midnight Pacific.
- **Fallback with a warning:** with no key, the basic checker runs. If Gemini can't answer (both models out of free requests or busy, key refused, offline, any other error), the basic checker runs and the feedback shows a small warning above it saying why, e.g. "You've used Gemini's free limit for now, so the basic checker did this one. It's less accurate."
- **Privacy:** the setup screen says that on the free tier Google may use what's sent to improve its products.
- Request building, reply parsing and error classification are in RumboCore (`Gemini`, tested); sending is `Rumbo/Services/GeminiClient.swift`.
- **Diagnostics → Gemini:** "Trace a full check" runs a writing check exactly like a task and lists every step with timings (`GeminiTrace`, a task-local log): model order and rests, streaming or one piece, HTTP status, first event, when the answer started, thinking updates, longest silence, why a stream was abandoned, fallbacks, and which checker answered. "Test each model and method" asks Flash-Lite and Flash, streaming and in one piece, directly (4 free requests). It also shows which models are resting, with "Clear rests". The trace is included in the copied report.

**Basic checker (fallback):**
1. **LanguageTool** (`https://api.languagetool.org/v2/check`, `language=es`) when online. Free, no key, rate-limited (~20 requests/min).
2. **On-device Apple model** gets the text plus LanguageTool's matches and returns structured feedback (`@Generable`). Corrections where the "fix" equals the original are dropped. Apple's Private Cloud Compute model is not used: it crashes sideloaded builds (M0).
3. With no Apple model, LanguageTool's results are shown alone. Offline with no Apple model: the writing is saved but not checked.

The prompt asks for **at most 8 errors, most important first**, plus one or two specific strengths, so feedback stays useful and encouraging. Explanations are in English at A2–B1 and in simple Spanish from B2.1. Both checkers use the same instructions. Corrections go through `Mistakes.merge` in RumboCore: no-ops dropped, overlapping finds kept once (the model's wording wins over LanguageTool's), capped at 8. Implemented in `Rumbo/Services/Correction.swift`.

## 5.4 Deep links into sources

| Source | Opens | Fallback |
|---|---|---|
| Dreaming Spanish | App via URL scheme, if installed | `https://www.dreaming.com/spanish` |
| Language Transfer | App via URL scheme, if installed | languagetransfer.org course page |
| Extra en Español | YouTube app, episode URL from the catalog | Web URL |
| Duolingo | `duolingo://` | App Store page |
| Tandem | App via URL scheme | App Store page |

URL schemes are confirmed during implementation and listed in `LSApplicationQueriesSchemes`. If a scheme doesn't work, Rumbo opens the https link instead.

## 5.5 Timer, Live Activity and widgets

- The timer is based on timestamps: `startedAt`, plus `pausedAt` / `pausedSeconds` for pauses, so it survives the app being backgrounded or killed.
- The Live Activity's state carries an *effective* start (now − elapsed) so `Text(timerInterval:)` counts correctly after pauses, plus the paused flag and frozen elapsed time. Its stale date is the planned end + 30 minutes.
- Pause/Resume is a `LiveActivityIntent` (`Shared/TimerIntents.swift`). It runs in the app's process; the app registers the handler at launch. Done is a `rumbo://finish` link the app opens to the active task's log screen.
- Ending timers: on leaving the task screen, on logging or cancelling, on `willTerminate` (waiting up to 2 s, since the process is ending), and on every launch.
- Widgets read `WidgetSnapshot` (`Shared/WidgetSnapshot.swift`), JSON in the Keychain's default access group with the App Group as a fallback. The app rewrites it after every save, only when it changed, and reloads widget timelines.
- Pico's drawing and the palette live in `Shared/` so the widget extension can draw them (widgets use a still Pico).

## 5.6 CI: unsigned IPA

`.github/workflows/build.yml`, run manually (workflow_dispatch) when a build is wanted, and on tags `v*`:

1. `runs-on: xcode-27`
2. Install XcodeGen (Homebrew), run `xcodegen generate`.
3. `swift test` in `Packages/RumboCore`.
4. `xcodebuild archive -scheme Rumbo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`.
5. Copy `Rumbo.app` from the archive into `Payload/`, zip it as `Rumbo.ipa`.
6. Upload as a workflow artifact. On tags, also attach it to a GitHub Release.

The public repo gets free macOS runner minutes.

## 5.7 Signing and entitlements

The IPA is unsigned; the user signs it with their own certificate and provisioning profile. Entitlements in the IPA are only kept if the profile allows them, and some re-signing tools strip them. Features degrade gracefully:

| Entitlement | Used for | If missing |
|---|---|---|
| App Groups (`group.com.rahns.rumbo`) | Widgets read today's plan | Shared Keychain group `TEAMID.com.rahns.rumbo.shared` (development profiles usually grant `TEAMID.*`). If that fails too: an "Open Rumbo" placeholder. |
| None needed | Live Activity, notifications, Gemini, Foundation Models on-device, LanguageTool, Pico, everything else | — |

Every CI build is versioned `0.1.<run number>` with build number `<run number>`, so each IPA installs over the previous one.

Milestone 0 ships a test build with a **Diagnostics** screen (Settings → About → Diagnostics) that reports which entitlements and services actually work after signing. It showed that the author's profile has no iCloud or App Group entitlement, so Rumbo stores data on device only and widgets use the Keychain.

Friends get the same IPA from the Releases page and sign it with their own certificate.
