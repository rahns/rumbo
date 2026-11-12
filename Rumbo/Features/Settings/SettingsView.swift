import RumboCore
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false
    /// The second, final check before a language's progress is deleted.
    @State private var confirmingDeleteForGood = false
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
            .sheet(item: $sourceInfo) { SourceInfoSheet(source: $0) }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        // Settings for the language being learned: each language has its own.
        groupHeader("Settings for \(profile.pack.name) \(profile.pack.flag)", switcher: true)
        Section {
            ForEach(profile.pack.roles, id: \.self) { source in
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
            Text("Adds a real-world \(profile.pack.name) mission to every day's plan." + (model.canChangeBudget ? "" : " Today's plan has started, so this applies from tomorrow."))
        }

        // One row per source the language has, each in that source's own terms.
        Section("Progress") {
            let pack = profile.pack
            if let graded = pack.graded {
                // A window (e.g. 40–45) that slides by 1 per tap.
                Stepper("\(SourceCopy.name(.gradedVideo)): \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)", value: binding(
                    get: { profile.dsDifficultyLow },
                    set: { low in
                        let low = max(graded.scale.lowerBound, low)
                        profile.dsDifficulty = low...(low + graded.windowWidth)
                    }
                ), in: graded.scale.lowerBound...(graded.scale.upperBound - graded.windowWidth))
            }
            if let course = pack.course {
                // The last track finished, like the series' "seen": finishing 13 means you're up to 14.
                Stepper(profile.languageTransferLastTrack == 0
                        ? "\(SourceCopy.name(.audioCourse)): not started"
                        : "\(SourceCopy.name(.audioCourse)): finished Track \(profile.languageTransferLastTrack)", value: binding(
                    get: { profile.languageTransferLastTrack },
                    set: { profile.languageTransferLastTrack = $0; profile.languageTransferRepeatPending = false }
                ), in: 0...course.tracks)
            }
            if let drill = pack.drill {
                // Section and unit as two full steppers in one row, so they read as one entry.
                VStack(alignment: .leading, spacing: 16) {
                    Text(SourceCopy.name(.drillApp))
                    Stepper(value: binding(get: { profile.duolingoSection }, set: { profile.duolingoSection = $0 }), in: drill.sections) {
                        Text("Section \(profile.duolingoSection)").foregroundStyle(Palette.secondaryText)
                    }
                    Stepper(value: binding(get: { profile.duolingoUnit }, set: { profile.duolingoUnit = $0 }), in: drill.units) {
                        Text("Unit \(profile.duolingoUnit)").foregroundStyle(Palette.secondaryText)
                    }
                }
                .padding(.vertical, 2)
            }
            if let series = pack.series {
                // One step = one part (an episode is watched in parts at the early levels), so a half-watched episode can be set.
                Stepper(seriesProgressLabel(profile, series), value: binding(
                    get: { profile.extraEpisodesWatched * series.intensiveParts + profile.extraPartsDoneInEpisode },
                    set: { parts in
                        profile.extraEpisodesWatched = parts / series.intensiveParts
                        profile.extraPartsDoneInEpisode = parts % series.intensiveParts
                    }
                ), in: 0...(series.episodes * series.intensiveParts))
            }
            if let drill = pack.drill, profile.band == drill.optionalBand {
                Toggle("Keep a \(SourceCopy.name(.drillApp)) warm-up", isOn: binding(get: { profile.keepDuolingoInB2 }, set: { profile.keepDuolingoInB2 = $0 }))
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
            Text("Rumbo switches these on by itself as your hours and \(profile.pack.sources[.exchange]?.shortName ?? "partner") exchanges grow, and you can go early if you feel ready. Switch one off and it stays off until you switch it back on.")
        }
        Section("Habit") {
            if profile.pack.has(.drillApp) {
                Toggle(isOn: binding(get: { profile.alwaysIncludeDuolingo }, set: { profile.alwaysIncludeDuolingo = $0; model.replanTodayIfNotStarted() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always include \(SourceCopy.name(.drillApp))")
                        Text("If you're keeping a streak going")
                            .font(.rounded(.caption, weight: .medium))
                            .foregroundStyle(Palette.secondaryText)
                    }
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
            // With another language set up, starting over deletes this one and switches back to that one.
            let current = profile.pack.name
            let fallback = model.profiles.first { $0.languageCode != profile.languageCode }?.pack.name
            Button(fallback.map { "Delete \(current) progress and switch back to \($0)" } ?? "Start over", role: .destructive) {
                confirmingReset = true
            }
            .confirmationDialog(fallback == nil ? "Start over?" : "Delete \(current) progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button(fallback.map { "Delete \(current) and switch to \($0)" } ?? "Delete everything and start again", role: .destructive) {
                    // Once the sheet has gone, one last check that says exactly what will be lost.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { confirmingDeleteForGood = true }
                }
            } message: {
                // The leading line break gives the message a little room under the title.
                Text("\n" + (fallback.map { "Your \(current) streak, hours and history will be deleted. Your \($0) progress stays as it is." }
                     ?? "Your streak, hours and history for \(current) will be deleted. You'll go through onboarding again."))
            }
            .alert("Are you sure?", isPresented: $confirmingDeleteForGood) {
                Button("Save a backup first") { saveBackup() }
                Button("Delete \(current) for good", role: .destructive) { model.reset() }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(lossSummary(profile) + " This can't be undone. Save a backup first so you can bring it all back later.")
            }
        }
        // Settings shared by every language.
        groupHeader("Settings across all languages", switcher: false)
        Section {
            if LanguagePack.all.count > 1 {
                // Each language has its own level, plan, goal and streak. One without a profile yet starts its setup.
                Picker("Learning", selection: Binding(get: { model.languageCode }, set: { model.setLanguage($0, announce: true) })) {
                    ForEach(LanguagePack.all) { pack in
                        Text(pack.name).tag(pack.code)
                    }
                }
            } else {
                LabeledContent("Learning", value: profile.pack.name)
            }
        } header: {
            Text("Language")
        } footer: {
            Text(LanguagePack.all.count > 1
                 ? "Each language keeps its own level, plan, goal and streak."
                 : "More languages are on the way\(LanguagePack.upcoming.first.map { ": \($0) is next" } ?? "").")
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
            Button("Save backup", systemImage: "square.and.arrow.down") { saveBackup() }
            Button("Restore from a backup", systemImage: "arrow.counterclockwise") { importing = true }
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
        } header: {
            Text("Backup")
        } footer: {
            Text("Saves one file you can keep in iCloud Drive. Restoring replaces everything in Rumbo with the file's contents.")
        }
        Section {
            ShareLink(item: URL(string: "https://github.com/rahns/rumbo/releases/latest")!,
                      subject: Text("Rumbo"),
                      message: Text("I'm using Rumbo to plan my \(profile.pack.name). Download it here (you sign it with your own certificate):")) {
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

    /// A small heading over a group of sections. For the language being learned, a Switch menu beside it
    /// changes language without scrolling down to the Language picker.
    private func groupHeader(_ title: String, switcher: Bool) -> some View {
        Section {
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(Palette.secondaryText)
                Spacer(minLength: 8)
                if switcher, LanguagePack.all.count > 1 {
                    Menu {
                        ForEach(LanguagePack.all.filter { $0.code != model.languageCode }) { pack in
                            Button("\(pack.flag) \(pack.name)") { model.setLanguage(pack.code, announce: true) }
                        }
                    } label: {
                        Label("Switch", systemImage: "arrow.left.arrow.right")
                            .font(.rounded(.subheadline, weight: .bold))
                    }
                }
            }
            // Written as is, not in the list's default uppercase.
            .textCase(nil)
            .padding(.top, 8)
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

    private func saveBackup() {
        do {
            backupDocument = try model.makeBackup()
            exporting = true
        } catch {
            message = error.localizedDescription
        }
    }

    /// What deleting the language being learned loses: "You'll lose your 12-day streak, 34 hours over
    /// 41 days of French, your A2.2 level and 18 mistake cards."
    private func lossSummary(_ profile: LearnerProfile) -> String {
        let logs = model.logs
        let days = Set(logs.map { model.calendar.startOfDay(for: $0.date) }).count
        let hours = Int((Double(logs.reduce(0) { $0 + $1.minutes }) / 60).rounded())
        let streak = model.streak.streak
        let cards = model.allCards.count
        var parts: [String] = []
        if streak > 0 { parts.append("your \(streak)-day streak") }
        if days > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours") logged over \(days) \(days == 1 ? "day" : "days")") }
        parts.append(days > 0 ? "your \(profile.band.rawValue) level and plan history" : "your setup and \(profile.band.rawValue) level")
        if cards > 0 { parts.append("\(cards) mistake \(cards == 1 ? "card" : "cards")") }
        let list = parts.count > 1 ? parts.dropLast().joined(separator: ", ") + " and " + parts.last! : parts[0]
        return "You'll lose all your \(profile.pack.name) progress: \(list)."
    }

    /// The last part seen: "Extra en Español: seen Ep 3 Part 2" (or "not started").
    private func seriesProgressLabel(_ profile: LearnerProfile, _ series: LearnerSeries) -> String {
        let name = SourceCopy.name(.learnerSeries)
        let parts = profile.extraEpisodesWatched * series.intensiveParts + profile.extraPartsDoneInEpisode
        guard parts > 0 else { return "\(name): not started" }
        let episode = (parts - 1) / series.intensiveParts + 1
        let part = (parts - 1) % series.intensiveParts + 1
        return "\(name): seen Ep \(episode) Part \(part)"
    }

    /// A binding that saves through the app model, so every change persists and refreshes views.
    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { value in
            set(value)
            model.save()
        })
    }
}

