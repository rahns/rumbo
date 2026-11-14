/// The eight internal levels Rumbo plans for, from a complete beginner (A1.1, zero hours) to B2.2.
/// See docs/02-learning-engine.md §2.1 and docs/10-beginners.md for A1.
/// The hours each one starts at and its friendly name depend on the language (`LanguagePack.levels`, `levelName`).
public enum Band: String, CaseIterable, Codable, Sendable, Comparable {
    /// Complete beginners: from the first word.
    case a1_1 = "A1.1"
    case a1_2 = "A1.2"
    case a2_1 = "A2.1"
    case a2_2 = "A2.2"
    case b1_1 = "B1.1"
    case b1_2 = "B1.2"
    case b2_1 = "B2.1"
    case b2_2 = "B2.2"

    /// The share of training time that's listening at every band. Level hours are listening milestones ÷ this.
    public static let listeningShare = 0.55

    /// Training hours equivalent to `hours` of listening, for listening done before Rumbo (e.g. Dreaming Spanish's counter).
    public static func trainingHours(fromListening hours: Double) -> Double {
        hours / listeningShare
    }

    /// Share of weekly minutes per strand (R1). Each row sums to 1; listening is 55% throughout.
    public var strandTargets: [Strand: Double] {
        switch self {
        // Beginners lean on structured study (an audio course, Duolingo) while there's little they can understand
        // yet, and speak and write very little: Nation's language-focused strand is at its largest here. No fluency
        // practice yet: there's nothing to make faster until there's something known well. At A1.1 no separate
        // speaking or writing either: Language Transfer and Duolingo already have the learner answering out loud.
        case .a1_1: [.input: 0.55, .output: 0, .languageFocused: 0.45, .fluency: 0]
        case .a1_2: [.input: 0.55, .output: 0.10, .languageFocused: 0.35, .fluency: 0]
        case .a2_1: [.input: 0.55, .output: 0.13, .languageFocused: 0.24, .fluency: 0.08]
        case .a2_2: [.input: 0.55, .output: 0.15, .languageFocused: 0.22, .fluency: 0.08]
        case .b1_1: [.input: 0.55, .output: 0.18, .languageFocused: 0.18, .fluency: 0.09]
        case .b1_2: [.input: 0.55, .output: 0.20, .languageFocused: 0.15, .fluency: 0.10]
        case .b2_1: [.input: 0.55, .output: 0.23, .languageFocused: 0.10, .fluency: 0.12]
        case .b2_2: [.input: 0.55, .output: 0.25, .languageFocused: 0.08, .fluency: 0.12]
        }
    }

    public static func < (lhs: Band, rhs: Band) -> Bool {
        let order = Band.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Nation's four strands.
public enum Strand: String, CaseIterable, Codable, Sendable {
    case input
    case output
    case languageFocused
    case fluency
}

extension Band {
    /// The first level, from this one up, whose plan includes `strand` (A1.2 for speaking & writing, A2.1 for
    /// fluency), or nil if none does. For "Starts at A2.1" on a strand that's at 0% for now.
    public func firstBand(including strand: Strand) -> Band? {
        Band.allCases.first { $0 >= self && ($0.strandTargets[strand] ?? 0) > 0 }
    }
}

