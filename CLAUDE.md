# Rumbo

Native iOS app (SwiftUI, iOS 27+) that turns a language learner's sources into one research-based daily plan. It teaches Spanish and French; the app's own text is English. The spec lives in `docs/` and is the source of truth; update it when behavior changes.

## Layout
- `project.yml`: XcodeGen spec. The `.xcodeproj` is generated and not committed.
- `Packages/RumboCore`: pure Swift engine (bands, planner, FSRS, projection). No UIKit/SwiftUI/SwiftData imports, so it stays testable anywhere.
- `Rumbo/`: app target. `RumboWidgets/`: widget + Live Activity extension. `Shared/`: code compiled into both.

## Building
- There is no Mac in the cloud environment. CI (`.github/workflows/build.yml`, runner `xcode-27`) is the compiler: run the workflow, then read its logs.
- RumboCore builds on Linux: if a Swift toolchain is installed (e.g. `/home/user/.toolchains/swift-6.4.1-RELEASE-ubuntu24.04/usr/bin`), run `swift test --package-path Packages/RumboCore` locally before pushing.
- **Only start a build when the user says so.** Pushing to `main` doesn't build; trigger the `Build` workflow manually (workflow_dispatch) when asked.
- CI runs `swift test` on RumboCore, then archives an unsigned IPA, fake-signs it with `ldid` using the entitlements files, and uploads just the IPA (unzipped, no entitlements files) as an artifact. Tags `v*` publish a release.

## Languages
- Each language is one `LanguagePack` (RumboCore: `.spanish`, `.french`); everything specific to a language lives in its pack: sources and their numbers, level hours, the tutor's checklist, the phrasebook. Don't name a language or one of its sources outside a pack. See `docs/09-multi-language.md`.
- Stored identifiers (`TaskKind` and `SourceKind` raw values, profile column names, backup field names) date from when Spanish was the only language. Never change them; a test pins them.
- Every stored record has a `languageCode`; new records go through `AppModel.insert`.

## Conventions
- App targets use Swift 5 language mode for now; RumboCore uses Swift 6.
- Every planner rule from `docs/02-learning-engine.md` gets a unit test in RumboCore.
- Data is on device only (no sync). Backup is manual: save a JSON file, restore by picking it (`Rumbo/Services/Backup.swift`); keep `BackupFile` in step with the models. SwiftData models still follow the CloudKit rules in `docs/04-data-model.md` (defaults on every property, no unique constraints, optional relationships).
- Features must degrade gracefully when an entitlement is missing (see `docs/05-architecture.md`).
