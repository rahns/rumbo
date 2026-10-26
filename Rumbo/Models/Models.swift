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
    var dsDifficultyHigh: Int = 48
    var languageTransferLastTrack: Int = 0
    var languageTransferRepeatPending: Bool = false
    var extraEpisodesWatched: Int = 0
    var extraPartsDoneInEpisode: Int = 0
    var duolingoSection: Int = 1
    var duolingoUnit: Int = 1

    /// Level-up gates (§2.1): passes count toward XP; a failed check waits 14 days.
    var gatesPassed: Int = 0
    var lastFailedGate: Date?

    init() {}

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

    var sortedTasks: [PlannedTaskRecord] {
        (tasks ?? []).sorted { $0.order < $1.order }
    }
}

@Model final class PlannedTaskRecord {
    var taskRaw: String = TaskKind.dsWatch.rawValue
    var order: Int = 0
    var minutesPlanned: Int = 0
    var isAnchor: Bool = false
    /// Encoded `TaskDetail`, e.g. "lt:13", "extra:2:1", "ds:40:48".
    var detailRaw: String = ""
    /// The prompt shown for output tasks, fixed when the plan is made.
    var prompt: String = ""
    var statusRaw: String = TaskStatus.planned.rawValue
    var startedAt: Date?
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

/// Writing saved from `write.guided` / `write.quick`. Correction arrives in M4.
@Model final class WritingEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var taskRaw: String = TaskKind.writeGuided.rawValue
    var prompt: String = ""
    var text: String = ""

    init(date: Date, task: TaskKind, prompt: String, text: String) {
        self.date = date
        self.taskRaw = task.rawValue
        self.prompt = prompt
        self.text = text
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
