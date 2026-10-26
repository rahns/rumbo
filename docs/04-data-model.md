# 4. Data model

## 4.1 Storage

**SwiftData**, stored on device only. No Rumbo server and no accounts.

Models still follow CloudKit's rules, so sync could be switched on later for a build signed with an iCloud entitlement:
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

**Derived, never stored:** total input hours (`baselineInputHours` + sum of `ActivityLog` input minutes), XP, streak, strand balance, projection. Computing them keeps a single source of truth.

## 4.3 No sync or backup

Rumbo keeps everything on the phone. There is no sync and no backup file: CloudKit needs an entitlement the author's signing profile doesn't grant, and every iCloud Drive backup approach failed on device in M0.

If the app is lost (new phone, reinstall, new certificate), the learner simply onboards again. That's cheap by design:
- The numbers that matter live in the sources themselves: Dreaming Spanish hours, the Language Transfer track, the Duolingo unit and Extra episodes. Onboarding asks for exactly these, so the plan picks up where it left off.
- What's lost is Rumbo's own history: streak, XP, writing entries and the mistake deck.
- Onboarding should take about 2 minutes (see [03-experience.md](03-experience.md#onboarding-first-launch-about-2-minutes)).
