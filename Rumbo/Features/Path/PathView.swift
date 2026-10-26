import RumboCore
import SwiftUI

/// Home: a winding path with one node per session, grouped into units of 7, running on into the
/// future with projected level-ups. See docs/03-experience.md §3.4 "Path".
struct PathView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var selectedDate: SelectedDay?
    @State private var showingToday = false
    @State private var showingGate = false

    var body: some View {
        let map = model.pathMap
        let focus = map.focusNode
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(map.units) { unit in
                            UnitBanner(unit: unit, isFuture: unit.nodes.allSatisfy { $0.status == .upcoming })
                                .padding(.top, unit.number == 1 ? 8 : 28)
                                .padding(.bottom, 18)
                            ForEach(unit.nodes) { node in
                                nodeRow(node)
                                    .id(node.id)
                                if node.id == focus?.id && model.isGateOpen {
                                    gateRow(after: node.number)
                                }
                                ForEach(map.milestones.filter { $0.afterNode == node.number }) { milestone in
                                    MilestoneRow(milestone: milestone)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    if let focus { proxy.scrollTo(focus.id, anchor: .center) }
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) { header }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingToday) {
                TodayView()
                    .navigationTransition(.zoom(sourceID: "focus", in: zoom))
            }
            .sheet(item: $selectedDate) { selected in
                DaySummarySheet(date: selected.date)
                    .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingGate) {
                GateView()
            }
        }
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
            StatPill(symbol: "flame.fill", value: "\(model.streak.streak)", color: Palette.sun, bounce: model.streak.streak)
            StatPill(symbol: "star.fill", value: "\(model.xp)", color: Palette.sky)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Rows

    /// Nodes wind left and right like a trail.
    private func xOffset(_ number: Int) -> CGFloat {
        sin(Double(number - 1) * .pi / 3.5) * 80
    }

    @ViewBuilder
    private func nodeRow(_ node: PathNode) -> some View {
        let offset = xOffset(node.number)
        let isFocus = node.status == .current || node.status == .unlocked
        ZStack {
            if isFocus {
                Button {
                    if node.status == .unlocked { model.wantsNextSession = true }
                    showingToday = true
                } label: {
                    PathNodeView(status: node.status)
                }
                .buttonStyle(PathNodeButtonStyle())
                .matchedTransitionSource(id: "focus", in: zoom)
                .overlay(alignment: .top) {
                    StartBubble(text: bubbleText(for: node), color: node.status == .unlocked ? Palette.sky : Palette.coral)
                        .offset(y: -46)
                }
                // Mirror first, then move: Pico faces the node from whichever side has room.
                PicoView(mood: model.picoMood, size: 76, celebrate: model.celebrations)
                    .scaleEffect(x: offset > 0 ? 1 : -1, y: 1)
                    .offset(x: offset > 0 ? -112 : 112, y: -6)
            } else {
                Button {
                    if let date = node.date { selectedDate = SelectedDay(date: date) }
                } label: {
                    PathNodeView(status: node.status)
                }
                .buttonStyle(PathNodeButtonStyle())
                .disabled(node.date == nil)
            }
        }
        .offset(x: offset)
        .frame(maxWidth: .infinity)
        .padding(.vertical, isFocus ? 32 : 10)
    }

    private func bubbleText(for node: PathNode) -> String {
        if node.status == .unlocked { return "Keep going" }
        return model.todayPlan == nil ? "Start" : "Today"
    }

    private func gateRow(after number: Int) -> some View {
        Button {
            showingGate = true
        } label: {
            VStack(spacing: 6) {
                PathNodeView(status: .current, isGate: true)
                Text("Level-up check")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
        }
        .buttonStyle(PathNodeButtonStyle())
        .offset(x: xOffset(number) * 0.5)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

// MARK: - Pieces

struct UnitBanner: View {
    let unit: PathUnit
    let isFuture: Bool

    var body: some View {
        let color = unit.isComplete ? Palette.leaf : isFuture ? Palette.secondaryText.opacity(0.55) : Palette.sky
        let dates = unit.nodes.compactMap(\.date)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unidad \(unit.number)")
                    .font(.rounded(.title3, weight: .black))
                if let first = dates.first, let last = dates.last {
                    Text(first == last
                         ? first.formatted(.dateTime.day().month(.abbreviated))
                         : "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.rounded(.subheadline, weight: .bold))
                        .opacity(0.85)
                } else {
                    Text("Sessions \(unit.nodes.first?.number ?? 0)–\(unit.nodes.last?.number ?? 0)")
                        .font(.rounded(.subheadline, weight: .bold))
                        .opacity(0.85)
                }
            }
            Spacer()
            if unit.isComplete {
                Image(systemName: "checkmark.seal.fill").font(.title2)
            } else if isFuture {
                Image(systemName: "lock.fill").font(.title3)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.edge()).offset(y: 4))
        .padding(.bottom, 4)
    }
}

/// A round "3D" node: a face over a darker edge. The focus node pulses; upcoming nodes are flat and locked.
struct PathNodeView: View {
    let status: PathNode.Status
    var isGate = false

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let edge: CGFloat = 6

    private var color: Color {
        if isGate { return Palette.sun }
        switch status {
        case .done: return Palette.leaf
        case .partial: return Palette.sun
        case .current: return Palette.coral
        case .unlocked: return Palette.sky
        case .upcoming: return Palette.lilac
        }
    }

    private var symbol: String {
        if isGate { return "trophy.fill" }
        switch status {
        case .done: return "checkmark"
        case .partial: return "circle.lefthalf.filled"
        case .current: return "star.fill"
        case .unlocked: return "forward.fill"
        case .upcoming: return "lock.fill"
        }
    }

    private var size: CGFloat {
        isGate ? 86 : (status == .current || status == .unlocked) ? 82 : 66
    }

    private var pulses: Bool { isGate || status == .current || status == .unlocked }

    var body: some View {
        let raised = status != .upcoming
        ZStack {
            if pulses {
                // Centred on face + edge together, so the ring sits evenly around the whole node.
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 6)
                    .frame(width: size + 22, height: size + 22)
                    .offset(y: Self.edge / 2)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .opacity(pulse ? 0.3 : 0.9)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(status == .upcoming ? Palette.secondaryText : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(color))
                .background(Circle().fill(color.edge()).offset(y: raised ? Self.edge : 0))
        }
        .padding(.bottom, Self.edge)
        .opacity(status == .upcoming ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion, pulses else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isGate { return "Level-up check" }
        switch status {
        case .done: return "Finished session"
        case .partial: return "Unfinished session"
        case .current: return "Today's session"
        case .unlocked: return "Next session, open early"
        case .upcoming: return "Locked session"
        }
    }
}

/// A projected level-up further along the path.
struct MilestoneRow: View {
    let milestone: PathMilestone

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Circle().fill(Palette.sun.opacity(0.75)))
                .background(Circle().fill(Palette.sun.edge()).opacity(0.75).offset(y: 5))
            VStack(spacing: 2) {
                Text("\(milestone.band.label) · \(milestone.band.rawValue)")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text("around \(milestone.expectedDate.formatted(.dateTime.month(.wide).year()))")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
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
    var color: Color = Palette.coral
    @State private var bob = false

    var body: some View {
        Text(text.uppercased())
            .font(.rounded(.subheadline, weight: .black))
            .foregroundStyle(color)
            .fixedSize()
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
    let date: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        let logs = model.logs(on: date)
        VStack(alignment: .leading, spacing: 14) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.rounded(.title2, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(logs.isEmpty ? "Nothing logged that day." : "\(logs.reduce(0) { $0 + $1.minutes }) minutes")
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
