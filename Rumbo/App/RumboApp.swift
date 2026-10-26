import Combine
import SwiftData
import SwiftUI
import UIKit

@main
struct RumboApp: App {
    let container: ModelContainer
    @State private var model: AppModel

    init() {
        let schema = Schema([LearnerProfile.self, ActivityLog.self, DayPlanRecord.self, PlannedTaskRecord.self, WritingEntry.self])
        // On device only: no sync, no backup (docs/04-data-model.md).
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Couldn't open the Rumbo store: \(error)")
        }
        _model = State(initialValue: AppModel(context: container.mainContext))
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
            if phase == .active { model.save() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.save()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") { PathView() }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") { StatsView() }
            Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
        }
    }
}
