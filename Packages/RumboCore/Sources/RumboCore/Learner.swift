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

/// Everything the planner needs to know about the learner today.
public struct LearnerSnapshot: Sendable {
    /// The language being learned: which sources exist, their sizes, and the weekly anchors.
    public var pack: LanguagePack
    public var band: Band
    public var enabledSources: Set<SourceKind>
    public var speakingStage: SpeakingStage
    /// Last audio-course track finished (0 = not started).
    public var courseLastTrack: Int
    /// The last track was rated "shaky", so the next session repeats it once.
    public var courseRepeatPending: Bool
    public var seriesEpisodesWatched: Int
    /// Intensive parts already done in the episode currently being watched.
    public var seriesPartsDone: Int
    /// Keep the drill-app warm-up at the level where it's optional (`DrillApp.optionalBand`).
    public var keepDrillAppLate: Bool
    public var dueReviewCards: Int
    public var travelMode: Bool
    public var isOnline: Bool
    /// Suggested difficulty range in the graded video library.
    public var gradedDifficulty: ClosedRange<Int>
    /// Settings → Habit → Always include (Duolingo): a short lesson every day, for the learner's streak there.
    /// Off: the drill app is just one of the study options.
    public var alwaysIncludeDrillApp: Bool
    /// Tutoring or classroom lessons (Settings → Lessons).
    public var lessons: LessonSchedule
    /// Settings → Plan balance: the learner's own split between the strands, or nil for the band's.
    public var balance: StrandBalance?

    /// What share of the day each strand should get: the custom balance, or the band's research-based split,
    /// over the strands the planner can fill today. A strand with nothing to plan (every source for it off,
    /// say) has its share spread over the others in proportion. If the split puts everything on such strands,
    /// the band's split is used for the rest instead, so the plan is never left empty.
    public var strandTargets: [Strand: Double] {
        let available = Strand.allCases.filter(canPlan)
        guard !available.isEmpty else { return balance?.targets ?? band.strandTargets }
        func share(_ targets: [Strand: Double]) -> [Strand: Double]? {
            // Nothing to move: keep the split exactly as it is.
            if Strand.allCases.allSatisfy({ available.contains($0) || (targets[$0] ?? 0) == 0 }) { return targets }
            let sum = available.reduce(0) { $0 + (targets[$1] ?? 0) }
            guard sum > 0 else { return nil }
            return Dictionary(uniqueKeysWithValues: Strand.allCases.map { strand in
                (strand, available.contains(strand) ? (targets[strand] ?? 0) / sum : 0)
            })
        }
        return balance.flatMap { share($0.targets) } ?? share(band.strandTargets)
            ?? Dictionary(uniqueKeysWithValues: Strand.allCases.map { ($0, available.contains($0) ? 1 / Double(available.count) : 0) })
    }

    /// Whether the planner has anything it can put on a card in this strand (lessons and logged-only kinds aside).
    public func canPlan(_ strand: Strand) -> Bool {
        TaskKind.allCases.contains { $0.strand == strand && isEligible($0) }
    }

    public init(
        band: Band,
        enabledSources: Set<SourceKind> = Set(SourceKind.allCases),
        speakingStage: SpeakingStage = .text,
        courseLastTrack: Int = 0,
        courseRepeatPending: Bool = false,
        seriesEpisodesWatched: Int = 0,
        seriesPartsDone: Int = 0,
        keepDrillAppLate: Bool = false,
        dueReviewCards: Int = 0,
        travelMode: Bool = false,
        isOnline: Bool = true,
        gradedDifficulty: ClosedRange<Int> = 40...48,
        alwaysIncludeDrillApp: Bool = true,
        lessons: LessonSchedule = LessonSchedule(),
        balance: StrandBalance? = nil,
        pack: LanguagePack = .spanish
    ) {
        self.pack = pack
        self.balance = balance
        self.band = band
        self.enabledSources = enabledSources
        self.speakingStage = speakingStage
        self.courseLastTrack = courseLastTrack
        self.courseRepeatPending = courseRepeatPending
        self.seriesEpisodesWatched = seriesEpisodesWatched
        self.seriesPartsDone = seriesPartsDone
        self.keepDrillAppLate = keepDrillAppLate
        self.dueReviewCards = dueReviewCards
        self.travelMode = travelMode
        self.isOnline = isOnline
        self.gradedDifficulty = gradedDifficulty
        self.alwaysIncludeDrillApp = alwaysIncludeDrillApp
        self.lessons = lessons
    }

    /// The audio course is done, or the language has none.
    public var courseFinished: Bool {
        courseLastTrack >= (pack.course?.tracks ?? 0)
    }

    /// The learner series is done, or the language has none.
    public var seriesFinished: Bool {
        seriesEpisodesWatched >= (pack.series?.episodes ?? 0)
    }

    /// Whether the learner uses `role`: the language has a source for it and it's switched on.
    public func uses(_ role: SourceKind) -> Bool {
        pack.has(role) && enabledSources.contains(role)
    }

    /// The drill app is a daily warm-up up to a level, optional at the next and dropped after (R15).
    public var usesDrillApp: Bool {
        guard uses(.drillApp), let drill = pack.drill else { return false }
        if band <= drill.lastBand { return true }
        return band == drill.optionalBand && keepDrillAppLate
    }

    /// Whether a task may be planned at all for this learner today.
    public func isEligible(_ kind: TaskKind) -> Bool {
        if let source = kind.source, !uses(source) { return false }
        if !isOnline && !kind.isOfflineCapable { return false }

        switch kind {
        case .drillLesson:
            return usesDrillApp
        case .courseTrack:
            return !courseFinished
        case .gradedWatch, .gradedEasy, .writeGuided, .exchangeText:
            return true
        case .seriesIntensive:
            return pack.series?.intensiveBands.contains(band) == true && !seriesFinished
        case .seriesExtensive:
            return pack.series?.extensiveBands.contains(band) == true && !seriesFinished
        case .contentWatch:
            // Suggested content steps in once the learner series has run out (or isn't used), from B1,
            // or when there is no graded video library.
            let seriesUnavailable = seriesFinished || !uses(.learnerSeries)
            return (band >= .b1_1 && seriesUnavailable) || !uses(.gradedVideo)
        case .writeQuick:
            return band >= .b1_1
        case .exchangeVoice, .fluency432:
            return speakingStage >= .voiceNotes
        case .exchangeCall:
            return speakingStage >= .calls
        case .reviewMistakes:
            return dueReviewCards > 0
        case .missionTravel:
            return travelMode
        case .otherStudy, .otherOutput, .otherFluency:
            // Only ever logged by hand.
            return false
        case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed:
            // Planned from the lesson schedule, never chosen by the planner.
            return false
        }
    }

    /// The best exchange task for the learner's speaking stage.
    var preferredExchangeTask: TaskKind {
        switch speakingStage {
        case .text: .exchangeText
        case .voiceNotes, .calls: .exchangeVoice
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
