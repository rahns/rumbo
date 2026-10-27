import Foundation
import RumboCore
import SwiftData

/// The learner. One per install. See docs/04-data-model.md.
@Model final class LearnerProfile {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var displayName: String = ""
    var goal: String = "B2"
    var targetDate: Date?
    var currentBandRaw: String = Band.a2_1.rawValue
    var speakingStageRaw: Int = SpeakingStage.text.rawValue
    var weeklyGoalMinutes: Int = 150
    var habitCue: String = ""
    var reminderEnabled: Bool = false
    var reminderHour: Int = 8
    var reminderMinute: Int = 0
    var travelMode: Bool = false
    var enabledSourcesRaw: [String] = SourceKind.allCases.map(\.rawValue)
    var keepDuolingoInB2: Bool = false

    /// Input hours before Rumbo (e.g. Dreaming Spanish's own counter at onboarding).
    var baselineInputHours: Double = 0
    var dsDifficultyLow: Int = 40
    var dsDifficultyHigh: Int = 45
    var languageTransferLastTrack: Int = 0
    var languageTransferRepeatPending: Bool = false
    var extraEpisodesWatched: Int = 0
    var extraPartsDoneInEpisode: Int = 0
    var duolingoSection: Int = 1
    var duolingoUnit: Int = 1

    /// Level-up gates (§2.1): passes are counted; a failed check waits 14 days.
    var gatesPassed: Int = 0
    var lastFailedGate: Date?
    /// Weeks (weekly goal, freezes, budget advice) start on Sunday instead of Monday.
    var weekStartsOnSunday: Bool = false
    /// The catalog item the learner is watching now; "Watch or listen" tasks point at it.
    var currentContentID: String = ""

    init() {}

    /// Dreaming Spanish ranges are always this wide (40–45); moving them slides the whole window.
    static let dreamingRangeWidth = 5

    /// The level the goal ("B1", "B2", "C1") is reached at. Rumbo's path ends at B2.2, so C1 maps there.
    var goalBand: Band { GoalEditor.goalBand(for: goal) }

    var band: Band {
        get { Band(rawValue: currentBandRaw) ?? .a2_1 }
        set { currentBandRaw = newValue.rawValue }
    }

    var speakingStage: SpeakingStage {
        get { SpeakingStage(rawValue: speakingStageRaw) ?? .text }
        set { speakingStageRaw = newValue.rawValue }
    }

    var enabledSources: Set<SourceKind> {
        get { Set(enabledSourcesRaw.compactMap(SourceKind.init(rawValue:))) }
        set { enabledSourcesRaw = newValue.map(\.rawValue).sorted() }
    }

    var dsDifficulty: ClosedRange<Int> {
        get { dsDifficultyLow...max(dsDifficultyLow, dsDifficultyHigh) }
        set { dsDifficultyLow = newValue.lowerBound; dsDifficultyHigh = newValue.upperBound }
    }

    var sourceProgress: SourceProgress {
        get {
            SourceProgress(
                languageTransferLastTrack: languageTransferLastTrack,
                languageTransferRepeatPending: languageTransferRepeatPending,
                extraEpisodesWatched: extraEpisodesWatched,
                extraPartsDoneInEpisode: extraPartsDoneInEpisode
            )
        }
        set {
            languageTransferLastTrack = newValue.languageTransferLastTrack
            languageTransferRepeatPending = newValue.languageTransferRepeatPending
            extraEpisodesWatched = newValue.extraEpisodesWatched
            extraPartsDoneInEpisode = newValue.extraPartsDoneInEpisode
        }
    }
}

/// One logged block of practice.
@Model final class ActivityLog {
    var id: UUID = UUID()
    var date: Date = Date.now
    var taskRaw: String = TaskKind.dsWatch.rawValue
    var minutes: Int = 0
    /// 1 lost, 2 mostly, 3 easy (input tasks only).
    var comprehension: Int?
    /// "solid" / "shaky" for Language Transfer; "easy" / "ok" / "hard" for Tandem.
    var rating: String?
    /// Logged outside the plan ("I listened to Spanish on the bus").
    var isBonus: Bool = false
    var difficultyLow: Int?
    var difficultyHigh: Int?

    init(date: Date, task: TaskKind, minutes: Int) {
        self.date = date
        self.taskRaw = task.rawValue
        self.minutes = minutes
    }

    var task: TaskKind { TaskKind(rawValue: taskRaw) ?? .dsWatch }

    var record: ActivityRecord {
        ActivityRecord(date: date, kind: task, minutes: minutes)
    }
}

/// Today's plan, saved so it stays stable while the learner works through it.
@Model final class DayPlanRecord {
    var day: Date = Date.now
    var budgetMinutes: Int = 30
    var bandRaw: String = Band.a2_1.rawValue
    @Relationship(deleteRule: .cascade, inverse: \PlannedTaskRecord.plan)
    var tasks: [PlannedTaskRecord]? = []

    init(day: Date, budgetMinutes: Int, band: Band) {
        self.day = day
        self.budgetMinutes = budgetMinutes
        self.bandRaw = band.rawValue
    }

    /// Every task, the day's plan and any "Keep going" extras, in order.
    var sortedTasks: [PlannedTaskRecord] {
        (tasks ?? []).sorted { $0.order < $1.order }
    }

    /// The tasks planned for the chosen time, without extras.
    var planTasks: [PlannedTaskRecord] { sortedTasks.filter { !$0.isExtra } }

