import ActivityKit
import Foundation
import RumboCore
import UIKit
import UserNotifications

/// The task timer on the Lock Screen and in the Dynamic Island.
enum LiveActivities {
    static func start(task: PlannedTaskRecord) {
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date.now
        let attributes = RumboTimerAttributes(
            taskTitle: TaskCopy.title(for: task.task),
            sourceSymbol: TaskCopy.symbol(for: task.task)
        )
        let state = RumboTimerAttributes.ContentState(
            startedAt: now,
            endsAt: now.addingTimeInterval(Double(task.minutesPlanned * 60))
        )
        _ = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
    }

    static func endAll() {
        Task {
            for activity in Activity<RumboTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

/// One gentle daily reminder at the learner's chosen time, phrased around their habit cue (R13).
enum Reminders {
    static let identifier = "rumbo.daily"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(for profile: LearnerProfile) {
        cancel()
        guard profile.reminderEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "¿Rumbo a dónde?"
        let cue = profile.habitCue.trimmingCharacters(in: .whitespaces)
        content.body = cue.isEmpty
            ? "Pico has today's plan ready. Even 10 minutes counts."
            : "\(cue): time for Spanish with Pico. Even 10 minutes counts."
        content.sound = .default
        var components = DateComponents()
        components.hour = profile.reminderHour
        components.minute = profile.reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
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
