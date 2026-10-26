# 4. Data model and sync

## 4.1 Storage

**SwiftData**, stored on device, synced to the user's private iCloud database through CloudKit. No Rumbo server and no accounts: each user's data lives only in their own iCloud.

CloudKit sync puts constraints on SwiftData models, which all models must follow:
- Every property is optional or has a default value.
- No `@Attribute(.unique)`.
- Every relationship is optional.
- Enums are stored as `String` raw values.

## 4.2 Models

```swift
@Model final class LearnerProfile {
    var id: UUID = UUID()
    var displayName: String = ""
    var createdAt: Date = Date.now
    var goalBand: String = "B2.2"            // Band raw value
    var targetDate: Date?
    var currentBand: String = "A2.1"
    var speakingStage: Int = 1               // 1 text, 2 voice, 3 calls
    var weeklyGoalMinutes: Int = 150
    var habitCue: String = ""                // "After breakfast"
    var reminderTime: Date?
    var travelMode: Bool = false
    var enabledSources: [String] = []        // SourceKind raw values
    var dsDifficultyLow: Int = 40
    var dsDifficultyHigh: Int = 48
    var streakFreezes: Int = 0
}

@Model final class SourceProgress {
    var source: String = ""                  // SourceKind
    var baselineInputHours: Double = 0       // e.g. DS hours at onboarding
    var position: Int = 0                    // LT track, Extra episode
    var section: Int = 0                     // Duolingo section
    var unit: Int = 0                        // Duolingo unit
    var finishedAt: Date?
    var updatedAt: Date = Date.now
}

@Model final class DayPlan {
    var day: Date = Date.now                 // start of local day
    var budgetMinutes: Int = 30
    var band: String = "A2.1"
    @Relationship(deleteRule: .cascade) var tasks: [PlannedTask]? = []
}

@Model final class PlannedTask {
    var taskID: String = ""                  // "lt.track", "ds.watch", …
    var strand: String = ""
    var order: Int = 0
    var minutesPlanned: Int = 0
    var detail: String = ""                  // "Track 13", "Rated 40–48"
    var payload: Data?                       // JSON, task-specific
    var status: String = "planned"           // planned / active / done / skipped
    var plan: DayPlan?
}

@Model final class ActivityLog {
    var id: UUID = UUID()
    var date: Date = Date.now
    var taskID: String = ""
    var source: String = ""
    var strand: String = ""
    var minutes: Int = 0
    var countsAsInput: Bool = false          // adds to input hours
    var comprehension: Int?                  // 1 lost, 2 mostly, 3 easy
    var rating: String?                      // "solid" / "shaky"
    var isBonus: Bool = false                // logged outside a plan
}

@Model final class WritingEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var promptID: String = ""
    var draft: String = ""
    var feedbackJSON: Data?                  // CorrectionResult
    var rewrite: String = ""
    var engine: String = ""                  // which correction engine ran
}

@Model final class ReviewCard {
    var id: UUID = UUID()
    var front: String = ""
    var back: String = ""
    var explanation: String = ""
    var origin: String = ""                  // writing / tandem / manual
    // FSRS state
    var due: Date = Date.now
    var stability: Double = 0
    var difficulty: Double = 0
    var reps: Int = 0
    var lapses: Int = 0
    var state: Int = 0                       // new / learning / review / relearning
    var lastReview: Date?
}

@Model final class LevelCheck {
    var date: Date = Date.now
    var band: String = ""
    var answers: [Bool] = []
    var passed: Bool = false
}
```

**Derived, never stored:** total input hours (`baselineInputHours` + sum of `ActivityLog` input minutes), XP, streak, strand balance, projection. Computing them avoids sync conflicts between devices.

## 4.3 Sync and backup

There are two layers. Which ones are active depends on the entitlements the user's signing certificate keeps (see [05-architecture.md](05-architecture.md#signing-and-entitlements)).

| Layer | How | Needs |
|---|---|---|
| **1. CloudKit sync** (preferred) | SwiftData `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.rahns.rumbo"))`. Automatic, continuous, works across devices. | iCloud + CloudKit entitlement with the container ID in the provisioning profile |
| **2. Auto-backup to iCloud Drive** (always on) | During onboarding the user saves `Rumbo Backup.json` once, anywhere in Files (e.g. *iCloud Drive/Rumbo*), using the document picker in move mode. Rumbo keeps a security-scoped bookmark to that file and rewrites it after each logged session. The file holds the latest full snapshot plus the previous 7 daily snapshots. | No entitlement. Works with any signing method. (Picking a *folder* didn't work on device in M0; saving a file does.) |

At launch, Rumbo checks whether CloudKit is available (`FileManager.default.ubiquityIdentityToken` plus a CloudKit account-status check). If it is, CloudKit sync is used. If not, Rumbo uses a local-only store and Settings explains that the iCloud Drive backup is the safety net.

**Restore:** onboarding offers "Restore from backup" before anything else. On a new phone (or after reinstalling with a new certificate, which can wipe app data), the user picks `Rumbo Backup.json`, and Rumbo then keeps writing to that same file.

**Export:** Settings → Export creates the same JSON file through the share sheet (for moving to a friend's format, or archiving).