    /// Tasks added from "Keep going" after the plan was complete.
    var extraTasks: [PlannedTaskRecord] { sortedTasks.filter(\.isExtra) }

    /// Something has been done (or is underway), so the budget is fixed.
    var hasStarted: Bool {
        planTasks.contains { $0.status == .done || $0.status == .active }
    }

    /// Every planned card is done or skipped, and at least one was done. Extras don't count.
    var isComplete: Bool {
        let tasks = planTasks
        return !tasks.isEmpty
            && tasks.allSatisfy { $0.status == .done || $0.status == .skipped }
            && tasks.contains { $0.status == .done }
    }
}

@Model final class PlannedTaskRecord {
    var taskRaw: String = TaskKind.dsWatch.rawValue
    var order: Int = 0
    var minutesPlanned: Int = 0
    var isAnchor: Bool = false
    /// Added from "Keep going" after the day's plan was complete.
    var isExtra: Bool = false
    /// Writing in progress, kept as it's typed so closing the task screen never loses it.
    var draftText: String = ""
    var draftRewrite: String = ""
    /// Encoded `CorrectionService.Result` once the draft has been checked.
    var draftFeedback: Data?
    /// Encoded `TaskDetail`, e.g. "lt:13", "extra:2:1", "ds:40:48".
    var detailRaw: String = ""
    /// The prompt shown for output tasks, fixed when the plan is made.
    var prompt: String = ""
    var statusRaw: String = TaskStatus.planned.rawValue
    var startedAt: Date?
    /// Set while the timer is paused; `pausedSeconds` is the total of earlier pauses.
    var pausedAt: Date?
    var pausedSeconds: Double = 0
    var plan: DayPlanRecord?

    // Set when the task is completed, so the completion can be undone.
    var logID: UUID?
    var writingID: UUID?
    var progressBefore: Data?
    var duolingoSectionBefore: Int?
    var duolingoUnitBefore: Int?

    init(task: PlannedTask, order: Int, prompt: String) {
        self.taskRaw = task.kind.rawValue
        self.order = order
        self.minutesPlanned = task.minutes
        self.isAnchor = task.isAnchor
        self.detailRaw = TaskDetailCoding.encode(task.detail)
        self.prompt = prompt
    }

    var task: TaskKind { TaskKind(rawValue: taskRaw) ?? .dsWatch }
    var detail: TaskDetail { TaskDetailCoding.decode(detailRaw) }

    var isPaused: Bool { pausedAt != nil }

    /// Seconds on the clock, not counting pauses.
    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let startedAt else { return 0 }
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedSeconds)
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
}

enum TaskStatus: String {
    case planned
    case active
    case done
    case skipped
}

/// Writing saved from `write.guided` / `write.quick`, with its correction and the learner's rewrite.
@Model final class WritingEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var taskRaw: String = TaskKind.writeGuided.rawValue
    var prompt: String = ""
    var text: String = ""
    /// Encoded `CorrectionService.Result`.
    var feedbackJSON: Data?
    var rewrite: String = ""

    init(date: Date, task: TaskKind, prompt: String, text: String) {
        self.date = date
        self.taskRaw = task.rawValue
        self.prompt = prompt
        self.text = text
    }
}

/// A mistake-deck card, scheduled with FSRS. See docs/03-experience.md §3.4 "Mistake deck".
@Model final class ReviewCard {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var front: String = ""
    var back: String = ""
    var explanation: String = ""
    /// "writing", "tandem" or "manual".
    var origin: String = "manual"
    /// The writing entry it came from, so undoing that writing task removes its cards.
    var writingID: UUID?

    var due: Date = Date.now
    var stability: Double = 0
    var difficulty: Double = 0
    var reps: Int = 0
    var lapses: Int = 0
    var stateRaw: Int = 0
    var lastReview: Date?

    init(front: String, back: String, explanation: String, origin: String) {
        self.front = front
        self.back = back
        self.explanation = explanation
        self.origin = origin
    }

    var schedule: FSRS.Card {
        get {
            var card = FSRS.Card(due: due)
            card.stability = stability
            card.difficulty = difficulty
            card.reps = reps
            card.lapses = lapses
            card.state = FSRS.State(rawValue: stateRaw) ?? .new
            card.lastReview = lastReview
            return card
        }
        set {
            due = newValue.due
            stability = newValue.stability
            difficulty = newValue.difficulty
            reps = newValue.reps
            lapses = newValue.lapses
            stateRaw = newValue.state.rawValue
            lastReview = newValue.lastReview
        }
    }
}

enum TaskDetailCoding {
    static func encode(_ detail: TaskDetail) -> String {
        switch detail {
        case .none: ""
        case .languageTransferTrack(let track): "lt:\(track)"
        case .extraPart(let episode, let part): "extra:\(episode):\(part)"
        case .extraEpisode(let episode): "extra:\(episode)"
        case .dreamingDifficulty(let range): "ds:\(range.lowerBound):\(range.upperBound)"
        }
    }

    static func decode(_ raw: String) -> TaskDetail {
        let parts = raw.split(separator: ":").map(String.init)
        let numbers = parts.dropFirst().compactMap(Int.init)
        switch (parts.first, numbers.count) {
        case ("lt", 1): return .languageTransferTrack(numbers[0])
        case ("extra", 2): return .extraPart(episode: numbers[0], part: numbers[1])
        case ("extra", 1): return .extraEpisode(numbers[0])
        case ("ds", 2) where numbers[0] <= numbers[1]: return .dreamingDifficulty(numbers[0]...numbers[1])
        default: return .none
        }
    }
}
