import Foundation

/// Speaking stages for Tandem. See docs/02-learning-engine.md §2.4.
public enum SpeakingStage: Int, Codable, Sendable, Comparable {
    case text = 1
    case voiceNotes = 2
    case calls = 3

    public static func < (lhs: SpeakingStage, rhs: SpeakingStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Course {
    public static let languageTransferTracks = 90
    public static let extraEpisodes = 13
    /// At A2, one Extra episode is split into this many intensive parts.
    public static let extraIntensivePartsPerEpisode = 2
}

/// Everything the planner needs to know about the learner today.
public struct LearnerSnapshot: Sendable {
    public var band: Band
    public var enabledSources: Set<SourceKind>
    public var speakingStage: SpeakingStage
    /// Last Language Transfer track finished (0 = not started).
    public var languageTransferLastTrack: Int
    /// The last track was rated "shaky", so the next session repeats it once.
    public var languageTransferRepeatPending: Bool
    public var extraEpisodesWatched: Int
    /// Intensive parts already done in the episode currently being watched.
    public var extraPartsDoneInEpisode: Int
    /// Keep a short Duolingo warm-up at B2.1 (optional there; never planned at B2.2).
    public var keepDuolingoInB2: Bool
    public var dueReviewCards: Int
    public var travelMode: Bool
    public var isOnline: Bool
    /// Suggested Dreaming Spanish difficulty range.
    public var dsDifficulty: ClosedRange<Int>

    public init(
        band: Band,
        enabledSources: Set<SourceKind> = Set(SourceKind.allCases),
        speakingStage: SpeakingStage = .text,
        languageTransferLastTrack: Int = 0,
        languageTransferRepeatPending: Bool = false,
        extraEpisodesWatched: Int = 0,
        extraPartsDoneInEpisode: Int = 0,
        keepDuolingoInB2: Bool = false,
        dueReviewCards: Int = 0,
        travelMode: Bool = false,
        isOnline: Bool = true,
        dsDifficulty: ClosedRange<Int> = 40...48
    ) {
        self.band = band
        self.enabledSources = enabledSources
        self.speakingStage = speakingStage
        self.languageTransferLastTrack = languageTransferLastTrack
        self.languageTransferRepeatPending = languageTransferRepeatPending
        self.extraEpisodesWatched = extraEpisodesWatched
        self.extraPartsDoneInEpisode = extraPartsDoneInEpisode
        self.keepDuolingoInB2 = keepDuolingoInB2
        self.dueReviewCards = dueReviewCards
        self.travelMode = travelMode
        self.isOnline = isOnline
        self.dsDifficulty = dsDifficulty
    }

    public var languageTransferFinished: Bool {
        languageTransferLastTrack >= Course.languageTransferTracks
    }

    public var extraFinished: Bool {
        extraEpisodesWatched >= Course.extraEpisodes
    }

    /// Duolingo is a daily warm-up from A2.1 to B1.2, optional at B2.1 and dropped at B2.2 (R15).
    public var usesDuolingo: Bool {
        guard enabledSources.contains(.duolingo) else { return false }
        switch band {
        case .a2_1, .a2_2, .b1_1, .b1_2: return true
        case .b2_1: return keepDuolingoInB2
        case .b2_2: return false
        }
    }

    /// Whether a task may be planned at all for this learner today.
    public func isEligible(_ kind: TaskKind) -> Bool {
        if let source = kind.source, !enabledSources.contains(source) { return false }
        if !isOnline && !kind.isOfflineCapable { return false }

        switch kind {
        case .duoLesson:
            return usesDuolingo
        case .ltTrack:
            return !languageTransferFinished
        case .dsWatch, .dsEasy, .writeGuided, .tandemText:
            return true
        case .extraIntensive:
            return band <= .a2_2 && !extraFinished
        case .extraExtensive:
            return band >= .b1_1 && band <= .b1_2 && !extraFinished
        case .contentWatch:
            // Suggested content steps in once Extra has run out (or isn't used), from B1, or when there is no Dreaming Spanish.
            let extraUnavailable = extraFinished || !enabledSources.contains(.extraEnEspanol)
            return (band >= .b1_1 && extraUnavailable) || !enabledSources.contains(.dreamingSpanish)
        case .writeQuick:
            return band >= .b1_1
        case .tandemVoice, .fluency432:
            return speakingStage >= .voiceNotes
        case .tandemCall:
            return speakingStage >= .calls
        case .reviewMistakes:
            return dueReviewCards > 0
        case .missionTravel:
            return travelMode
        }
    }

    /// The best Tandem task for the learner's speaking stage.
    var preferredTandemTask: TaskKind {
        switch speakingStage {
        case .text: .tandemText
        case .voiceNotes, .calls: .tandemVoice
        }
    }
}

/// One logged block of practice.
public struct ActivityRecord: Equatable, Sendable {
    public var date: Date
    public var kind: TaskKind
    public var minutes: Int

    public init(date: Date, kind: TaskKind, minutes: Int) {
        self.date = date
        self.kind = kind
        self.minutes = minutes
    }
}
