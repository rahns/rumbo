# Rumbo

Native iOS app (SwiftUI, iOS 27+) that turns a learner's Spanish sources into one research-based daily plan. The spec lives in `docs/` and is the source of truth; update it when behavior changes.

## Layout
- `project.yml`: XcodeGen spec. The `.xcodeproj` is generated and not committed.
- `Packages/RumboCore`: pure Swift engine (bands, planner, FSRS, projection). No UIKit/SwiftUI/SwiftData imports, so it stays testable anywhere.
- `Rumbo/`: app target. `RumboWidgets/`: widget + Live Activity extension. `Shared/`: code compiled into both.

## Building
- There is no Mac in the cloud environment. CI (`.github/workflows/build.yml`, runner `xcode-27`) is the compiler: run the workflow, then read its logs.
- RumboCore builds on Linux: if a Swift toolchain is installed (e.g. `/home/user/.toolchains/swift-6.4.1-RELEASE-ubuntu24.04/usr/bin`), run `swift test --package-path Packages/RumboCore` locally before pushing.
- **Only start a build when the user says so.** Pushing to `main` doesn't build; trigger the `Build` workflow manually (workflow_dispatch) when asked.
- CI runs `swift test` on RumboCore, then archives an unsigned IPA, fake-signs it with `ldid` using the entitlements files, and uploads it as an artifact. Tags `v*` publish a release.

## Conventions
- App targets use Swift 5 language mode for now; RumboCore uses Swift 6.
- Every planner rule from `docs/02-learning-engine.md` gets a unit test in RumboCore.
- Data is on device only (no sync, no backup). SwiftData models still follow the CloudKit rules in `docs/04-data-model.md` (defaults on every property, no unique constraints, optional relationships).
- Features must degrade gracefully when an entitlement is missing (see `docs/05-architecture.md`).
