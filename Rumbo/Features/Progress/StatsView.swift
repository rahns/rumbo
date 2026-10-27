import RumboCore
import SwiftUI

/// Progress tab: level, strand balance, projection chart, streak, 12-week heat map and course progress.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = model.profile {
                    VStack(alignment: .leading, spacing: 18) {
                        levelCard(profile)
                        RaisedCard(accent: Palette.leaf) {
                            StrandBalanceChart(minutes: model.strandMinutesThisWeek, targets: profile.band.strandTargets)
                        }
                        projectionCard(profile)
                        streakCard
                        RaisedCard(accent: Palette.leaf) {
                            PracticeHeatMap(weeks: model.heatMapWeeks(), calendar: model.calendar)
                        }
                        mistakeDeckCard
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
        // Until there's a week of history, forecast at the weekly goal rather than from one or two sessions.
        let (weekly, ownPace) = model.forecastWeeklyHours
        let arrivals = projection.arrivalDates(inputHours: model.inputHours, weeklyHours: weekly, from: .now)
        return RaisedCard(accent: Palette.sky) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Where you're heading")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text(ownPace
                     ? String(format: "%.1f hours of listening a week, your recent pace (extra listening included).", weekly)
                     : "\(String(format: "%.1f", weekly)) hours of listening a week: about \(Int(((profile.band.strandTargets[.input] ?? 0) * 100).rounded()))% of your \(profile.weeklyGoalMinutes)-minute weekly goal is listening, and only listening counts toward level hours. Your real pace takes over after a week.")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                if arrivals.isEmpty {
                    Text("Log some listening and Rumbo will forecast when you reach each level.")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                } else {
                    let expected = profile.targetDate.map { projection.inputHours(by: $0, from: .now, current: model.inputHours, weeklyHours: weekly) }
                    LevelTimeline(band: profile.band, hours: model.inputHours, arrivals: arrivals,
                                  goal: profile.goal, goalBand: profile.goalBand,
                                  targetDate: profile.targetDate, hoursAtTarget: expected)
                        .padding(.top, 6)
                }
                if let target = profile.targetDate, target > .now {
                    let extra = projection.inputHours(by: target, from: .now, current: model.inputHours, weeklyHours: weekly, extraMinutesPerDay: 10)
                    Label("With 10 more minutes a day, you'd have about \(Int(extra)) h by \(target.formatted(.dateTime.month(.abbreviated).year())): \(Band.forInputHours(extra).label) (\(Band.forInputHours(extra).rawValue)).", systemImage: "bolt.fill")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private var mistakeDeckCard: some View {
        let total = model.allCards.count
        let due = model.dueCards.count
        return NavigationLink {
            MistakeDeckView()
        } label: {
            RaisedCard(accent: Palette.coral) {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Palette.coral))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mistake deck")
                            .font(.rounded(.headline, weight: .black))
                            .foregroundStyle(Palette.ink)
                        Text(total == 0 ? "Your corrected mistakes will collect here." : "\(total) cards · \(due) due now")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
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
        let sources = profile.enabledSources
        return RaisedCard(accent: Palette.leaf) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your sources")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                if sources.contains(.dreamingSpanish) {
                    infoRow("Dreaming Spanish", "\(Int(model.inputHours)) h · videos \(profile.dsDifficultyLow)–\(profile.dsDifficultyHigh)")
                }
                if sources.contains(.languageTransfer) {
                    courseRow("Language Transfer", done: profile.languageTransferLastTrack, total: Course.languageTransferTracks, unit: "tracks")
                }
                if sources.contains(.duolingo) {
                    infoRow("Duolingo", "Section \(profile.duolingoSection) · Unit \(profile.duolingoUnit)")
                }
                if sources.contains(.extraEnEspanol) {
                    courseRow("Extra en Español", done: profile.extraEpisodesWatched, total: Course.extraEpisodes, unit: "episodes")
                }
                if sources.contains(.tandem) {
                    infoRow("Tandem", "Speaking stage: \(stageName(profile.speakingStage))")
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
