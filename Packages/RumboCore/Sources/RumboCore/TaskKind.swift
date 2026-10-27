/// The learner's sources. Every one can be switched off; the planner then fills its strand with other tasks.
public enum SourceKind: String, CaseIterable, Codable, Sendable {
    case dreamingSpanish
    case languageTransfer
    case extraEnEspanol
    case duolingo
    case writing
    case tandem
    case suggestedContent
}

public struct MinuteRange: Equatable, Sendable {
    public let min: Int
    public let standard: Int
    public let max: Int
}

/// Every kind of task the planner can put on a day. See docs/02-learning-engine.md §2.3.
public enum TaskKind: String, CaseIterable, Codable, Sendable {
    case duoLesson = "duo.lesson"
    case ltTrack = "lt.track"
    case dsWatch = "ds.watch"
    case dsEasy = "ds.easy"
    case extraIntensive = "extra.intensive"
    case extraExtensive = "extra.extensive"
    case contentWatch = "content.watch"
    case writeGuided = "write.guided"
    case writeQuick = "write.quick"
    case tandemText = "tandem.text"
    case tandemVoice = "tandem.voice"
    case tandemCall = "tandem.call"
    case fluency432 = "fluency.432"
    case reviewMistakes = "review.mistakes"
    case missionTravel = "mission.travel"

    public var strand: Strand {
        switch self {
        // Intensive Extra viewing is captioned input with a short shadowing step, so it sits in input.
        case .dsWatch, .extraIntensive, .extraExtensive, .contentWatch: .input
        case .writeGuided, .tandemText, .tandemVoice, .tandemCall, .missionTravel: .output
        case .duoLesson, .ltTrack, .reviewMistakes: .languageFocused
        case .dsEasy, .writeQuick, .fluency432: .fluency
        }
    }

    public var minutes: MinuteRange {
        switch self {
        // One lesson (about 3 minutes) every day; never more than 5: a warm-up, not a main source.
        case .duoLesson: MinuteRange(min: 3, standard: 3, max: 5)
        case .ltTrack: MinuteRange(min: 8, standard: 12, max: 25)
        case .dsWatch: MinuteRange(min: 7, standard: 20, max: 60)
        case .dsEasy: MinuteRange(min: 7, standard: 10, max: 20)
        case .extraIntensive: MinuteRange(min: 10, standard: 12, max: 15)
        case .extraExtensive: MinuteRange(min: 12, standard: 25, max: 30)
        case .contentWatch: MinuteRange(min: 10, standard: 20, max: 60)
        case .writeGuided: MinuteRange(min: 8, standard: 12, max: 20)
        case .writeQuick: MinuteRange(min: 5, standard: 5, max: 10)
        case .tandemText: MinuteRange(min: 5, standard: 10, max: 15)
        case .tandemVoice: MinuteRange(min: 8, standard: 10, max: 15)
        case .tandemCall: MinuteRange(min: 15, standard: 20, max: 30)
        case .fluency432: MinuteRange(min: 10, standard: 10, max: 12)
        case .reviewMistakes: MinuteRange(min: 3, standard: 5, max: 10)
        case .missionTravel: MinuteRange(min: 5, standard: 10, max: 20)
        }
    }

    /// The source a task needs, or `nil` for tasks that live entirely in Rumbo.
    public var source: SourceKind? {
        switch self {
        case .duoLesson: .duolingo
        case .ltTrack: .languageTransfer
        case .dsWatch, .dsEasy: .dreamingSpanish
        case .extraIntensive, .extraExtensive: .extraEnEspanol
        case .contentWatch: .suggestedContent
        case .writeGuided, .writeQuick: .writing
        case .tandemText, .tandemVoice, .tandemCall: .tandem
        case .fluency432, .reviewMistakes, .missionTravel: nil
        }
    }

    /// Whether the task can be done without internet (assuming downloads where the source allows them).
    public var isOfflineCapable: Bool {
        switch self {
        case .extraIntensive, .extraExtensive, .contentWatch, .tandemText, .tandemVoice, .tandemCall: false
        default: true
        }
    }

    /// Whether logged minutes add to the learner's input hours.
    public var countsAsInput: Bool {
        switch self {
        case .dsWatch, .dsEasy, .extraIntensive, .extraExtensive, .contentWatch: true
        default: false
        }
    }

    /// Any of the Tandem tasks counts toward the weekly exchange anchor.
    public var isTandemExchange: Bool {
        switch self {
        case .tandemText, .tandemVoice, .tandemCall: true
        default: false
        }
    }
}
