# 5. Architecture

## 5.1 Stack

| Layer | Choice |
|---|---|
| Language/UI | Swift 6, SwiftUI, iOS 27 minimum |
| Persistence | SwiftData, on device only (see [04-data-model.md](04-data-model.md)) |
| AI | Foundation Models framework (Apple cloud model when online, on-device otherwise) + LanguageTool public API |
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

All engines conform to one protocol and return the same structured result:

```swift
protocol CorrectionEngine {
    var id: String { get }
    func isAvailable() async -> Bool
    func correct(_ text: String, band: Band, prompt: WritingPrompt) async throws -> CorrectionResult
}

struct CorrectionResult: Codable {
    var errors: [CorrectionError]   // range, original, suggestion, category, explanation
    var naturalRewrite: String      // how a native speaker might say it
    var strengths: [String]         // 1–2 things done well
    var estimatedBand: String?
}
```

**Pipeline:**
1. **LanguageTool** (`https://api.languagetool.org/v2/check`, `language=es`) when online. Free, no key, rate-limited (~20 requests/min). Finds spelling, agreement and grammar errors reliably.
2. **Apple model** gets the text plus LanguageTool's matches and returns a `CorrectionResult` via guided generation (`@Generable`). It explains errors at the learner's band, adds errors LanguageTool can't see (wrong tense choice, unnatural phrasing), and writes the natural rewrite.
   - **On-device model** (all Apple Intelligence devices, works offline). Asked for structured output (`@Generable`), given LanguageTool's matches as hints, and told to check tense against time expressions and agreement. Corrections where the "fix" equals the original are dropped (M0 showed it producing *voy → voy*).
   - **Private Cloud Compute model: not used.** It reports itself available in a sideloaded build, but sending it a request crashes the app because it needs Apple's managed entitlement (M0 finding). If Rumbo is ever distributed through the App Store, it becomes the preferred online engine.
3. **Fallbacks:** if no Apple model is available (older iPhone, Apple Intelligence off), LanguageTool's results are shown alone with its built-in messages. Offline with no Apple model: the writing is saved and checked automatically when back online.
4. **Optional:** a user's own Gemini (or other) key, plugged in through the Foundation Models `LanguageModel` provider protocol. Off by default.

The prompt asks for **at most 8 errors, most important first**, plus one or two specific strengths, so feedback stays useful and encouraging. Explanations are in English at A2–B1 and in simple Spanish from B2.1. The model's and LanguageTool's corrections are merged in RumboCore (`Mistakes.merge`): no-ops dropped, overlapping finds kept once (the model's wording wins), capped at 8. Implemented in `Rumbo/Services/Correction.swift`.

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
| None needed | Live Activity, notifications, Foundation Models on-device, LanguageTool, Pico, everything else | — |

Every CI build is versioned `0.1.<run number>` with build number `<run number>`, so each IPA installs over the previous one.

Milestone 0 ships a test build with a **Diagnostics** screen (Settings → About → Diagnostics) that reports which entitlements and services actually work after signing. It showed that the author's profile has no iCloud or App Group entitlement, so Rumbo stores data on device only and widgets use the Keychain.

Friends get the same IPA from the Releases page and sign it with their own certificate.
