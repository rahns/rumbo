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
            NavigationLink {
                GoalSettingsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.targetDate.map { "\(profile.goal) by \($0.formatted(.dateTime.month(.abbreviated).year()))" } ?? profile.goal)
                        .font(.rounded(.body, weight: .bold))
                    Text("\(profile.weeklyGoalMinutes) min a week")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        } header: {
            Text("Goal")
        } footer: {
            Text("Your level goal, weekly minutes and target date. Change the weekly goal and the date follows, or the other way round.")
        }

        Section {
            Toggle("Travel mode", isOn: binding(get: { profile.travelMode }, set: { profile.travelMode = $0 }))
        } footer: {
            Text("Adds real-world missions and copes with no signal.")
        }

        Section("Progress") {
            // A 5-point window (e.g. 40–45) that slides by 1 per tap.
            Stepper("Dreaming Spanish: \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)", value: binding(
                get: { profile.dsDifficultyLow },
                set: { low in profile.dsDifficulty = max(0, low)...(max(0, low) + LearnerProfile.dreamingRangeWidth) }
            ), in: 0...(100 - LearnerProfile.dreamingRangeWidth))
            Stepper("Language Transfer: track \(profile.languageTransferLastTrack)", value: binding(
                get: { profile.languageTransferLastTrack },
                set: { profile.languageTransferLastTrack = $0; profile.languageTransferRepeatPending = false }
            ), in: 0...Course.languageTransferTracks)
            Stepper("Duolingo: section \(profile.duolingoSection)", value: binding(
                get: { profile.duolingoSection },
                set: { profile.duolingoSection = $0 }
            ), in: 1...10)
            Stepper("Duolingo: unit \(profile.duolingoUnit)", value: binding(
                get: { profile.duolingoUnit },
                set: { profile.duolingoUnit = $0 }
            ), in: 1...300)
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
            Picker("Week starts on", selection: Binding(
                get: { profile.weekStartsOnSunday },
                set: { model.setWeekStartsOnSunday($0) }
            )) {
                Text("Monday").tag(false)
                Text("Sunday").tag(true)
            }
            Toggle("Daily reminder", isOn: binding(
                get: { profile.reminderEnabled },
                set: { on in
                    profile.reminderEnabled = on
                    Task {
                        if on { _ = await Reminders.requestPermission() }
                        model.refreshReminders()
                    }
                }
            ))
            if profile.reminderEnabled {
                DatePicker("Time", selection: binding(
                    get: { Calendar.current.date(from: DateComponents(hour: profile.reminderHour, minute: profile.reminderMinute)) ?? .now },
                    set: { date in
                        profile.reminderHour = Calendar.current.component(.hour, from: date)
                        profile.reminderMinute = Calendar.current.component(.minute, from: date)
                        model.refreshReminders()
                    }
                ), displayedComponents: .hourAndMinute)
            }
            Button("Send a test notification", systemImage: "bell.badge") {
                Task {
                    let allowed = await Reminders.sendTest()
                    message = allowed
                        ? "A test notification arrives in 5 seconds. It shows even with Rumbo open."
                        : "Notifications are off for Rumbo. Turn them on in the iPhone's Settings → Notifications → Rumbo."
                }
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
            ShareLink(item: URL(string: "https://github.com/rahns/rumbo/releases/latest")!,
                      subject: Text("Rumbo"),
                      message: Text("I'm using Rumbo to plan my Spanish. Download it here (you sign it with your own certificate):")) {
                Label("Share Rumbo with a friend", systemImage: "square.and.arrow.up")
            }
            Link(destination: URL(string: "https://github.com/rahns/rumbo/releases")!) {
                Label("Downloads and what's new", systemImage: "arrow.down.circle")
            }
        } header: {
            Text("Share")
        } footer: {
            Text("Friends get their own setup: Rumbo asks where they are in each source on first launch.")
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
