import Foundation

/// Prompts for output tasks (PromptLibrary+*.swift). Each pick skips prompts already used (`used`: earlier
/// prompts, which may have a reuse hint appended), so nothing repeats until a list has been used up;
/// among the rest, the date decides, so the same day always shows the same prompt.
public enum Prompts {
    public enum Level: Sendable {
        case a2, b1, b2

        public init(_ band: Band) {
            switch band {
            case .a2_1, .a2_2: self = .a2
            case .b1_1, .b1_2: self = .b1
            case .b2_1, .b2_2: self = .b2
            }
        }
    }

    /// Target word range for `write.guided` (§2.3).
    public static func wordTarget(for band: Band) -> ClosedRange<Int> {
        switch Level(band) {
        case .a2: 50...100
        case .b1: 120...180
        case .b2: 200...300
        }
    }

    public static func writing(for band: Band, on date: Date, used: [String] = [], calendar: Calendar = .current) -> String {
        pick(writingPrompts[Level(band)]!, on: date, used: used, calendar: calendar)
    }

    public static func tandem(for band: Band, on date: Date, used: [String] = [], calendar: Calendar = .current) -> String {
        pick(tandemPrompts[Level(band)]!, on: date, used: used, calendar: calendar)
    }

    public static func quickWrite(on date: Date, used: [String] = [], calendar: Calendar = .current) -> String {
        pick(quickWriteTopics, on: date, used: used, calendar: calendar)
    }

    public static func fluencyStory(on date: Date, used: [String] = [], calendar: Calendar = .current) -> String {
        pick(fluencyStories, on: date, used: used, calendar: calendar)
    }

    public static func travelMission(on date: Date, used: [String] = [], calendar: Calendar = .current) -> String {
        pick(travelMissions, on: date, used: used, calendar: calendar)
    }

    static func pick(_ list: [String], on date: Date, used: [String] = [], calendar: Calendar) -> String {
        let fresh = list.filter { prompt in !used.contains { $0.hasPrefix(prompt) } }
        let pool = fresh.isEmpty ? list : fresh
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }

    static let writingPrompts: [Level: [String]] = [.a2: writingA2, .b1: writingB1, .b2: writingB2]
    static let tandemPrompts: [Level: [String]] = [.a2: tandemA2, .b1: tandemB1, .b2: tandemB2]
}
