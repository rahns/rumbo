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
    /// Minutes logged that day, so Pico can turn sleepy at 8 pm without the app. Optional for older snapshots.
    var minutesToday: Int? = nil
    /// The next few days, worked out by the app ahead of time (suggested plan, week minutes, streak), so the
    /// widget is right after midnight even before the app is opened. Optional for older snapshots.
    var upcoming: [WidgetSnapshot]? = nil

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

    /// The snapshot as of `date`: the app's precomputed day if it has one, otherwise today with yesterday's
    /// plan cleared. From 8 pm with nothing logged, Pico is sleepy (as in the app).
    func current(at date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        var result: WidgetSnapshot
        if calendar.isDate(day, inSameDayAs: date) {
            result = self
        } else if let ahead = upcoming?.first(where: { calendar.isDate($0.day, inSameDayAs: date) }) {
            result = ahead
        } else {
            result = self
            result.day = calendar.startOfDay(for: date)
            result.dayComplete = false
            result.hasPlan = false
            result.tasks = []
            result.suggestedMinutes = nil
            result.minutesToday = 0
        }
        result.upcoming = nil
        if result.mood == "hovering", calendar.component(.hour, from: date) >= 20, result.minutesToday == 0 {
            result.mood = "sleepy"
        }
        return result
    }

    /// When the widget should next change by itself: 8 pm today if Pico may turn sleepy, then each midnight
    /// (and 8 pm) of the precomputed days.
    func changeDates(after now: Date, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let lastDay = upcoming?.map(\.day).max() ?? today
        let days = calendar.dateComponents([.day], from: today, to: lastDay).day ?? 0
        var dates: [Date] = []
        for offset in 0...max(days + 1, 1) {
            guard let start = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if offset > 0 { dates.append(start.addingTimeInterval(60)) }
            if offset <= days, let evening = calendar.date(bySettingHour: 20, minute: 0, second: 30, of: start) { dates.append(evening) }
        }
        return dates.filter { $0 > now }.sorted()
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
