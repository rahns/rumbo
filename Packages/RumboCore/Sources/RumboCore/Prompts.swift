import Foundation

/// Prompts for output tasks (PromptLibrary+*.swift), shared by every language. Each pick skips prompts already used (`used`: earlier
/// prompts, which may have a reuse hint appended), so nothing repeats until a list has been used up;
/// among the rest, the date decides, so the same day always shows the same prompt.
public enum Prompts {
    public enum Level: Sendable {
        case a1, a2, b1, b2

        public init(_ band: Band) {
            switch band {
            case .a1_1, .a1_2: self = .a1
            case .a2_1, .a2_2: self = .a2
            case .b1_1, .b1_2: self = .b1
            case .b2_1, .b2_2: self = .b2
            }
        }
    }

    /// Target word range for `write.guided` (§2.3).
    public static func wordTarget(for band: Band) -> ClosedRange<Int> {
        switch Level(band) {
        case .a1: 15...40
        case .a2: 50...100
        case .b1: 120...180
        case .b2: 200...300
        }
    }

    public static func writing(for band: Band, on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar = .current) -> String {
        pick(writingPrompts[Level(band)]!, on: date, used: used, pack: pack, calendar: calendar)
    }

    public static func exchange(for band: Band, on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar = .current) -> String {
        pick(exchangePrompts[Level(band)]!, on: date, used: used, pack: pack, calendar: calendar)
    }

    public static func quickWrite(on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar = .current) -> String {
        pick(quickWriteTopics, on: date, used: used, pack: pack, calendar: calendar)
    }

    public static func fluencyStory(on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar = .current) -> String {
        pick(fluencyStories, on: date, used: used, pack: pack, calendar: calendar)
    }

    public static func travelMission(on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar = .current) -> String {
        pick(travelMissions + pack.extraTravelMissions, on: date, used: used, pack: pack, calendar: calendar)
    }

    /// The lists are shared by every language, with `{language}` standing for its name; it's filled in
    /// before picking, so `used` (what the learner was shown) matches.
    static func pick(_ list: [String], on date: Date, used: [String] = [], pack: LanguagePack, calendar: Calendar) -> String {
        pick(list.map(pack.fill), on: date, used: used, calendar: calendar)
    }

    static func pick(_ list: [String], on date: Date, used: [String] = [], calendar: Calendar) -> String {
        let fresh = list.filter { prompt in !used.contains { $0.hasPrefix(prompt) } }
        let pool = fresh.isEmpty ? list : fresh
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }

    static let writingPrompts: [Level: [String]] = [.a1: writingA1, .a2: writingA2, .b1: writingB1, .b2: writingB2]
    static let exchangePrompts: [Level: [String]] = [.a1: tandemA1, .a2: tandemA2, .b1: tandemB1, .b2: tandemB2]
}
