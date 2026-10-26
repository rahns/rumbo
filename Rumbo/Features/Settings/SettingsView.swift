import RumboCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                if let profile = model.profile {
                    sections(profile)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Start over?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete everything and start again", role: .destructive) { model.reset() }
            } message: {
                Text("Your streak, XP and history will be deleted. You'll go through onboarding again.")
            }
        }
    }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        Section("Sources") {
            ForEach(SourceKind.allCases, id: \.self) { source in
                Toggle(SourceCopy.name(source), isOn: binding(
                    get: { profile.enabledSources.contains(source) },
                    set: { on in
                        var sources = profile.enabledSources
                        if on { sources.insert(source) } else { sources.remove(source) }
                        profile.enabledSources = sources
                    }
                ))
            }
        }

        Section {
            Toggle("Travel mode", isOn: binding(get: { profile.travelMode }, set: { profile.travelMode = $0 }))
        } footer: {
            Text("Prefers tasks that work offline and adds real-world missions.")
        }

        Section("Progress") {
            Stepper("Dreaming Spanish: \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)", value: binding(
                get: { profile.dsDifficultyLow },
                set: { low in profile.dsDifficulty = max(0, low)...(max(0, low) + OnboardingDraft.dreamingDifficultyWidth) }
            ), in: 0...100)
            Stepper("Language Transfer: track \(profile.languageTransferLastTrack)", value: binding(
                get: { profile.languageTransferLastTrack },
                set: { profile.languageTransferLastTrack = $0; profile.languageTransferRepeatPending = false }
            ), in: 0...Course.languageTransferTracks)
            Stepper("Extra en Español: \(profile.extraEpisodesWatched) episodes", value: binding(
                get: { profile.extraEpisodesWatched },
                set: { profile.extraEpisodesWatched = $0; profile.extraPartsDoneInEpisode = 0 }
            ), in: 0...Course.extraEpisodes)
            if profile.band >= .b2_1 && profile.band < .b2_2 {
                Toggle("Keep a Duolingo warm-up", isOn: binding(get: { profile.keepDuolingoInB2 }, set: { profile.keepDuolingoInB2 = $0 }))
            }
        }

        Section {
            if profile.speakingStage < .calls {
                Button(profile.speakingStage == .text ? "I'm ready for voice notes" : "I'm ready for live calls") {
                    model.unlockNextSpeakingStage()
                }
            } else {
                Text("Live calls unlocked")
            }
        } header: {
            Text("Speaking")
        } footer: {
            Text("Rumbo unlocks these automatically as your hours and Tandem exchanges grow. You can go early if you feel ready.")
        }

        Section("Habit") {
            Picker("Weekly goal", selection: binding(get: { profile.weeklyGoalMinutes }, set: { profile.weeklyGoalMinutes = $0 })) {
                ForEach(OnboardingDraft.weeklyGoals, id: \.self) { Text("\($0) min").tag($0) }
            }
            Toggle("Daily reminder", isOn: binding(
                get: { profile.reminderEnabled },
                set: { on in
                    profile.reminderEnabled = on
                    if on { Task { _ = await Reminders.requestPermission() } }
                    Reminders.schedule(for: profile)
                }
            ))
            if profile.reminderEnabled {
                DatePicker("Time", selection: binding(
                    get: { Calendar.current.date(from: DateComponents(hour: profile.reminderHour, minute: profile.reminderMinute)) ?? .now },
                    set: { date in
                        profile.reminderHour = Calendar.current.component(.hour, from: date)
                        profile.reminderMinute = Calendar.current.component(.minute, from: date)
                        Reminders.schedule(for: profile)
                    }
                ), displayedComponents: .hourAndMinute)
            }
        }

        Section {
            NavigationLink("Diagnostics") { DiagnosticsView() }
            Button("Start over", role: .destructive) { confirmingReset = true }
        } footer: {
            Text("Rumbo \(DiagnosticsModel.appVersion)")
        }
    }

    /// A binding that saves through the app model, so every change persists and refreshes views.
    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { value in
            set(value)
            model.save()
        })
    }
}
