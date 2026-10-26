# Rumbo

*¿Rumbo a dónde?* — A native iOS app that combines the Spanish sources you already use into one research-based daily plan, taking you from A2 to B2 (comfortably conversational).

Rumbo doesn't replace your sources. It tells you **exactly what to do today, with which source, and for how long**, then tracks it with a Duolingo-style path, a mascot, streaks, widgets and a Dynamic Island timer.

## Supported sources

| Source | Role in the plan |
|---|---|
| Dreaming Spanish | Main comprehensible-input engine |
| Language Transfer (Complete Spanish) | Grammar skeleton, A2 → early B1 |
| Extra en Español | Intensive then extensive viewing, A2 → B1 |
| Duolingo | Short daily retrieval warm-up, fades out by B2 |
| Writing tasks (in-app) | Output, with free AI correction |
| Tandem partner | Interaction: text → planned voice notes → live calls |
| Suggested content | Native shows & podcasts once a source runs out |

Every source can be turned off. The planner reallocates its time to whatever else fills the same learning strand.

## Identity

| | |
|---|---|
| App name | Rumbo |
| Bundle ID | `com.rahns.rumbo` |
| Widget/Live Activity extension | `com.rahns.rumbo.widgets` |
| App Group | `group.com.rahns.rumbo` |
| Minimum iOS | 27.0 |

## Spec

1. [Research foundations](docs/01-research.md)
2. [Learning engine: levels, strands and the daily planner](docs/02-learning-engine.md)
3. [Screens, animation and the mascot](docs/03-experience.md)
4. [Data model](docs/04-data-model.md)
5. [Architecture, AI correction, widgets, CI and install](docs/05-architecture.md)
6. [Content catalog](docs/06-content-catalog.md)
7. [Roadmap](docs/07-roadmap.md)

## Install

The **Build** workflow (run manually from the Actions tab, or on `v*` tags) builds an **unsigned** `Rumbo.ipa` on GitHub Actions (macOS runner, Xcode 27). Download it from the latest run on the [Actions tab](../../actions) (artifact `Rumbo-0.1.<build>`) or from [Releases](../../releases), and sign/install it with your own certificate. The artifact also contains the two `.entitlements` files in case your signing tool asks for them.

See [docs/05-architecture.md](docs/05-architecture.md#57-signing-and-entitlements) for which features depend on the entitlements your certificate supports. The app's **Diagnostics** screen tells you what works on your phone.

## Development

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Rumbo.xcodeproj
```

Engine tests: `swift test --package-path Packages/RumboCore`.
