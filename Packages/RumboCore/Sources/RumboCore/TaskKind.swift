/// The roles a learner's sources play. Each language fills a role with its own product (`LanguagePack.sources`):
/// for Spanish, graded video is Dreaming Spanish, the audio course is Language Transfer, and so on.
/// Every one can be switched off; the planner then fills its strand with other tasks.
/// The raw values are what's stored (profiles, backups) and date from when Spanish was the only language: never change them.
public enum SourceKind: String, CaseIterable, Codable, Sendable {
    case gradedVideo = "dreamingSpanish"
    case audioCourse = "languageTransfer"
    case learnerSeries = "extraEnEspanol"
    case drillApp = "duolingo"
    case writing
    case exchange = "tandem"
    case suggestedContent
}

public struct MinuteRange: Equatable, Sendable {
    public let min: Int
    public let standard: Int
    public let max: Int
}

/// Every kind of task the planner can put on a day. See docs/02-learning-engine.md §2.3.
/// The raw values are what's stored (logs, plans, backups) and date from when Spanish was the only language: never change them.
public enum TaskKind: String, CaseIterable, Codable, Sendable {
    case drillLesson = "duo.lesson"
    case courseTrack = "lt.track"
    case gradedWatch = "ds.watch"
    case gradedEasy = "ds.easy"
    case seriesIntensive = "extra.intensive"
    case seriesExtensive = "extra.extensive"
    case contentWatch = "content.watch"
    case writeGuided = "write.guided"
    case writeQuick = "write.quick"
    case exchangeText = "tandem.text"
    case exchangeVoice = "tandem.voice"
    case exchangeCall = "tandem.call"
    case fluency432 = "fluency.432"
    case reviewMistakes = "review.mistakes"
    case missionTravel = "mission.travel"
    /// Practice logged by hand outside the plan ("Log other"), one per strand besides listening
    /// (which uses `contentWatch`). Never planned.
    case otherStudy = "other.study"
    case otherOutput = "other.output"
    case otherFluency = "other.fluency"
    /// A tutoring or classroom lesson (Settings → Lessons), one per type. Planned only from the lesson schedule.
    case lessonOutput = "lesson.output"
    case lessonInput = "lesson.input"
    case lessonStudy = "lesson.study"
    /// An all-in-one lesson: planned as one card, logged as three equal parts (`LessonType.split`).
    case lessonMixed = "lesson.mixed"

    /// The lesson kind for a lesson type; all-in-one is planned as one mixed card.
    public static func lesson(for type: LessonType) -> TaskKind {
        switch type {
        case .output: .lessonOutput
        case .input: .lessonInput
        case .languageFocused: .lessonStudy
        case .allInOne: .lessonMixed
        }
    }

    public var isLesson: Bool { self == .lessonOutput || self == .lessonInput || self == .lessonStudy || self == .lessonMixed }

    /// The kind "Log other" records for practice in `strand`.
    public static func other(for strand: Strand) -> TaskKind {
        switch strand {
        case .input: .contentWatch
        case .languageFocused: .otherStudy
        case .output: .otherOutput
        case .fluency: .otherFluency
        }
    }

    public var strand: Strand {
        switch self {
        // Intensive Extra viewing is captioned input with a short shadowing step, so it sits in input.
        case .gradedWatch, .seriesIntensive, .seriesExtensive, .contentWatch, .lessonInput: .input
        // An all-in-one lesson is logged split across three strands; as a planned card it shows as speaking.
        case .writeGuided, .exchangeText, .exchangeVoice, .exchangeCall, .missionTravel, .otherOutput, .lessonOutput, .lessonMixed: .output
        case .drillLesson, .courseTrack, .reviewMistakes, .otherStudy, .lessonStudy: .languageFocused
        case .gradedEasy, .writeQuick, .fluency432, .otherFluency: .fluency
        }
    }

    public var minutes: MinuteRange {
        switch self {
        // One lesson (about 3 minutes) every day; never more than 5: a warm-up, not a main source.
        case .drillLesson: MinuteRange(min: 3, standard: 3, max: 5)
        // Planned at the track's real length (`AudioCourse.minutes`): 5 to 16 minutes.
        case .courseTrack: MinuteRange(min: 5, standard: 10, max: 16)
        case .gradedWatch: MinuteRange(min: 7, standard: 20, max: 60)
        case .gradedEasy: MinuteRange(min: 7, standard: 10, max: 20)
        case .seriesIntensive: MinuteRange(min: 10, standard: 12, max: 15)
        case .seriesExtensive: MinuteRange(min: 12, standard: 25, max: 30)
        case .contentWatch: MinuteRange(min: 10, standard: 20, max: 60)
        case .writeGuided: MinuteRange(min: 8, standard: 12, max: 20)
        case .writeQuick: MinuteRange(min: 5, standard: 5, max: 10)
        case .exchangeText: MinuteRange(min: 5, standard: 10, max: 15)
        case .exchangeVoice: MinuteRange(min: 8, standard: 10, max: 15)
        case .exchangeCall: MinuteRange(min: 15, standard: 20, max: 30)
        case .fluency432: MinuteRange(min: 10, standard: 10, max: 12)
        case .reviewMistakes: MinuteRange(min: 3, standard: 5, max: 10)
        case .missionTravel: MinuteRange(min: 3, standard: 3, max: 3)
        case .otherStudy, .otherOutput, .otherFluency: MinuteRange(min: 1, standard: 20, max: 600)
        case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed: MinuteRange(min: 5, standard: 60, max: 240)
        }
    }

    /// The source a task needs, or `nil` for tasks that live entirely in Rumbo.
    public var source: SourceKind? {
        switch self {
        case .drillLesson: .drillApp
        case .courseTrack: .audioCourse
        case .gradedWatch, .gradedEasy: .gradedVideo
        case .seriesIntensive, .seriesExtensive: .learnerSeries
        case .contentWatch: .suggestedContent
        case .writeGuided, .writeQuick: .writing
        case .exchangeText, .exchangeVoice, .exchangeCall: .exchange
        case .fluency432, .reviewMistakes, .missionTravel, .otherStudy, .otherOutput, .otherFluency,
             .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed: nil
        }
    }

    /// Whether the task can be done without internet (assuming downloads where the source allows them).
    public var isOfflineCapable: Bool {
        switch self {
        case .seriesIntensive, .seriesExtensive, .contentWatch, .exchangeText, .exchangeVoice, .exchangeCall: false
        default: true
        }
    }

    /// Whether logged minutes add to the learner's input hours.
    public var countsAsInput: Bool {
        switch self {
        case .gradedWatch, .gradedEasy, .seriesIntensive, .seriesExtensive, .contentWatch, .lessonInput: true
        default: false
        }
    }

    /// Any of the Tandem tasks counts toward the weekly exchange anchor.
    public var isExchange: Bool {
        switch self {
        case .exchangeText, .exchangeVoice, .exchangeCall: true
        default: false
        }
    }
}
