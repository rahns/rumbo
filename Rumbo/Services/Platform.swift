import ActivityKit
import Foundation
import RumboCore
import UIKit
import UserNotifications

/// The task timer on the Lock Screen and in the Dynamic Island.
enum LiveActivities {
    /// A forgotten timer greys out this long after its planned end.
    static let staleAfter: TimeInterval = 30 * 60

    /// Shows the timer for `task` (replacing any other), picking up its elapsed time and pause state.
    static func start(task: PlannedTaskRecord) {
        let attributes = RumboTimerAttributes(
            taskTitle: TaskCopy.title(for: task.task),
            sourceSymbol: TaskCopy.symbol(for: task.task),
            colorHex: task.task.strand.hex
        )
        let content = self.content(for: task)
        Task {
            await endAllNow()
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: attributes, content: content)
        }
    }

    /// Refreshes the running timer after a pause or resume.
    static func update(task: PlannedTaskRecord) {
        let content = self.content(for: task)
        Task {
            for activity in Activity<RumboTimerAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func endAll() {
        Task { await endAllNow() }
    }

    static func endAllNow() async {
        for activity in Activity<RumboTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// For app termination: waits (briefly) until the timers are gone, since the process is about to end.
    static func endAllBlocking() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await endAllNow()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    private static func content(for task: PlannedTaskRecord) -> ActivityContent<RumboTimerAttributes.ContentState> {
        let now = Date.now
        let elapsed = task.elapsed(at: now)
        let effectiveStart = now.addingTimeInterval(-elapsed)
        let endsAt = effectiveStart.addingTimeInterval(Double(task.minutesPlanned * 60))
        let state = RumboTimerAttributes.ContentState(
            startedAt: effectiveStart,
            endsAt: endsAt,
            isPaused: task.isPaused,
            pausedElapsed: elapsed
        )
        return ActivityContent(state: state, staleDate: max(endsAt, now).addingTimeInterval(staleAfter))
    }
}

/// Notifications (docs/03-experience.md §3.7): a daily reminder at the learner's time, phrased around
/// their habit cue (R13), and an evening nudge on days with nothing logged yet.
enum Reminders {
    static let dailyPrefix = "rumbo.daily."
    /// The repeating reminder older versions scheduled; removed so it doesn't double up.
    static let legacyDailyID = "rumbo.daily"
    static let nudgePrefix = "rumbo.nudge."
    static let testID = "rumbo.test"
    static let nudgeHour = 20
    static let nudgeDaysAhead = 7
    /// Daily reminders are scheduled one by one, so each day's text can differ (a freeze used overnight).
    /// Rescheduled whenever the app changes anything; 30 days covers a long break (iOS allows 64 pending).
    static let dailyDaysAhead = 30

    /// What a day's reminder says when a streak freeze covered the day before.
    struct FreezeNote {
        var streak: Int
        var freezesLeft: Int
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static var allIDs: [String] {
        [legacyDailyID] + (0..<dailyDaysAhead).map { "\(dailyPrefix)\($0)" } + (0..<nudgeDaysAhead).map { "\(nudgePrefix)\($0)" }
    }

    /// Reschedules everything. Called after anything that changes the reminder settings or today's practice.
    /// `freezeNote` says, for a day, whether a freeze will have covered the day before if nothing more is logged.
    static func refresh(for profile: LearnerProfile, practisedToday: Bool, calendar: Calendar = .current,
                        freezeNote: (Date) -> FreezeNote? = { _ in nil }) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        guard profile.reminderEnabled else { return }

        let now = Date.now
        for offset in 0..<dailyDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: day),
                  fireDate > now else { continue }
            let daily = UNMutableNotificationContent()
            if let note = freezeNote(fireDate) {
                daily.title = "🧊 A streak freeze saved your streak"
                let left = note.freezesLeft == 1 ? "1 freeze left" : "\(note.freezesLeft) freezes left"
                daily.body = "Nothing was logged yesterday, so a freeze kept your \(note.streak)-day streak alive (\(left)). "
                    + "Do a little Spanish today to keep it going: even one lesson counts. Pico has your plan ready."
            } else {
                daily.title = "¿Rumbo a dónde?"
                daily.body = "Pico has today's plan ready. Even 10 minutes counts."
            }
            daily.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            center.add(UNNotificationRequest(identifier: "\(dailyPrefix)\(offset)", content: daily,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }

        // Evening nudges for the coming week; today's is skipped once something has been logged.
        for offset in 0..<nudgeDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: nudgeHour, minute: 0, second: 0, of: day),
                  fireDate > now,
                  !(offset == 0 && practisedToday),
                  // Don't nudge before the daily reminder has even had its turn.
                  profile.reminderHour < nudgeHour
            else { continue }
            let nudge = UNMutableNotificationContent()
            nudge.title = "Pico's still awake 🌙"
            nudge.body = "Nothing logged today yet. Even one quick lesson keeps your streak going."
            nudge.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            center.add(UNNotificationRequest(identifier: "\(nudgePrefix)\(offset)", content: nudge,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }

    /// A notification in 5 seconds, to check notifications reach the phone.
    static func sendTest() async -> Bool {
        guard await requestPermission() else { return false }
        let content = UNMutableNotificationContent()
        content.title = "¡Hola! 🐦"
        content.body = "Notifications from Rumbo are working."
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: testID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        )
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }
}

/// Without a delegate, iOS hides an app's notifications while that app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

/// Opens the source app for a task, falling back to the web. Schemes confirmed on device in M0.
enum DeepLinks {
    static func url(for task: TaskKind, detail: TaskDetail) -> URL? {
        switch task {
        case .dsWatch, .dsEasy:
            return URL(string: "dreaming://")
        case .ltTrack:
            return URL(string: "languagetransfer://")
        case .duoLesson:
            return URL(string: "duolingo://")
        case .tandemText, .tandemVoice, .tandemCall:
            return URL(string: "tandem://")
        case .extraIntensive, .extraExtensive:
            let episode: Int = switch detail {
            case .extraPart(let episode, _), .extraEpisode(let episode): episode
            default: 1
            }
            let query = "Extra en Español episodio \(episode)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.youtube.com/results?search_query=\(query)")
        default:
            return nil
        }
    }

    static func webFallback(for task: TaskKind) -> URL? {
        switch task {
        case .dsWatch, .dsEasy: URL(string: "https://www.dreaming.com/spanish")
        case .ltTrack: URL(string: "https://www.languagetransfer.org")
        case .duoLesson: URL(string: "https://www.duolingo.com")
        case .tandemText, .tandemVoice, .tandemCall: URL(string: "https://www.tandem.net")
        default: nil
        }
    }

    @MainActor
    static func open(_ task: TaskKind, detail: TaskDetail) {
        guard let url = url(for: task, detail: detail) else { return }
        UIApplication.shared.open(url) { opened in
            if !opened, let fallback = webFallback(for: task) {
                UIApplication.shared.open(fallback)
            }
        }
    }
}
