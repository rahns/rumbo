import RumboCore
import SwiftUI

/// Progress tab: level, strand balance, projection chart, level watched, streak, 12-week heat map and course progress.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = model.profile {
                    VStack(alignment: .leading, spacing: 18) {
                        levelCard(profile)
                        RaisedCard(accent: Palette.leaf) {
                            StrandBalanceChart(minutes: model.strandMinutesThisWeek, targets: model.snapshot(for: profile).strandTargets)
                        }
                        projectionCard(profile)
                        // The level-watched chart needs a graded library with a difficulty scale.
                        if profile.enabledSources.contains(.gradedVideo), profile.pack.graded != nil {
                            RaisedCard(accent: Palette.coral) {
                                WatchedLevelChart(sessions: model.watchedLevels, calendar: model.calendar)
                            }
                        }
                        streakCard
                        RaisedCard(accent: Palette.leaf) {
                            PracticeHeatMap(weeks: model.heatMapWeeks(), calendar: model.calendar)
                        }
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
        let hours = model.trainingHours
        let band = profile.band
        let next = band.next
        let progress = next.map { (hours - ActiveLanguage.pack.levels.threshold(band)) / (ActiveLanguage.pack.levels.threshold($0) - ActiveLanguage.pack.levels.threshold(band)) } ?? 1
        return RaisedCard(accent: Palette.coral) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BandBadge(band: band).scaleEffect(0.7, anchor: .leading)
                    Spacer()
                }
                .frame(height: 80)
                Text("\(Int(hours)) training hours")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text("Every minute of practice counts. Listening from before Rumbo counts at the plan's mix (\(Int(profile.baselineInputHours)) h → \(Int(Band.trainingHours(fromListening: profile.baselineInputHours))) h).")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                ChunkyProgressBar(value: progress, color: Palette.coral)
                if let next {
                    Text("\(max(0, Int((ActiveLanguage.pack.levels.threshold(next) - hours).rounded(.up)))) training hours to \(ActiveLanguage.levelName(next)) (\(next.rawValue)), which starts at \(Int(ActiveLanguage.pack.levels.threshold(next))) h")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private func projectionCard(_ profile: LearnerProfile) -> some View {
        let projection = Projection()
        // Until there's a week of history, forecast at the weekly goal rather than from one or two sessions.
        let (weekly, ownPace) = model.forecastWeeklyHours
        let arrivals = projection.arrivalDates(hours: model.trainingHours, weeklyHours: weekly, from: .now, levels: model.pack.levels)
        return RaisedCard(accent: Palette.sky) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Where you're heading")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text(ownPace
                     ? String(format: "%.1f training hours a week, your recent pace (everything you've logged).", weekly)
                     : "\(String(format: "%.1f", weekly)) training hours a week: your \(profile.weeklyGoalMinutes)-minute weekly goal, all of which counts toward levels. Your real pace takes over after a week.")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                if arrivals.isEmpty {
                    Text("Log some practice and Rumbo will forecast when you reach each level.")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                } else {
                    let expected = profile.targetDate.map { projection.hours(by: $0, from: .now, current: model.trainingHours, weeklyHours: weekly) }
                    LevelTimeline(band: profile.band, hours: model.trainingHours, arrivals: arrivals,
                                  goal: profile.goal, goalBand: profile.goalBand,
                                  targetDate: profile.targetDate, hoursAtTarget: expected)
                        .padding(.top, 6)
                }
                if let target = profile.targetDate, target > .now {
                    let extra = projection.hours(by: target, from: .now, current: model.trainingHours, weeklyHours: weekly, extraMinutesPerDay: 10)
                    Label("With 10 more minutes a day, you'd have about \(Int(extra)) h by \(target.formatted(.dateTime.month(.abbreviated).year())): \(ActiveLanguage.levelName(ActiveLanguage.pack.levels.band(forHours: extra))) (\(ActiveLanguage.pack.levels.band(forHours: extra).rawValue)).", systemImage: "bolt.fill")
                        .font(.rounded(.subheadline, weight: .semibold))
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
                stat("\(status.freezes) of \(StreakCalculator.maxFreezes)", "freezes", "snowflake", Palette.ice)
                stat("\(Int(model.trainingHours))", "training hours", "clock.fill", Palette.leaf)
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
        let pack = profile.pack
        // Only the sources this language has and the learner uses.
        let sources = profile.enabledSources.filter(pack.has)
        return RaisedCard(accent: Palette.leaf) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your sources")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                if sources.contains(.gradedVideo) {
                    infoRow(SourceCopy.name(.gradedVideo), "\(Int(model.listeningHours)) h listening · videos \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)")
                }
                if sources.contains(.audioCourse) {
                    courseRow(SourceCopy.name(.audioCourse), done: profile.languageTransferLastTrack, total: pack.course?.tracks ?? 0, unit: "tracks")
                }
                if sources.contains(.drillApp) {
                    infoRow(SourceCopy.name(.drillApp), "Section \(profile.duolingoSection) · Unit \(profile.duolingoUnit)")
                }
                if sources.contains(.learnerSeries) {
                    courseRow(SourceCopy.name(.learnerSeries), done: profile.extraEpisodesWatched, total: pack.series?.episodes ?? 0, unit: "episodes")
                }
                if sources.contains(.exchange) {
                    infoRow(pack.sources[.exchange]?.shortName ?? "Exchange", "Speaking stage: \(stageName(profile.speakingStage))")
                }
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Palette.secondaryText)
        }
        .font(.rounded(.subheadline, weight: .bold))
        .foregroundStyle(Palette.ink)
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
