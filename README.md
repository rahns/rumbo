# Rumbo

*¿Rumbo a dónde?* — A native iOS app that combines the language-learning sources you already use into one research-based daily plan, taking you from your very first words to B2 (comfortably conversational).

Rumbo doesn't replace your sources. It tells you **exactly what to do today, with which source, and for how long**, then tracks it with a Duolingo-style path, a mascot, streaks, widgets and a Dynamic Island timer.

**Languages:** Spanish, French.

Each language keeps its own level, plan, goal and streak; switch between them in Settings. The app itself is in English.

## Sources

Each language fills these roles with the best source it has (see [docs/09-multi-language.md](docs/09-multi-language.md)):

| Role | Source | In the plan |
|---|---|---|
| Graded video | Dreaming | Main comprehensible-input engine |
| Audio course | Language Transfer | Grammar skeleton in the early levels |
| Learner sitcom | Extra | Intensive then extensive viewing, A2 → B1 |
| Drill app | Duolingo | Short daily retrieval warm-up, fades out by B2 |
| Writing (in-app) | Rumbo | Output, with free AI correction |
| Exchange partner | Tandem/HelloTalk | Interaction: text → planned voice notes → live calls |
| Suggested content | Rumbo's Library | Native shows & podcasts once a source runs out |

Every source can be turned off. The planner reallocates its time to whatever else fills the same learning strand.

## Identity

| | |
|---|---|
| App name | Rumbo |
| Bundle ID | `com.rahns.rumbo` |
| Widget/Live Activity extension | `com.rahns.rumbo.widgets` |
| Shared data (widgets) | Keychain default access group (App Groups aren't available with a personal certificate) |
| Minimum iOS | 27.0 |

## Spec

1. [Research foundations](docs/01-research.md)
2. [Learning engine: levels, strands and the daily planner](docs/02-learning-engine.md)
3. [Screens, animation and the mascot](docs/03-experience.md)
4. [Data model and backup](docs/04-data-model.md)
5. [Architecture, AI correction, widgets, CI and install](docs/05-architecture.md)
6. [Content catalog](docs/06-content-catalog.md)
7. [Roadmap](docs/07-roadmap.md)
8. [Monetisation ideas (parked, not built)](docs/08-monetisation.md)
9. [Languages: language packs, and adding a new language](docs/09-multi-language.md)
10. [Complete beginners (A1)](docs/10-beginners.md)

## Install

The **Build** workflow (run manually from the Actions tab, or on `v*` tags) builds an **unsigned** `Rumbo.ipa` on GitHub Actions (macOS runner, Xcode 27). Download it from the latest run on the [Actions tab](../../actions) (the artifact is the IPA itself, `Rumbo-0.1.<build>.ipa`, not zipped) or from [Releases](../../releases), and sign/install it with your own certificate. The IPA is fake-signed with the app's entitlements, so signing tools that keep them carry them over.

See [docs/05-architecture.md](docs/05-architecture.md#57-signing-and-entitlements) for which features depend on the entitlements your certificate supports. The app's **Diagnostics** screen tells you what works on your phone.

## Development

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Rumbo.xcodeproj
```

Engine tests: `swift test --package-path Packages/RumboCore`.

To add a language, see [docs/09-multi-language.md](docs/09-multi-language.md): a new `LanguagePack` in RumboCore and a suggestions list, then add it to the **Languages** line above.
