import RumboCore
import SwiftUI

/// Settings → Lessons: which weekdays have a tutoring or classroom lesson, how long it usually is and what kind,
/// and (with more than one day) each day's own length and kind. See docs/03-experience.md "Settings".
struct LessonSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if let profile = model.profile {
                Group { sections(profile) }
                    .rumboRows()
            }
        }
        .rumboListBackground()
        .navigationTitle("Lessons")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Weekday numbers (1 = Sunday) in the order of the learner's week.
    private func weekdays(_ profile: LearnerProfile) -> [Int] {
        profile.weekStartsOnSunday ? Array(1...7) : [2, 3, 4, 5, 6, 7, 1]
    }

    private func dayName(_ weekday: Int) -> String { Calendar.current.weekdaySymbols[weekday - 1] }
    private func shortDayName(_ weekday: Int) -> String { Calendar.current.shortWeekdaySymbols[weekday - 1] }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        let schedule = profile.lessonSchedule
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 10) {
                ForEach(weekdays(profile), id: \.self) { weekday in
                    ChipButton(title: shortDayName(weekday), isSelected: schedule.days[weekday] != nil) {
                        update(profile) { schedule in
                            if schedule.days[weekday] == nil { schedule.days[weekday] = .init() } else { schedule.days[weekday] = nil }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Choose each day you have lessons")
        } footer: {
            Text("On these days a Lesson card is always in your plan. It's part of the time you pick for the day, so pick a bit more on lesson days.")
        }

        Section {
            Stepper("Usual lesson duration: \(schedule.usualMinutes) min", value: Binding(
                get: { schedule.usualMinutes },
                set: { minutes in update(profile) { $0.usualMinutes = minutes } }
            ), in: 15...180, step: 5)
            Picker("Usual lesson type", selection: Binding(
                get: { schedule.usualType },
                set: { type in update(profile) { $0.usualType = type } }
            )) {
                ForEach(LessonType.allCases, id: \.self) { Text(TaskCopy.lessonTypeName($0)).tag($0) }
            }
        } header: {
            Text("Usual lesson")
        } footer: {
            Text("The type decides which part of your practice the lesson counts toward, so the rest of the day's plan balances it. All-in-one splits the lesson's time evenly between speaking & writing, listening and grammar & vocabulary. You can change the type for a one-off lesson when you log it.")
        }

        let chosen = weekdays(profile).filter { schedule.days[$0] != nil }
        if chosen.count > 1 {
            Section {
                ForEach(chosen, id: \.self) { weekday in
                    dayRow(profile, weekday: weekday, schedule: schedule)
                }
            } header: {
                Text("Each day")
            } footer: {
                Text("Give a day its own length or type, e.g. a longer speaking class on Tuesdays and a shorter grammar lesson on Thursdays.")
            }
        }
    }

    @ViewBuilder
    private func dayRow(_ profile: LearnerProfile, weekday: Int, schedule: LessonSchedule) -> some View {
        let day = schedule.days[weekday] ?? .init()
        let custom = day.minutes != nil || day.type != nil
        let lesson = schedule.lesson(weekday: weekday)
        DisclosureGroup {
            Toggle("Same as usual", isOn: Binding(
                get: { !custom },
                set: { same in
                    update(profile) { schedule in
                        schedule.days[weekday] = same ? .init() : .init(minutes: schedule.usualMinutes, type: schedule.usualType)
                    }
                }
            ))
            if custom {
                Stepper("Duration: \(day.minutes ?? schedule.usualMinutes) min", value: Binding(
                    get: { day.minutes ?? schedule.usualMinutes },
                    set: { minutes in update(profile) { $0.days[weekday]?.minutes = minutes } }
                ), in: 15...180, step: 5)
                Picker("Type", selection: Binding(
                    get: { day.type ?? schedule.usualType },
                    set: { type in update(profile) { $0.days[weekday]?.type = type } }
                )) {
                    ForEach(LessonType.allCases, id: \.self) { Text(TaskCopy.lessonTypeName($0)).tag($0) }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName(weekday)).font(.rounded(.body, weight: .bold))
                if let lesson {
                    Text("\(lesson.minutes) min · \(TaskCopy.lessonTypeName(lesson.type))\(custom ? "" : " (usual)")")
                        .font(.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    /// Changes the schedule and saves it.
    private func update(_ profile: LearnerProfile, _ change: (inout LessonSchedule) -> Void) {
        var schedule = profile.lessonSchedule
        change(&schedule)
        profile.lessonSchedule = schedule
        model.save()
        model.replanTodayIfNotStarted()
    }
}

extension LessonSchedule {
    /// "Tue, Thu · 60 min" for the Settings row, or "None".
    func summary(weekStartsOnSunday: Bool) -> String {
        let order = weekStartsOnSunday ? Array(1...7) : [2, 3, 4, 5, 6, 7, 1]
        let days = order.filter { self.days[$0] != nil }.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }
        return days.isEmpty ? "None" : days.joined(separator: ", ") + " · \(usualMinutes) min"
    }
}
