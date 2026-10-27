import Combine
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct RumboApp: App {
    let container: ModelContainer
    @State private var model: AppModel

    init() {
        let schema = Schema([LearnerProfile.self, ActivityLog.self, DayPlanRecord.self, PlannedTaskRecord.self, WritingEntry.self, ReviewCard.self])
        // On device only: no sync, no backup (docs/04-data-model.md).
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Couldn't open the Rumbo store: \(error)")
        }
        let appModel = AppModel(context: container.mainContext)
        _model = State(initialValue: appModel)
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        TimerControl.togglePause = { appModel.togglePause() }
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.profile == nil {
                OnboardingView { draft in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        model.completeOnboarding(with: draft)
                    }
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .environment(model)
        .tint(Palette.coral)
        // Refresh when the app comes back or the day changes, so Today rolls over at midnight.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.save()
                model.refreshReminders()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.save()
        }
        // Quitting the app takes the task timer off the Lock Screen and Dynamic Island.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            LiveActivities.endAllBlocking()
        }
        .onOpenURL { model.handle($0) }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView {
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") { PathView() }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") { StatsView() }
            Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
        }
        .fullScreenCover(item: $model.finishingTask) { task in
            TaskSessionView(task: task, startLogging: true)
        }
    }
}
