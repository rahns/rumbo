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

    /// Input hours at which this band starts.
    public var inputHoursThreshold: Double {
        switch self {
        case .a2_1: 150
        case .a2_2: 225
        case .b1_1: 300
        case .b1_2: 450
        case .b2_1: 600
        case .b2_2: 800
        }
    }

    /// Share of weekly minutes per strand (R1). Each row sums to 1.
    public var strandTargets: [Strand: Double] {
        switch self {
        case .a2_1: [.input: 0.45, .output: 0.15, .languageFocused: 0.30, .fluency: 0.10]
        case .a2_2: [.input: 0.45, .output: 0.18, .languageFocused: 0.27, .fluency: 0.10]
        case .b1_1: [.input: 0.45, .output: 0.22, .languageFocused: 0.20, .fluency: 0.13]
        case .b1_2: [.input: 0.45, .output: 0.25, .languageFocused: 0.15, .fluency: 0.15]
        case .b2_1: [.input: 0.45, .output: 0.28, .languageFocused: 0.12, .fluency: 0.15]
        case .b2_2: [.input: 0.45, .output: 0.30, .languageFocused: 0.10, .fluency: 0.15]
        }
    }

    /// The band an amount of input hours falls into, before any can-do adjustment.
    /// Learners below A2.1's threshold are still placed in A2.1.
    public static func forInputHours(_ hours: Double) -> Band {
        allCases.last { hours >= $0.inputHoursThreshold } ?? .a2_1
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
