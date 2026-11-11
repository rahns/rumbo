import RumboCore
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false
    @State private var backupDocument: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: Data?
    @State private var message: String?
    @State private var sourceInfo: SourceKind?
    /// "Gemini, then Groq", "Groq" or "Not set up".
    @State private var checkers = SettingsView.checkersText()

    var body: some View {
        NavigationStack {
            Form {
                if let profile = model.profile {
                    Group { sections(profile) }
                        .rumboRows()
                }
            }
            .rumboListBackground()
            .navigationTitle("Settings")
            .confirmationDialog("Start over?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete everything and start again", role: .destructive) { model.reset() }
            } message: {
                Text("Your streak, hours and history will be deleted. You'll go through onboarding again.")
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
                        checkers = SettingsView.checkersText()
                        message = "Backup restored."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            } message: {
                Text("Everything in Rumbo now will be replaced by what's in the file.")
            }
            .sheet(item: $sourceInfo) { SourceInfoSheet(source: $0) }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        Section {
            ForEach(SourceKind.allCases, id: \.self) { source in
                HStack {
                    // The name opens what the source is; the switch turns it on or off.
                    Button {
                        sourceInfo = source
                    } label: {
                        HStack(spacing: 6) {
                            Text(SourceCopy.name(source)).foregroundStyle(Palette.ink)
                            Image(systemName: "info.circle")
                                .font(.rounded(.caption, weight: .bold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Toggle(SourceCopy.name(source), isOn: binding(
                        get: { profile.enabledSources.contains(source) },
                        set: { on in
                            var sources = profile.enabledSources
                            if on { sources.insert(source) } else { sources.remove(source) }
                            profile.enabledSources = sources
                        }
                    ))
                    .labelsHidden()
                }
            }
        } header: {
            Text("Sources")
        } footer: {
            Text("Tap a source to see what it is and where to find it.")
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
            NavigationLink {
                GeminiSettingsView { _ in checkers = SettingsView.checkersText() }
            } label: {
                LabeledContent("AI checkers", value: checkers)
            }
        } header: {
            Text("Writing feedback")
        } footer: {
            Text("Pico checks your writing with Gemini and/or GroqCloud, both free with your own keys: your default first, then the other. Without either, a basic checker is used.")
        }

        Section {
            NavigationLink {
                LessonSettingsView()
            } label: {
                LabeledContent("Classes/Tutoring", value: profile.lessonSchedule.summary(weekStartsOnSunday: profile.weekStartsOnSunday))
            }
        } header: {
            Text("Classes/Tutoring")
        } footer: {
            Text("A tutor or a class on set days: it's always in that day's plan, at its usual length.")
        }

        Section {
            Toggle("Custom plan balance", isOn: binding(
                get: { profile.strandBalance != nil },
                set: { on in
                    profile.strandBalance = on ? StrandBalance(band: profile.band) : nil
                    model.replanTodayIfNotStarted()
                }
            ))
            if let balance = profile.strandBalance {
                NavigationLink {
                    PlanBalanceView()
                } label: {
                    HStack(spacing: 10) {
                        Text("Plan balance")
                        Spacer()
                        // The split at a glance, each share in its strand's colour.
                        HStack(spacing: 6) {
                            ForEach([Strand.input, .languageFocused, .output, .fluency], id: \.self) { strand in
                                Text("\(balance[strand])")
                                    .font(.rounded(.subheadline, weight: .black))
                                    .foregroundStyle(strand.color)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        } footer: {
            Text(profile.strandBalance == nil
                 ? "Rumbo splits each day between listening, grammar & vocab, speaking & writing and fluency by your level. Switch this on to set your own split."
                 : "Your own split between listening, grammar & vocab, speaking & writing and fluency (%).")
        }

        Section {
            Toggle("Travel mode", isOn: Binding(get: { profile.travelMode }, set: { model.setTravelMode($0) }))
        } footer: {
            Text("Adds a real-world Spanish mission to every day's plan." + (model.canChangeBudget ? "" : " Today's plan has started, so this applies from tomorrow."))
        }

        Section("Progress") {
            // A 5-point window (e.g. 40–45) that slides by 1 per tap.
            Stepper("Dreaming Spanish: \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)", value: binding(
                get: { profile.dsDifficultyLow },
                set: { low in profile.dsDifficulty = max(0, low)...(max(0, low) + LearnerProfile.dreamingRangeWidth) }
            ), in: 0...(100 - LearnerProfile.dreamingRangeWidth))
            // The last track finished, like Extra's "seen": finishing 13 means you're up to 14.
            Stepper(profile.languageTransferLastTrack == 0
                    ? "Language Transfer: not started"
                    : "Language Transfer: finished Track \(profile.languageTransferLastTrack)", value: binding(
                get: { profile.languageTransferLastTrack },
                set: { profile.languageTransferLastTrack = $0; profile.languageTransferRepeatPending = false }
            ), in: 0...Course.languageTransferTracks)
            // Section and unit as two full steppers in one row, so they read as one Duolingo entry.
            VStack(alignment: .leading, spacing: 16) {
                Text("Duolingo")
                Stepper(value: binding(get: { profile.duolingoSection }, set: { profile.duolingoSection = $0 }), in: 1...10) {
                    Text("Section \(profile.duolingoSection)").foregroundStyle(Palette.secondaryText)
                }
                Stepper(value: binding(get: { profile.duolingoUnit }, set: { profile.duolingoUnit = $0 }), in: 1...300) {
                    Text("Unit \(profile.duolingoUnit)").foregroundStyle(Palette.secondaryText)
                }
            }
            .padding(.vertical, 2)
            // One step = one part (each episode is two parts), so a half-watched episode can be set.
            Stepper(extraProgressLabel(profile), value: binding(
                get: { profile.extraEpisodesWatched * Course.extraIntensivePartsPerEpisode + profile.extraPartsDoneInEpisode },
                set: { parts in
                    profile.extraEpisodesWatched = parts / Course.extraIntensivePartsPerEpisode
                    profile.extraPartsDoneInEpisode = parts % Course.extraIntensivePartsPerEpisode
                }
            ), in: 0...(Course.extraEpisodes * Course.extraIntensivePartsPerEpisode))
            if profile.band >= .b2_1 && profile.band < .b2_2 {
                Toggle("Keep a Duolingo warm-up", isOn: binding(get: { profile.keepDuolingoInB2 }, set: { profile.keepDuolingoInB2 = $0 }))
            }
        }

        Section {
            Toggle("I'm ready for voice notes", isOn: binding(
                get: { profile.speakingStage >= .voiceNotes },
                set: { model.setSpeakingStage(.voiceNotes, on: $0) }
            ))
            Toggle("I'm ready for live calls", isOn: binding(
                get: { profile.speakingStage >= .calls },
                set: { model.setSpeakingStage(.calls, on: $0) }
            ))
            .disabled(profile.speakingStage < .voiceNotes)
        } header: {
            Text("Speaking")
        } footer: {
            Text("Rumbo switches these on by itself as your hours and Tandem/HelloTalk exchanges grow, and you can go early if you feel ready. Switch one off and it stays off until you switch it back on.")
        }

        Section("Habit") {
            Toggle(isOn: binding(get: { profile.alwaysIncludeDuolingo }, set: { profile.alwaysIncludeDuolingo = $0; model.replanTodayIfNotStarted() })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Always include Duolingo")
                    Text("If you're keeping a streak going")
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
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
            Link(destination: Self.feedbackEmail) {
                Label("Report a bug or suggest something", systemImage: "envelope")
            }
        } header: {
            Text("Share")
        }

        Section {
            NavigationLink("Diagnostics") { DiagnosticsView() }
            Button("Start over", role: .destructive) { confirmingReset = true }
        } footer: {
            VStack(spacing: 4) {
                Text("Rumbo \(DiagnosticsModel.appVersion)")
                Text("Made out of necessity (and with ❤️) by Rahn")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            // A little room between the credit and the tab bar.
            .padding(.bottom, 24)
        }
    }

    /// A new email to Rahn in the Mail app, with the app and iOS version filled in for bug reports.
    static var feedbackEmail: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "contact@rahnstavar.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Rumbo feedback"),
            URLQueryItem(name: "body", value: "\n\n\n— Rumbo \(DiagnosticsModel.appVersion) · iOS \(UIDevice.current.systemVersion)"),
        ]
        return components.url ?? URL(string: "mailto:contact@rahnstavar.com")!
    }

    static func checkersText() -> String { WritingCheckers.summary }

    /// The last part seen: "Extra en Español: seen Ep 3 Part 2" (or "not started").
    private func extraProgressLabel(_ profile: LearnerProfile) -> String {
        let parts = profile.extraEpisodesWatched * Course.extraIntensivePartsPerEpisode + profile.extraPartsDoneInEpisode
        guard parts > 0 else { return "Extra en Español: not started" }
        let episode = (parts - 1) / Course.extraIntensivePartsPerEpisode + 1
        let part = (parts - 1) % Course.extraIntensivePartsPerEpisode + 1
        return "Extra en Español: seen Ep \(episode) Part \(part)"
    }

    /// A binding that saves through the app model, so every change persists and refreshes views.
    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { value in
            set(value)
            model.save()
        })
    }
}

