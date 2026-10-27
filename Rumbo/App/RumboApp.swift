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
        RumboApp.styleNavigationBars()
        TimerControl.togglePause = { appModel.togglePause() }
    }

    /// Screen titles in SF Rounded, heavy, like the rest of the app.
    static func styleNavigationBars() {
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]]), size: base.pointSize)
        }
        // Only the title fonts change; the system's own bar backgrounds (glass) are kept.
        let bar = UINavigationBar.appearance()
        func withRoundedTitles(_ appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
            let copy = appearance.copy()
            copy.largeTitleTextAttributes[.font] = rounded(.largeTitle, .black)
            copy.titleTextAttributes[.font] = rounded(.headline, .heavy)
            return copy
        }
        bar.standardAppearance = withRoundedTitles(bar.standardAppearance)
        let edge = bar.scrollEdgeAppearance ?? {
            let transparent = UINavigationBarAppearance()
            transparent.configureWithTransparentBackground()
            return transparent
        }()
        bar.scrollEdgeAppearance = withRoundedTitles(edge)
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
        // SF Rounded everywhere, including plain Text in lists and forms (Settings, Mistakes, Diagnostics).
        .fontDesign(.rounded)
        // Refresh when the app comes back or the day changes, so Today rolls over at midnight.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.save()
                model.refreshReminders()
                Task { await model.refreshCatalog() }
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
    @State private var tab = 0

    var body: some View {
        @Bindable var model = model
        TabView(selection: $tab) {
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill", value: 0) { PathView() }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 1) { StatsView() }
            Tab("Mistakes", systemImage: "rectangle.stack.fill", value: 2) {
                NavigationStack { MistakeDeckView() }
            }
            .badge(model.dueCards.count)
            Tab("Library", systemImage: "books.vertical.fill", value: 3) { LibraryView() }
            Tab("Settings", systemImage: "gearshape.fill", value: 4) { SettingsView() }
        }
        // A widget tap (rumbo://today or rumbo://plan) brings up the Path tab, which pushes Today.
        .onChange(of: model.todayRequests) { tab = 0 }
        // Big moments play over whichever tab is showing (a task can be finished from the Live Activity).
        .overlay {
            ZStack {
                GoalReachedOverlay(trigger: model.goalReachedBursts, goal: model.profile?.weeklyGoalMinutes ?? 150)
                StreakMilestoneOverlay(milestone: model.streakMilestone)
            }
        }
        .fullScreenCover(item: $model.finishingTask) { task in
            TaskSessionView(task: task, startLogging: true)
        }
    }
}
