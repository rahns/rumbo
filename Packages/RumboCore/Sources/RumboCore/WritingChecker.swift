/// The AI services that can check writing, each with the learner's own free key (docs/05-architecture.md §5.3).
/// The learner picks which goes first; any other with a key is tried next, then the basic checker.
public enum WritingChecker: String, CaseIterable, Sendable {
    case gemini, groq

    public static let standardDefault = WritingChecker.gemini

    /// For the picker and warnings: "Gemini" or "Groq".
    public var name: String { self == .gemini ? "Gemini" : "Groq" }

    /// The order to try them in: the default first (if it has a key), then the others that have keys.
    public static func order(default first: WritingChecker, available: Set<WritingChecker>) -> [WritingChecker] {
        ([first] + allCases.filter { $0 != first }).filter(available.contains)
    }

    /// "Gemini, then Groq", "Groq" or "Not set up", for the Settings row.
    public static func summary(default first: WritingChecker, available: Set<WritingChecker>) -> String {
        let order = order(default: first, available: available)
        return order.isEmpty ? "Not set up" : order.map(\.name).joined(separator: ", then ")
    }
}
