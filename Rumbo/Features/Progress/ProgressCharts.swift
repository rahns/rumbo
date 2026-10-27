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
                Spacer(minLength: 8)
                Text("\(Int((share * 100).rounded()))% · aim \(Int((target * 100).rounded()))%")
                    .foregroundStyle(Palette.secondaryText)
            }
            .font(.rounded(.subheadline, weight: .bold))
            Text("\(spent) min · \(strand.detail)")
                .font(.rounded(.caption, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
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
        .accessibilityLabel("\(strand.label): \(strand.detail)")
        .accessibilityValue("\(spent) minutes, \(Int((share * 100).rounded())) percent. Target \(Int((target * 100).rounded())) percent.")
    }
}

/// The road ahead: now, each level's expected arrival, and the learner's target date, in date order.
/// Levels reached before the target are green; ones after it are faded.
struct LevelTimeline: View {
    let band: Band
    let hours: Double
    let arrivals: [Band: Date]
    let targetDate: Date?
    /// Expected hours and level on the target date.
    let atTarget: (hours: Double, band: Band)?

    private enum Stop: Identifiable {
        case now
        case level(Band, Date)
        case target(Date)

        var id: String {
            switch self {
            case .now: "now"
            case .level(let band, _): band.rawValue
            case .target: "target"
            }
        }

        var date: Date {
            switch self {
            case .now: .distantPast
            case .level(_, let date), .target(let date): date
            }
        }
    }

    var body: some View {
        let stops = makeStops()
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                row(stop, isLast: index == stops.count - 1)
            }
        }
    }

    private func makeStops() -> [Stop] {
        var stops: [Stop] = arrivals.map { Stop.level($0.key, $0.value) }
        if let targetDate, targetDate > .now { stops.append(.target(targetDate)) }
        return [.now] + stops.sorted { $0.date < $1.date }
    }

    private func row(_ stop: Stop, isLast: Bool) -> some View {
        let afterTarget = targetDate.map { stop.date > $0 } ?? false
        let style = style(for: stop, afterTarget: afterTarget)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: style.symbol)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(style.color))
                if !isLast {
                    Rectangle()
                        .fill(Palette.lilac)
                        .frame(width: 4)
                        .frame(minHeight: 22, maxHeight: .infinity)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(style.title)
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(style.isTarget ? Palette.sun : Palette.ink)
                    Spacer(minLength: 8)
                    Text(style.date)
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(style.isTarget ? Palette.sun : Palette.ink)
                }
                Text(style.subtitle)
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 0 : 14)
        }
        .opacity(afterTarget ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private struct Style {
        var symbol: String
        var color: Color
        var title: String
        var date: String
        var subtitle: String
        var isTarget = false
    }

    private func style(for stop: Stop, afterTarget: Bool) -> Style {
        switch stop {
        case .now:
            return Style(symbol: "location.fill", color: Palette.coral, title: "Now · \(band.label)",
                         date: "\(Int(hours)) h", subtitle: "\(band.rawValue), hours of listening so far")
        case .level(let level, let date):
            return Style(symbol: "trophy.fill", color: afterTarget ? Palette.secondaryText : Palette.leaf,
                         title: "\(level.label) · \(level.rawValue)",
                         date: date.formatted(.dateTime.month(.abbreviated).year()),
                         subtitle: "\(Int(level.inputHoursThreshold)) h · \(Self.distance(to: date))")
        case .target(let date):
            let expected = atTarget.map { "About \(Int($0.hours)) h by then: \($0.band.label) (\($0.band.rawValue))" } ?? ""
            return Style(symbol: "flag.fill", color: Palette.sun, title: "Your target",
                         date: date.formatted(.dateTime.month(.abbreviated).year()), subtitle: expected, isTarget: true)
        }
    }

    /// "in 4 months", "in 2 years".
    private static func distance(to date: Date) -> String {
        let months = Calendar.current.dateComponents([.month], from: .now, to: date).month ?? 0
        if months < 1 { return "within a month" }
        if months < 18 { return months == 1 ? "in 1 month" : "in \(months) months" }
        let years = (Double(months) / 12).rounded()
        return "in about \(Int(years)) years"
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
