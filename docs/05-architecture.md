# 5. Architecture

## 5.1 Stack

| Layer | Choice |
|---|---|
| Language/UI | Swift 6, SwiftUI, iOS 27 minimum |
| Persistence | SwiftData + CloudKit (see [04-data-model.md](04-data-model.md)) |
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
│  ├─ Services/                  # Correction, Backup, DeepLinks, Notifications, LiveActivity
│  ├─ DesignSystem/              # Colors, type, cards, haptics, motion presets
│  └─ Resources/                 # Catalogs (JSON), prompts, can-do statements, assets
├─ RumboWidgets/                 # Widget + Live Activity extension
├─ Shared/                       # ActivityAttributes, App Intents, App Group store
├─ docs/
└─ .github/workflows/build.yml
```

`RumboCore` has no dependency on SwiftUI, SwiftData or Apple-only frameworks, so its tests also run on Linux.

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
   - **Online:** Apple's server model on Private Cloud Compute (new in iOS 27). Larger and better at subtle Spanish errors.
   - **Offline / unavailable:** the on-device model. Works on the author's iPhone 16 Pro and on any Apple Intelligence device.
3. **Fallbacks:** if no Apple model is available (older iPhone, Apple Intelligence off), LanguageTool's results are shown alone with its built-in messages. Offline with no Apple model: the writing is saved and checked automatically when back online.
4. **Optional:** a user's own Gemini (or other) key, plugged in through the Foundation Models `LanguageModel` provider protocol. Off by default.

> ⚠️ **To verify in milestone 0:** Apple describes free Private Cloud Compute access for developers in its Small Business Program. It's not yet known whether an app signed outside that program (a sideloaded IPA) can use it. If not, Rumbo uses the on-device model, which is still free and works offline.

The prompt asks for **at most 8 errors, most important first**, so feedback stays useful rather than overwhelming. Explanations are in English at A2–B1 and switch to Spanish from B2.1.

## 5.4 Deep links into sources

| Source | Opens | Fallback |
|---|---|---|
| Dreaming Spanish | App via URL scheme, if installed | `https://www.dreaming.com/spanish` |
| Language Transfer | App via URL scheme, if installed | languagetransfer.org course page |
| Extra en Español | YouTube app, episode URL from the catalog | Web URL |
| Duolingo | `duolingo://` | App Store page |
| Tandem | App via URL scheme | App Store page |

URL schemes are confirmed during implementation and listed in `LSApplicationQueriesSchemes`. If a scheme doesn't work, Rumbo opens the https link instead.

## 5.5 Timer and Live Activity

- The timer is based on timestamps (start time, accumulated pauses), so it survives the app being backgrounded or killed.
- Starting a task starts an `ActivityKit` Live Activity. Its content state holds task name, source, strand color, start date and target minutes. The countdown uses `Text(timerInterval:)`, so no push updates are needed.
- Pause and Done buttons are `LiveActivityIntent`s that update the shared timer state.
- Widgets read today's plan from a small JSON snapshot in the App Group container, written by the app whenever the plan changes, then reload timelines.

## 5.6 CI: unsigned IPA

`.github/workflows/build.yml`, on every push to `main` and on tags `v*`:

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
| iCloud / CloudKit (`iCloud.com.rahns.rumbo`) | Automatic sync | Local store + auto-backup to iCloud Drive folder (no entitlement needed) |
| App Groups (`group.com.rahns.rumbo`) | Widgets read today's plan | Shared Keychain group `TEAMID.com.rahns.rumbo.shared` (development profiles usually grant `TEAMID.*`). If that fails too: an "Open Rumbo" placeholder. |
| None needed | Live Activity, notifications, Foundation Models on-device, LanguageTool, Pico, everything else | — |

Every CI build is versioned `0.1.<run number>` with build number `<run number>`, so each IPA installs over the previous one.

Milestone 0 ships a test build with a **Diagnostics** screen (Settings → About → Diagnostics) that reports which entitlements and services actually work after signing. That decides whether CloudKit sync is real for the author's setup, before building on it.

Friends get the same IPA from the Releases page and sign it with their own certificate. Their bundle ID may change when signing; CloudKit then only works if their profile includes a matching iCloud container, so for most friends the iCloud Drive backup is the sync path.
