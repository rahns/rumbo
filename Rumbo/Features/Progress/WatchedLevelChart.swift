import Charts
import RumboCore
import SwiftUI

/// The Dreaming Spanish level watched over time: a minute-weighted average per day (up to 1m), week (up to 1y) or month (longer, all time only).
struct WatchedLevelChart: View {
    let sessions: [WatchedLevel.Session]
    let calendar: Calendar

    @AppStorage("progress.levelPeriod") private var periodRaw = WatchedLevel.Period.month.rawValue

    private var period: WatchedLevel.Period { WatchedLevel.Period(rawValue: periodRaw) ?? .month }

    var body: some View {
        let window = WatchedLevel.window(sessions, period: period, today: .now, calendar: calendar)
        let points = WatchedLevel.series(sessions, period: period, today: .now, calendar: calendar)
        VStack(alignment: .leading, spacing: 12) {
            Text("Level you watch")
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
            Picker("Period", selection: $periodRaw) {
                ForEach(WatchedLevel.Period.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text(summary(points, window: window))
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if points.isEmpty {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Palette.lilac.opacity(0.5))
                    .frame(height: 160)
                    .overlay {
                        Text("Log a Dreaming Spanish task and say what level you watched.")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
            } else {
                chart(points, window: window)
            }
        }
        .animation(.snappy, value: periodRaw)
    }

    private func chart(_ points: [WatchedLevel.Point], window: WatchedLevel.Window) -> some View {
        let levels = points.map(\.level)
        let low = max(0, (levels.min() ?? 0) - 3)
        let high = min(100, (levels.max() ?? 100) + 3)
        let color = Strand.input.color
        return Chart(points, id: \.date) { point in
            AreaMark(x: .value("Date", point.date), yStart: .value("Floor", low), yEnd: .value("Level", point.level))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Date", point.date), y: .value("Level", point.level))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", point.date), y: .value("Level", point.level))
                .foregroundStyle(color)
                .symbolSize(points.count > 40 ? 0 : 36)
        }
        .chartYScale(domain: low...high)
        .chartXScale(domain: window.start...calendar.startOfDay(for: .now))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: window.bucketDays == 1
                               ? .dateTime.day().month(.abbreviated)
                               : window.days > 366 ? .dateTime.month(.abbreviated).year(.twoDigits) : .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
        }
        .frame(height: 180)
        .accessibilityLabel("Level watched over \(period.rawValue)")
    }

    private func summary(_ points: [WatchedLevel.Point], window: WatchedLevel.Window) -> String {
        let unit = window.bucketDays == 1 ? "day" : window.bucketDays == 7 ? "week" : "month"
        guard let first = points.first, let last = points.last else {
            return "The average difficulty you watch, each \(unit). Watching a little harder over time means your listening is growing."
        }
        let start = Int(first.level.rounded()), end = Int(last.level.rounded())
        guard points.count > 1 else { return "Level \(end) so far. Keep logging and the line shows how it changes." }
        let change = end - start
        let trend = change > 0 ? "up \(change)" : change < 0 ? "down \(-change)" : "steady"
        let span = period == .allTime ? "since you started" : "over \(period.rawValue)"
        return "Level \(start) → \(end), \(trend) \(span). Each point is a \(unit)'s average, weighted by minutes."
    }
}
