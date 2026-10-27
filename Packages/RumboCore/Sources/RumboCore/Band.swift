/// The six internal levels Rumbo plans for. See docs/02-learning-engine.md §2.1.
public enum Band: String, CaseIterable, Codable, Sendable, Comparable {
    case a2_1 = "A2.1"
    case a2_2 = "A2.2"
    case b1_1 = "B1.1"
    case b1_2 = "B1.2"
    case b2_1 = "B2.1"
    case b2_2 = "B2.2"

    /// Friendly name shown in the app.
    public var label: String {
        switch self {
        case .a2_1: "Explorador"
        case .a2_2: "Viajero"
        case .b1_1: "Andante"
        case .b1_2: "Conversador"
        case .b2_1: "Fluido"
        case .b2_2: "Local"
        }
    }

    /// Training hours (all practice, every minute counted) at which this band starts: the listening-hour
    /// milestones (150 / 225 / 300 / 450 / 600 / 800, Dreaming Spanish's roadmap) divided by the plan's
    /// listening share, rounded to 10 (docs/02-learning-engine.md §2.1).
    public var hoursThreshold: Double {
        switch self {
        case .a2_1: 270
        case .a2_2: 410
        case .b1_1: 550
        case .b1_2: 820
        case .b2_1: 1090
        case .b2_2: 1450
        }
    }

    /// The share of training time that's listening at every band. Level hours are listening milestones ÷ this.
    public static let listeningShare = 0.55

    /// Training hours equivalent to `hours` of listening, for listening done before Rumbo (e.g. Dreaming Spanish's counter).
    public static func trainingHours(fromListening hours: Double) -> Double {
        hours / listeningShare
    }

    /// Share of weekly minutes per strand (R1). Each row sums to 1; listening is 55% throughout.
    public var strandTargets: [Strand: Double] {
        switch self {
        case .a2_1: [.input: 0.55, .output: 0.13, .languageFocused: 0.24, .fluency: 0.08]
        case .a2_2: [.input: 0.55, .output: 0.15, .languageFocused: 0.22, .fluency: 0.08]
        case .b1_1: [.input: 0.55, .output: 0.18, .languageFocused: 0.18, .fluency: 0.09]
        case .b1_2: [.input: 0.55, .output: 0.20, .languageFocused: 0.15, .fluency: 0.10]
        case .b2_1: [.input: 0.55, .output: 0.23, .languageFocused: 0.10, .fluency: 0.12]
        case .b2_2: [.input: 0.55, .output: 0.25, .languageFocused: 0.08, .fluency: 0.12]
        }
    }

    /// The band an amount of training hours falls into, before any can-do adjustment.
    /// Learners below A2.1's threshold are still placed in A2.1.
    public static func forHours(_ hours: Double) -> Band {
        allCases.last { hours >= $0.hoursThreshold } ?? .a2_1
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
