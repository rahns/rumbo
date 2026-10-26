import RumboCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false
    @State private var backupDocument: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: Data?
    @State private var message: String?

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
            .fileExporter(isPresented: $exporting, document: backupDocument, contentType: .json, defaultFilename: BackupDocument.defaultFilename()) { result in
                switch result {
                case .success(let url): message = "Saved \(url.lastPathComponent)."
                case .failure(let error): message = "Couldn't save the backup: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $importing) {
                BackupImportPicker { result in
                    importing = false
                    switch result {
                    case .success(let data): pendingRestore = data
                    case .failure(let error): message = "Couldn't read that file: \(error.localizedDescription)"
                    case nil: break
                    }
                }
                .ignoresSafeArea()
            }
            .confirmationDialog("Restore this backup?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }), titleVisibility: .visible) {
                Button("Replace my data with the backup", role: .destructive) {
                    guard let data = pendingRestore else { return }
                    pendingRestore = nil
                    do {
                        try model.restore(from: data)
                        message = "Backup restored."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            } message: {
                Text("Everything in Rumbo now will be replaced by what's in the file.")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
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
            Button("Save backup", systemImage: "square.and.arrow.down") {
                do {
                    backupDocument = try model.makeBackup()
                    exporting = true
                } catch {
                    message = error.localizedDescription
                }
            }
            Button("Restore from a backup", systemImage: "arrow.counterclockwise") { importing = true }
        } header: {
            Text("Backup")
        } footer: {
            Text("Saves one file you can keep in iCloud Drive. Restoring replaces everything in Rumbo with the file's contents.")
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
