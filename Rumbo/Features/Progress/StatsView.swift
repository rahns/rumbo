import RumboCore
import SwiftUI

/// Progress tab (M2 version): level, input hours, projection, streak and course progress.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = model.profile {
                    VStack(alignment: .leading, spacing: 18) {
                        levelCard(profile)
                        projectionCard(profile)
                        streakCard
                        coursesCard(profile)
                    }
                    .padding(20)
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }

    private func levelCard(_ profile: LearnerProfile) -> some View {
        let hours = model.inputHours
        let band = profile.band
        let next = band.next
        let progress = next.map { (hours - band.inputHoursThreshold) / ($0.inputHoursThreshold - band.inputHoursThreshold) } ?? 1
        return RaisedCard(accent: Palette.coral) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BandBadge(band: band).scaleEffect(0.7, anchor: .leading)
                    Spacer()
                }
                .frame(height: 80)
                Text("\(Int(hours)) hours of input")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(Palette.ink)
                ChunkyProgressBar(value: progress, color: Palette.coral)
                if let next {
                    Text("\(max(0, Int((next.inputHoursThreshold - hours).rounded(.up)))) hours to \(next.label) (\(next.rawValue))")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private func projectionCard(_ profile: LearnerProfile) -> some View {
        let projection = Projection()
        let weekly = projection.weeklyInputHours(history: model.history, today: .now)
        let arrivals = projection.arrivalDates(inputHours: model.inputHours, weeklyHours: weekly, from: .now)
        return RaisedCard(accent: Palette.sky) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Where you're heading")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text(String(format: "%.1f hours of input a week (last 4 weeks)", weekly))
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                if arrivals.isEmpty {
                    Text("Log a few sessions and Rumbo will forecast when you reach each level.")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                } else {
                    ForEach(Band.allCases.filter { arrivals[$0] != nil }, id: \.self) { band in
                        HStack {
                            Text("\(band.label) · \(band.rawValue)")
                            Spacer()
                            Text(arrivals[band]!.formatted(.dateTime.month(.abbreviated).year()))
                        }
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    }
                }
                if let target = profile.targetDate {
                    let expected = projection.inputHours(by: target, from: .now, current: model.inputHours, weeklyHours: weekly)
                    let extra = projection.inputHours(by: target, from: .now, current: model.inputHours, weeklyHours: weekly, extraMinutesPerDay: 10)
                    Text("By \(target.formatted(date: .abbreviated, time: .omitted)): about \(Int(expected)) hours (\(Band.forInputHours(expected).rawValue)). With 10 more minutes a day: \(Int(extra)) hours (\(Band.forInputHours(extra).rawValue)).")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private var streakCard: some View {
        let status = model.streak
        return RaisedCard(accent: Palette.sun) {
            HStack(spacing: 20) {
                stat("\(status.streak)", "day streak", "flame.fill", Palette.sun)
                stat("\(status.freezes)", "freezes", "snowflake", Palette.sky)
                stat("\(model.xp)", "XP", "star.fill", Palette.leaf)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            Text(value).font(.rounded(.title2, weight: .black)).foregroundStyle(Palette.ink)
            Text(label).font(.rounded(.caption, weight: .bold)).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func coursesCard(_ profile: LearnerProfile) -> some View {
        RaisedCard(accent: Palette.leaf) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Courses")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                if profile.enabledSources.contains(.languageTransfer) {
                    courseRow("Language Transfer", done: profile.languageTransferLastTrack, total: Course.languageTransferTracks, unit: "tracks")
                }
                if profile.enabledSources.contains(.extraEnEspanol) {
                    courseRow("Extra en Español", done: profile.extraEpisodesWatched, total: Course.extraEpisodes, unit: "episodes")
                }
                Text("Speaking stage: \(stageName(profile.speakingStage))")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
    }

    private func courseRow(_ title: String, done: Int, total: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(done) / \(total) \(unit)")
            }
            .font(.rounded(.subheadline, weight: .bold))
            .foregroundStyle(Palette.ink)
            ChunkyProgressBar(value: Double(done) / Double(total), color: Palette.leaf, height: 10)
        }
    }

    private func stageName(_ stage: SpeakingStage) -> String {
        switch stage {
        case .text: "text messages"
        case .voiceNotes: "voice notes"
        case .calls: "live calls"
        }
    }
}
