import Foundation

/// Spaced-repetition scheduling for the mistake deck, using FSRS-5 with its published default parameters (R7).
/// The app shows three buttons: Again, Good, Easy.
public struct FSRS: Sendable {
    public enum Rating: Int, Codable, Sendable {
        case again = 1
        case hard = 2
        case good = 3
        case easy = 4
    }

    public enum State: Int, Codable, Sendable {
        case new = 0
        case learning = 1
        case review = 2
        case relearning = 3
    }

    public struct Card: Equatable, Codable, Sendable {
        public var due: Date
        public var stability: Double
        public var difficulty: Double
        public var reps: Int
        public var lapses: Int
        public var state: State
        public var lastReview: Date?

        public init(due: Date) {
            self.due = due
            stability = 0
            difficulty = 0
            reps = 0
            lapses = 0
            state = .new
            lastReview = nil
        }
    }

    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    static let decay = -0.5
    static let factor = 19.0 / 81.0
    /// Cards answered "Again" come back after this many minutes.
    public static let relearnMinutes = 10

    public var weights: [Double]
    public var desiredRetention: Double
    public var maximumIntervalDays: Int

    public init(weights: [Double] = FSRS.defaultWeights, desiredRetention: Double = 0.9, maximumIntervalDays: Int = 36500) {
        self.weights = weights
        self.desiredRetention = desiredRetention
        self.maximumIntervalDays = maximumIntervalDays
    }

    public func review(_ card: Card, rating: Rating, now: Date) -> Card {
        var next = card
        let w = weights

        if card.state == .new {
            next.stability = initialStability(rating)
            next.difficulty = initialDifficulty(rating)
        } else {
            let elapsedDays = max(0, now.timeIntervalSince(card.lastReview ?? now) / 86_400)
            if elapsedDays < 1 {
                // Same-day review (FSRS-5 short-term stability).
                next.stability = card.stability * exp(w[17] * (Double(rating.rawValue) - 3 + w[18]))
            } else {
                let r = retrievability(elapsedDays: elapsedDays, stability: card.stability)
                next.stability = rating == .again
                    ? stabilityAfterLapse(difficulty: card.difficulty, stability: card.stability, retrievability: r)
                    : stabilityAfterSuccess(difficulty: card.difficulty, stability: card.stability, retrievability: r, rating: rating)
            }
            next.difficulty = nextDifficulty(card.difficulty, rating: rating)
        }

        next.reps += 1
        next.lastReview = now
        if rating == .again {
            if card.state == .review { next.lapses += 1 }
            next.state = card.state == .review || card.state == .relearning ? .relearning : .learning
            next.due = now.addingTimeInterval(Double(Self.relearnMinutes * 60))
        } else {
            next.state = .review
            next.due = now.addingTimeInterval(Double(intervalDays(stability: next.stability)) * 86_400)
        }
        return next
    }

    // MARK: - Formulas

    public func retrievability(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + Self.factor * elapsedDays / stability, Self.decay)
    }

    public func intervalDays(stability: Double) -> Int {
        let interval = stability / Self.factor * (pow(desiredRetention, 1 / Self.decay) - 1)
        return min(max(Int(interval.rounded()), 1), maximumIntervalDays)
    }

    func initialStability(_ rating: Rating) -> Double {
        max(weights[rating.rawValue - 1], 0.1)
    }

    func initialDifficulty(_ rating: Rating) -> Double {
        clampDifficulty(weights[4] - exp(weights[5] * Double(rating.rawValue - 1)) + 1)
    }

    func nextDifficulty(_ difficulty: Double, rating: Rating) -> Double {
        let delta = -weights[6] * Double(rating.rawValue - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        let reverted = weights[7] * initialDifficulty(.easy) + (1 - weights[7]) * damped
        return clampDifficulty(reverted)
    }

    func stabilityAfterSuccess(difficulty: Double, stability: Double, retrievability: Double, rating: Rating) -> Double {
        let w = weights
        let hardPenalty = rating == .hard ? w[15] : 1
        let easyBonus = rating == .easy ? w[16] : 1
        return stability * (exp(w[8]) * (11 - difficulty) * pow(stability, -w[9])
            * (exp(w[10] * (1 - retrievability)) - 1) * hardPenalty * easyBonus + 1)
    }

    func stabilityAfterLapse(difficulty: Double, stability: Double, retrievability: Double) -> Double {
        let w = weights
        let lapsed = w[11] * pow(difficulty, -w[12]) * (pow(stability + 1, w[13]) - 1) * exp(w[14] * (1 - retrievability))
        return min(lapsed, stability)
    }

    private func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }
}
