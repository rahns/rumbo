import Foundation
import Security

/// What the widgets show, written by the app whenever something changes and read by the widget
/// extension. Shared through the Keychain's default group (App Groups aren't available with the
/// author's signing profile; see docs/05-architecture.md §5.7), with the App Group as a fallback.
struct WidgetSnapshot: Codable, Equatable {
    struct TaskLine: Codable, Equatable {
        var title: String
        var symbol: String
        var minutes: Int
        var done: Bool
        var colorHex: UInt32
        /// A "Keep going" task done after the plan was complete. Optional so older snapshots still decode.
        var isExtra: Bool? = nil
    }

    /// Extras done today after finishing the plan.
    var extrasDone: Int { tasks.filter { $0.isExtra == true && $0.done }.count }

    var updated: Date
    var day: Date
    var streak: Int
    var minutesThisWeek: Int
    var weeklyGoal: Int
    var bandLabel: String
    var dayComplete: Bool
    var hasPlan: Bool
    var tasks: [TaskLine]
    /// "hovering", "sleepy" or "backpacker".
    var mood: String
    /// With no plan yet: the budget that keeps the weekly goal on track. `tasks` then previews its plan.
    var suggestedMinutes: Int? = nil

    var isSuggestion: Bool { !hasPlan && suggestedMinutes != nil && !tasks.isEmpty }

    /// Tapping a suggestion picks that time and opens Today; otherwise it just opens Today.
    var tapURL: URL? {
        if isSuggestion, let suggestedMinutes { return URL(string: "rumbo://plan?minutes=\(suggestedMinutes)") }
        return URL(string: "rumbo://today")
    }

    static let placeholder = WidgetSnapshot(
        updated: .now, day: Calendar.current.startOfDay(for: .now), streak: 5, minutesThisWeek: 85, weeklyGoal: 150,
        bandLabel: "Explorador · A2.1", dayComplete: false, hasPlan: true,
        tasks: [
            TaskLine(title: "Duolingo warm-up", symbol: "bolt.fill", minutes: 5, done: true, colorHex: 0x5BC236),
            TaskLine(title: "Language Transfer", symbol: "headphones", minutes: 10, done: false, colorHex: 0x5BC236),
            TaskLine(title: "Dreaming Spanish", symbol: "play.tv.fill", minutes: 15, done: false, colorHex: 0xF25C4A),
        ],
        mood: "hovering"
    )

    /// The snapshot as of `date`: yesterday's plan doesn't carry over into today.
    func current(at date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        guard !calendar.isDate(day, inSameDayAs: date) else { return self }
        var fresh = self
        fresh.day = calendar.startOfDay(for: date)
        fresh.dayComplete = false
        fresh.hasPlan = false
        fresh.tasks = []
        fresh.suggestedMinutes = nil
        return fresh
    }

    var nextTask: TaskLine? { tasks.first { !$0.done } }

    private static let key = "widget.snapshot"

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        KeychainShare.write(data, forKey: Self.key)
        SharedStore.defaults?.set(data, forKey: Self.key)
    }

    static func load() -> WidgetSnapshot? {
        let data = KeychainShare.read(forKey: key).data ?? SharedStore.defaults?.data(forKey: key)
        return data.flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }
}
