# 5. Architecture

## 5.1 Stack

| Layer | Choice |
|---|---|
| Language/UI | Swift 6, SwiftUI, iOS 27 minimum |
| Persistence | SwiftData, on device only (see [04-data-model.md](04-data-model.md)) |
| AI | Gemini API (free) or Claude API (paid), with the learner's own key; fallback: LanguageTool public API + Foundation Models on-device |
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

**Main checker: an AI model the learner chooses, with their own API key.** The on-device Apple model was too weak (it missed tense errors and "corrected" words into themselves), so cloud models replaced it. Settings → Writing feedback → Model (`WritingModel`, default Gemini Flash-Lite): Gemini Flash-Lite or Gemini Flash (free, Google key), or Claude Haiku 5.5, Claude Sonnet 5.5 or Claude Opus 5.5 (paid, Anthropic key; roughly 0.1¢ / 3¢ / 5¢ a check at medium thinking). Each learner uses their own key, so nobody shares a quota or a bill.

- **Keys:** one per provider (`gemini.apiKey`, `claude.apiKey` in the Keychain, `AISettings`), saved in backups. Pasted in onboarding (the "Better writing feedback" step, skippable; Gemini only, since it's free) or Settings → Writing feedback, which shows the setup for the chosen model's provider: step-by-step instructions (Google AI Studio, `https://aistudio.google.com/apikey`, no billing; or the Claude Console, `https://platform.claude.com/settings/keys`, with credit added), a Paste button and a Test button. An empty field removes that key.
- **Gemini request:** the Interactions API (`POST https://generativelanguage.googleapis.com/v1beta/interactions`, header `x-goog-api-key`) with `store: false`, a JSON schema (`response_format`) for errors, natural rewrite and strengths, and the thinking level. The answer is the text of the `model_output` step.
- **Claude request:** the Messages API (`POST https://api.anthropic.com/v1/messages`, headers `x-api-key` and `anthropic-version: 2026-10-21`), the instructions as `system`, `thinking: {type: "adaptive"}` (with `display: "summarized"` when streamed, so summaries keep arriving while it thinks), `output_config.effort` from the thinking setting, and the same schema as structured output (`output_config.format`, every object closed with `additionalProperties: false`). Opus and Sonnet also send `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`): if a safety classifier declines, the API retries on a fallback model in the same call. A `refusal` stop reason (whole reply or mid-stream) counts as a failure, so the basic checker runs. Streamed answers are text deltas from `text` content blocks only (`Claude.StreamReader`); `ping` keep-alives and thinking deltas count as signs of life. Errors: 401/403 or `authentication_error` → key refused; 429 → rate-limited; 529/5xx or `overloaded_error` → busy. Implemented in RumboCore (`Claude`, tested).
- **Thinking and streaming:** thinking is `medium` by default (Settings → Writing feedback → Thinking: Low / Medium / High; Gemini's thinking level, Claude's effort; kept in UserDefaults and saved in backups; the trace shows the level used). Gemini Flash-Lite is the default model: short A2–B1 corrections are well within its reach, and in Diagnostics it answered in about 3 s while `gemini-3.8-flash` never started (it stays selectable, marked "often busy"). Answers are **streamed** (`stream: true`, server-sent events, with `thinking_summaries: "auto"` so thought summaries keep arriving while the model thinks), which tells a model that's thinking apart from one that's stuck. `Gemini.StreamLimits`: the first event must arrive within 10 s, then no more than 25 s may pass between events, and 90 s in all. `Gemini.StreamReader` takes text only from the `model_output` step, and an `error` event mid-stream is classified like an HTTP error. If streaming fails in any unexpected way (not busy, limited or stuck), Rumbo asks once more without streaming (50 s timeout). Both providers stream the same way and share the stall rules. If the model is busy (500/502/503/504/529, e.g. "currently experiencing high demand"), Rumbo waits 2 seconds and asks once more. The key test counts a busy or rate-limited reply as a working key (the provider accepted it) and says so. Flash-Lite is on the free tier (Oct 2026). Free limits are per Google project and reset at midnight Pacific.
- **Fallback with a warning:** with no key for the chosen model's provider, the basic checker runs. If the model can't answer (limit reached, still busy after the retry, stuck, key refused, declined, offline, any other error), the basic checker runs and the feedback shows a small warning above it saying why, naming the provider, e.g. "You've used Gemini's free limit for now, so the basic checker did this one. It's less accurate." Feedback names the model that checked it ("Checked by Claude Haiku 5.5").
- **Privacy and cost:** the Gemini setup says that on the free tier Google may use what's sent to improve its products; the Claude setup says checks are billed to the learner's Anthropic account, with rough costs per model, and that a spending limit can be set in the Console.
- Request building, reply parsing and error classification are in RumboCore (`Gemini`, `Claude`, `WritingModel`, tested); sending is `Rumbo/Services/AIClient.swift`.
- **Diagnostics → Writing feedback:** uses the chosen model. "Trace a full check" runs a writing check exactly like a task and lists every step with timings (`AITrace`, a task-local log): streaming or one piece, HTTP status, first event, when the answer started, thinking updates, longest silence, why a stream was abandoned, retries and fallbacks, and which checker answered. "Test streaming and one piece" asks the chosen model both ways, directly (2 requests, billed with Claude). The trace is included in the copied report.

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
6. Upload just the IPA as a workflow artifact, not zipped (`actions/upload-artifact@v7` with `archive: false`), with no separate entitlements files. On tags, also attach the IPA to a GitHub Release.

The public repo gets free macOS runner minutes.

## 5.7 Signing and entitlements

The IPA is unsigned; the user signs it with their own certificate and provisioning profile. Entitlements in the IPA are only kept if the profile allows them, and some re-signing tools strip them. Features degrade gracefully:

| Entitlement | Used for | If missing |
|---|---|---|
| App Groups (`group.com.rahns.rumbo`) | Widgets read today's plan | Shared Keychain group `TEAMID.com.rahns.rumbo.shared` (development profiles usually grant `TEAMID.*`). If that fails too: an "Open Rumbo" placeholder. |
| None needed | Live Activity, notifications, Gemini, Claude, Foundation Models on-device, LanguageTool, Pico, everything else | — |

Every CI build is versioned `0.1.<run number>` with build number `<run number>`, so each IPA installs over the previous one.

Milestone 0 ships a test build with a **Diagnostics** screen (Settings → About → Diagnostics) that reports which entitlements and services actually work after signing. It showed that the author's profile has no iCloud or App Group entitlement, so Rumbo stores data on device only and widgets use the Keychain.

Friends get the same IPA from the Releases page and sign it with their own certificate.
