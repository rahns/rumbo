# Rumbo

Native iOS app (SwiftUI, iOS 27+) that turns a learner's Spanish sources into one research-based daily plan. The spec lives in `docs/` and is the source of truth; update it when behavior changes.

## Layout
- `project.yml`: XcodeGen spec. The `.xcodeproj` is generated and not committed.
- `Packages/RumboCore`: pure Swift engine (bands, planner, FSRS, projection). No UIKit/SwiftUI/SwiftData imports, so it stays testable anywhere.
- `Rumbo/`: app target. `RumboWidgets/`: widget + Live Activity extension. `Shared/`: code compiled into both.

## Building
- There is no Mac in the cloud environment. CI (`.github/workflows/build.yml`, runner `xcode-27`) is the compiler: push, then read the workflow logs.
- CI runs `swift test` on RumboCore, then archives an unsigned IPA, fake-signs it with `ldid` using the entitlements files, and uploads it as an artifact. Tags `v*` publish a release.

## Conventions
- App targets use Swift 5 language mode for now; RumboCore uses Swift 6.
- Every planner rule from `docs/02-learning-engine.md` gets a unit test in RumboCore.
- SwiftData models follow the CloudKit rules in `docs/04-data-model.md` (defaults on every property, no unique constraints, optional relationships).
- Features must degrade gracefully when an entitlement is missing (see `docs/05-architecture.md`).
