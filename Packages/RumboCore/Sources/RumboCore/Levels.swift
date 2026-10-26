import Foundation

/// Onboarding placement. See docs/02-learning-engine.md §2.1 "Placement".
public enum Placement {
    public struct Result: Equatable, Sendable {
        public var band: Band
        public var bandByHours: Band
        /// -1, 0 or +1: how the can-do check moved the learner.
        public var adjustment: Int
    }

    /// - Parameters:
    ///   - ownBandYes: "Sí" answers to the statements for the band the hours point to.
    ///   - nextBandYes: "Sí" answers to the statements for the band above it.
    ///   - statementsPerBand: how many statements of each band were shown (10, or 5 in onboarding).
    /// Moves up if ≥ 80% of the next band's statements are ticked, down if < 50% of the own band's.
    public static func place(inputHours: Double, ownBandYes: Int, nextBandYes: Int, statementsPerBand: Int = CanDo.perBand) -> Result {
        let byHours = Band.forInputHours(inputHours)
        let total = Double(max(statementsPerBand, 1))
        var band = byHours
        var adjustment = 0
        if Double(nextBandYes) / total >= 0.8, let next = byHours.next {
            band = next
            adjustment = 1
        } else if Double(ownBandYes) / total < 0.5, let previous = byHours.previous {
            band = previous
            adjustment = -1
        }
        return Result(band: band, bandByHours: byHours, adjustment: adjustment)
    }
}

/// Level-up gates. See docs/02-learning-engine.md §2.1 "Promotion".
public enum LevelGate {
    public static let passMark = 7
    public static let retryDays = 14

    /// Whether the gate to the next band is open today.
    public static func isOpen(
        band: Band,
        inputHours: Double,
        lastFailedAttempt: Date?,
        today: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let next = band.next, inputHours >= next.inputHoursThreshold else { return false }
        guard let lastFailedAttempt else { return true }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastFailedAttempt), to: calendar.startOfDay(for: today)).day ?? 0
        return days >= retryDays
    }

    public static func passes(yesAnswers: Int) -> Bool {
        yesAnswers >= passMark
    }
}

/// Tandem stage unlocks. See docs/02-learning-engine.md §2.4.
public enum SpeakingProgress {
    public struct Evidence: Sendable {
        public var inputHours: Double
        public var textExchanges: Int
        /// Days between the first and the latest logged text exchange.
        public var textExchangeSpanDays: Int
        public var comfortableWithText: Bool
        public var voiceNotes: Int

        public init(inputHours: Double, textExchanges: Int, textExchangeSpanDays: Int, comfortableWithText: Bool, voiceNotes: Int) {
            self.inputHours = inputHours
            self.textExchanges = textExchanges
            self.textExchangeSpanDays = textExchangeSpanDays
            self.comfortableWithText = comfortableWithText
            self.voiceNotes = voiceNotes
        }
    }

    /// The highest stage the evidence supports. A learner who unlocked a stage early ("I feel ready") keeps it.
    public static func stage(for evidence: Evidence, current: SpeakingStage) -> SpeakingStage {
        var stage: SpeakingStage = .text
        if evidence.inputHours >= 250, evidence.textExchanges >= 8,
           evidence.textExchangeSpanDays >= 21, evidence.comfortableWithText {
            stage = .voiceNotes
            if evidence.inputHours >= 400, evidence.voiceNotes >= 6 {
                stage = .calls
            }
        }
        return max(stage, current)
    }
}

/// Keeps Dreaming Spanish input comprehensible. See docs/02-learning-engine.md §2.6 (R3).
public enum ComprehensionTuner {
    public enum Rating: Int, Codable, Sendable {
        case lost = 1
        case mostly = 2
        case easy = 3
    }

    public static let window = 5
    public static let step = 5

    /// Suggested new range, or `nil` to keep the current one. `ratings` are oldest first, all at the current range.
    public static func suggestion(for ratings: [Rating], current: ClosedRange<Int>) -> ClosedRange<Int>? {
        let recent = ratings.suffix(window)
        let lost = recent.filter { $0 == .lost }.count
        let easy = recent.filter { $0 == .easy }.count
        // Being lost is worse than being bored, so lowering wins if both apply.
        if lost >= 2 {
            let lower = max(0, current.lowerBound - step)
            return lower...(lower + current.count - 1)
        }
        if easy >= 3 {
            return (current.lowerBound + step)...(current.upperBound + step)
        }
        return nil
    }
}

extension Band {
    public var next: Band? {
        let all = Band.allCases
        let index = all.firstIndex(of: self)!
        return index + 1 < all.count ? all[index + 1] : nil
    }

    public var previous: Band? {
        let all = Band.allCases
        let index = all.firstIndex(of: self)!
        return index > 0 ? all[index - 1] : nil
    }
}
