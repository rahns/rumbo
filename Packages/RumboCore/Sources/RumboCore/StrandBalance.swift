import Foundation

/// A custom split of the day's practice between the four strands (Settings → Plan balance), in whole
/// percentages that add up to 100, in steps of 5. Without one, the plan uses the band's research-based
/// split (`Band.strandTargets`). See docs/02-learning-engine.md §2.5.
public struct StrandBalance: Codable, Equatable, Sendable {
    public static let step = 5

    public private(set) var percents: [Strand: Int]

    /// The band's split, rounded to steps of 5.
    public init(band: Band) {
        self.init(shares: band.strandTargets)
    }

    /// Any shares (they needn't add up to anything): scaled to 100 in steps of 5.
    public init(shares: [Strand: Double]) {
        percents = Self.rounded(shares, total: 100)
    }

    public subscript(strand: Strand) -> Int { percents[strand] ?? 0 }

    /// The plan's targets, as fractions of the day.
    public var targets: [Strand: Double] {
        Dictionary(uniqueKeysWithValues: Strand.allCases.map { ($0, Double(self[$0]) / 100) })
    }

    /// Sets one strand (clamped to 0–100, in steps of 5) and scales the others to fill the rest,
    /// keeping their proportions to each other. If they were all 0, the rest is shared evenly.
    public mutating func set(_ strand: Strand, to percent: Int) {
        let value = min(max(Int((Double(percent) / Double(Self.step)).rounded()) * Self.step, 0), 100)
        let others = Strand.allCases.filter { $0 != strand }
        var shares = Dictionary(uniqueKeysWithValues: others.map { ($0, Double(self[$0])) })
        if shares.values.reduce(0, +) == 0 { shares = Dictionary(uniqueKeysWithValues: others.map { ($0, 1) }) }
        var updated = Self.rounded(shares, total: 100 - value)
        updated[strand] = value
        percents = updated
    }

    /// Scales `shares` to `total` in steps of 5: each gets its rounded-down share, and the steps left over
    /// go to the largest remainders (ties in strand order).
    static func rounded(_ shares: [Strand: Double], total: Int) -> [Strand: Int] {
        let strands = Strand.allCases.filter { shares[$0] != nil }
        let sum = strands.reduce(0) { $0 + max(shares[$1] ?? 0, 0) }
        let steps = total / step
        guard sum > 0, !strands.isEmpty else {
            return Dictionary(uniqueKeysWithValues: strands.map { ($0, 0) })
        }
        let exact = strands.map { max(shares[$0] ?? 0, 0) / sum * Double(steps) }
        var whole = exact.map { Int($0.rounded(.down)) }
        let order = exact.indices.sorted { (exact[$0] - Double(whole[$0])) > (exact[$1] - Double(whole[$1])) }
        for index in order.prefix(steps - whole.reduce(0, +)) { whole[index] += 1 }
        return Dictionary(uniqueKeysWithValues: zip(strands, whole.map { $0 * step }))
    }
}
