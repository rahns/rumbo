import Charts
import RumboCore
import SwiftUI

/// The last 7 days' minutes per strand against the band's targets (§2.2): one row per strand,
/// the bar is the learner's share and the dark tick is the target share.
struct StrandBalanceChart: View {
    let minutes: [Strand: Int]
    let targets: [Strand: Double]

    var body: some View {
        let total = minutes.values.reduce(0, +)
        VStack(alignment: .leading, spacing: 14) {
            Text("This week's balance")
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(total == 0
                 ? "Nothing logged in the last 7 days yet. Finish a task and your mix shows up here, next to the marks your level needs."
                 : "Your last 7 days. The bar is your share of time; the mark is the share your level needs.")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
            ForEach(Strand.allCases, id: \.self) { strand in
                row(strand, share: total == 0 ? 0 : Double(minutes[strand] ?? 0) / Double(total))
            }
        }
    }

    private func row(_ strand: Strand, share: Double) -> some View {
        let target = targets[strand] ?? 0
        let spent = minutes[strand] ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(strand.label)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(spent) min · \(Int((share * 100).rounded()))%")
                    .foregroundStyle(Palette.secondaryText)
                Text("aim \(Int((target * 100).rounded()))%")
                    .foregroundStyle(Palette.secondaryText.opacity(0.8))
            }
            .font(.rounded(.subheadline, weight: .bold))
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.lilac)
                    Capsule()
                        .fill(strand.color)
                        .frame(width: share > 0 ? max(12, width * share) : 0)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Palette.ink)
                        .frame(width: 3, height: 20)
                        .offset(x: min(max(width * target - 1.5, 0), width - 3))
                }
            }
            .frame(height: 12)
            .padding(.vertical, 4)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: share)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strand.label)
        .accessibilityValue("\(spent) minutes, \(Int((share * 100).rounded())) percent. Target \(Int((target * 100).rounded())) percent.")
    }
}

/// Input hours from now to the target date (or a year out), with each level's threshold.
struct JourneyChart: View {
    let currentHours: Double
    let weeklyHours: Double
    let targetDate: Date?
    let calendar: Calendar

    var body: some View {
        let end = targetDate.flatMap { $0 > .now ? $0 : nil } ?? calendar.date(byAdding: .year, value: 1, to: .now)!
        let points = ProgressStats.projection(currentHours: currentHours, weeklyHours: weeklyHours, from: .now, until: end, calendar: calendar)
        let top = max((points.last?.hours ?? currentHours) * 1.1, currentHours + 10)
        let bottom = max(0, currentHours * 0.9)
        let bands = Band.allCases.filter { $0.inputHoursThreshold > currentHours && $0.inputHoursThreshold <= top }
        Chart {
            ForEach(bands, id: \.self) { band in
                RuleMark(y: .value("Hours", band.inputHoursThreshold))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Palette.secondaryText.opacity(0.6))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("\(band.label) · \(Int(band.inputHoursThreshold)) h")
                            .font(.rounded(.caption2, weight: .heavy))
                            .foregroundStyle(Palette.secondaryText)
                    }
            }
            ForEach(points, id: \.date) { point in
                AreaMark(x: .value("Date", point.date), yStart: .value("Hours", bottom), yEnd: .value("Hours", point.hours))
                    .foregroundStyle(LinearGradient(colors: [Palette.sky.opacity(0.35), Palette.sky.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", point.date), y: .value("Hours", point.hours))
                    .foregroundStyle(Palette.sky)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            if let first = points.first {
                PointMark(x: .value("Date", first.date), y: .value("Hours", first.hours))
                    .foregroundStyle(Palette.coral)
                    .symbolSize(90)
            }
            if let targetDate, targetDate > .now {
                RuleMark(x: .value("Target", targetDate))
                    .foregroundStyle(Palette.sun)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("Target").font(.rounded(.caption2, weight: .heavy)).foregroundStyle(Palette.sun)
                    }
            }
        }
        .chartYScale(domain: bottom...top)
        .chartPlotStyle { $0.clipped() }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year())
            }
        }
        .frame(height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Projected input hours")
        .accessibilityValue(summary(points))
    }

    private func summary(_ points: [ProgressStats.Point]) -> String {
        guard let last = points.last else { return "" }
        return "About \(Int(last.hours)) hours by \(last.date.formatted(.dateTime.month(.wide).year())), from \(Int(currentHours)) now."
    }
}

/// Twelve weeks of practice, one square per day, darker for more minutes.
struct PracticeHeatMap: View {
    let weeks: [[ProgressStats.Day]]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 12 weeks")
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
            if activeDays == 0 {
                Text("Each square is a day. They fill in green as you practise.")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(weekdayInitial(row))
                            .font(.rounded(.caption2, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                            .frame(width: 14, height: 18)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(week, id: \.date) { day in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(fill(for: day))
                                .frame(height: 18)
                                .overlay {
                                    if calendar.isDateInToday(day.date) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(Palette.ink, lineWidth: 1.5)
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 6) {
                Text("Less")
                ForEach([0, 10, 25, 45], id: \.self) { minutes in
                    RoundedRectangle(cornerRadius: 3).fill(fill(minutes: minutes, future: false)).frame(width: 14, height: 14)
                }
                Text("More")
            }
            .font(.rounded(.caption2, weight: .bold))
            .foregroundStyle(Palette.secondaryText)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last 12 weeks")
        .accessibilityValue("You practised on \(activeDays) days, \(totalMinutes) minutes in all.")
    }

    private var activeDays: Int { weeks.joined().filter { $0.minutes > 0 }.count }
    private var totalMinutes: Int { weeks.joined().reduce(0) { $0 + $1.minutes } }

    private func weekdayInitial(_ row: Int) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return symbols[(calendar.firstWeekday - 1 + row) % 7]
    }

    private func fill(for day: ProgressStats.Day) -> Color {
        fill(minutes: day.minutes, future: day.date > .now)
    }

    private func fill(minutes: Int, future: Bool) -> Color {
        if future { return Palette.lilac.opacity(0.35) }
        switch minutes {
        case 0: return Palette.lilac
        case ..<15: return Palette.leaf.opacity(0.35)
        case ..<30: return Palette.leaf.opacity(0.65)
        default: return Palette.leaf
        }
    }
}
