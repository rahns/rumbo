import RumboCore
import SwiftUI

/// Home: a winding path with one node per day, grouped into weekly units.
/// Today's node zooms into the Today plan. See docs/03-experience.md §3.4 "Path".
struct PathView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var selectedDay: PathDay?
    @State private var showingToday = false
    @State private var showingGate = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(units) { unit in
                            UnitBanner(unit: unit)
                                .padding(.top, unit.number == 1 ? 8 : 28)
                                .padding(.bottom, 18)
                            ForEach(Array(unit.days.enumerated()), id: \.element.id) { offset, day in
                                dayRow(day, index: (unit.number - 1) * PathLayout.daysPerUnit + offset)
                                    .id(day.id)
                                if day.status == .today && model.isGateOpen {
                                    gateRow(index: (unit.number - 1) * PathLayout.daysPerUnit + offset)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    if let today = todayID {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) { header }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingToday) {
                TodayView()
                    .navigationTransition(.zoom(sourceID: "today", in: zoom))
            }
            .sheet(item: $selectedDay) { day in
                DaySummarySheet(day: day)
                    .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingGate) {
                GateView()
            }
        }
    }

    private var units: [PathUnit] {
        guard let profile = model.profile else { return [] }
        return PathLayout.units(start: profile.createdAt, today: .now, history: model.history)
    }

    private var todayID: Date? {
        units.flatMap(\.days).first { $0.status == .today }?.id
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if let profile = model.profile {
                Text("\(profile.band.label) · \(profile.band.rawValue)")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Palette.coral))
            }
            Spacer()
            StatPill(symbol: "flame.fill", value: "\(model.streak.streak)", color: Palette.sun)
            StatPill(symbol: "star.fill", value: "\(model.xp)", color: Palette.sky)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Rows

    /// Nodes wind left and right like a trail.
    private func xOffset(_ index: Int) -> CGFloat {
        sin(Double(index) * .pi / 3.5) * 80
    }

    @ViewBuilder
    private func dayRow(_ day: PathDay, index: Int) -> some View {
        let offset = xOffset(index)
        ZStack {
            if day.status == .today {
                Button {
                    showingToday = true
                } label: {
                    PathNode(day: day, isGate: false)
                }
                .buttonStyle(PathNodeButtonStyle())
                .matchedTransitionSource(id: "today", in: zoom)
                .overlay(alignment: .top) {
                    StartBubble(text: model.todayPlan == nil ? "Start" : "Today")
                        .offset(y: -44)
                }
                // Mirror first, then move: Pico faces the node from whichever side has room.
                PicoView(mood: model.picoMood, size: 70, celebrate: model.celebrations)
                    .scaleEffect(x: offset > 0 ? 1 : -1, y: 1)
                    .offset(x: offset > 0 ? -110 : 110, y: -6)
            } else {
                Button {
                    if day.status != .upcoming { selectedDay = day }
                } label: {
                    PathNode(day: day, isGate: false)
                }
                .buttonStyle(PathNodeButtonStyle())
                .disabled(day.status == .upcoming)
            }
        }
        .offset(x: offset)
        .frame(maxWidth: .infinity)
        .padding(.vertical, day.status == .today ? 30 : 10)
    }

    private func gateRow(index: Int) -> some View {
        Button {
            showingGate = true
        } label: {
            VStack(spacing: 6) {
                PathNode(day: nil, isGate: true)
                Text("Level-up check")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
        }
        .buttonStyle(PathNodeButtonStyle())
        .offset(x: xOffset(index) * 0.4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Pieces

struct UnitBanner: View {
    let unit: PathUnit

    var body: some View {
        let color = unit.isComplete ? Palette.leaf : Palette.sky
        let first = unit.days.first?.date ?? .now
        let last = unit.days.last?.date ?? .now
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unidad \(unit.number)")
                    .font(.rounded(.title3, weight: .black))
                Text("\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.rounded(.subheadline, weight: .bold))
                    .opacity(0.85)
            }
            Spacer()
            if unit.isComplete {
                Image(systemName: "checkmark.seal.fill").font(.title2)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.edge()).offset(y: 4))
        .padding(.bottom, 4)
    }
}

/// A round "3D" node. Today's node pulses; upcoming nodes are flat and locked.
struct PathNode: View {
    let day: PathDay?
    let isGate: Bool

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        if isGate { return Palette.sun }
        switch day?.status {
        case .done: return Palette.leaf
        case .partial: return Palette.sun
        case .today: return Palette.coral
        case .missed, .upcoming, nil: return Palette.lilac
        }
    }

    private var symbol: String {
        if isGate { return "trophy.fill" }
        switch day?.status {
        case .done: return "checkmark"
        case .partial: return "circle.lefthalf.filled"
        case .today: return "star.fill"
        case .missed: return "moon.zzz.fill"
        case .upcoming, nil: return "lock.fill"
        }
    }

    private var size: CGFloat {
        isGate ? 86 : day?.status == .today ? 82 : 66
    }

    var body: some View {
        let raised = day?.status != .upcoming
        ZStack {
            if day?.status == .today || isGate {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 6)
                    .frame(width: size + 18, height: size + 18)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .opacity(pulse ? 0.3 : 0.9)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(day?.status == .missed || day?.status == .upcoming ? Palette.secondaryText : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(color))
                .background(Circle().fill(color.edge()).offset(y: raised ? 6 : 0))
        }
        .padding(.bottom, 6)
        .opacity(day?.status == .upcoming ? 0.6 : 1)
        .onAppear {
            guard !reduceMotion, day?.status == .today || isGate else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isGate { return "Level-up check" }
        guard let day else { return "" }
        let date = day.date.formatted(date: .abbreviated, time: .omitted)
        switch day.status {
        case .done: return "\(date), done, \(day.minutes) minutes"
        case .partial: return "\(date), \(day.minutes) minutes"
        case .missed: return "\(date), missed"
        case .today: return "Today"
        case .upcoming: return "\(date), upcoming"
        }
    }
}

/// Nodes press down onto their edge, like the chunky buttons.
struct PathNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, new in new }
    }
}

struct StartBubble: View {
    let text: String
    @State private var bob = false

    var body: some View {
        Text(text.uppercased())
            .font(.rounded(.subheadline, weight: .black))
            .foregroundStyle(Palette.coral)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardEdge).offset(y: 3))
            .overlay(alignment: .bottom) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.card)
                    .rotationEffect(.degrees(180))
                    .offset(y: 8)
            }
            .offset(y: bob ? -3 : 3)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = true }
            .allowsHitTesting(false)
    }
}

/// What happened on a past day.
struct DaySummarySheet: View {
    let day: PathDay
    @Environment(AppModel.self) private var model

    var body: some View {
        let logs = model.logs(on: day.date)
        VStack(alignment: .leading, spacing: 14) {
            Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.rounded(.title2, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(logs.isEmpty ? "No practice logged. Missed days happen; the plan rebalances." : "\(day.minutes) minutes")
                .font(.rounded(.headline, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
            ForEach(logs) { log in
                HStack(spacing: 12) {
                    Image(systemName: log.isBonus ? "ear.fill" : TaskCopy.symbol(for: log.task))
                        .foregroundStyle(log.task.strand.color)
                        .frame(width: 28)
                    Text(log.isBonus ? "Extra listening" : TaskCopy.title(for: log.task))
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(log.minutes) min")
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            Spacer()
        }
        .padding(24)
        .background(Palette.background.ignoresSafeArea())
    }
}
