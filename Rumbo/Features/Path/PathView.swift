import RumboCore
import SwiftUI

/// Home: a winding path with one node per calendar day, in units of 7, running on into the future
/// with projected level-ups. Finishing today opens tomorrow early. See docs/03-experience.md §3.4 "Path".
struct PathView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var selectedDate: SelectedDay?
    @State private var showingToday = false
    @State private var showingGate = false

    var body: some View {
        let map = model.pathMap
        let todayDone = map.todayNode?.status == .done
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(map.units) { unit in
                            UnitBanner(unit: unit, isFuture: unit.nodes.allSatisfy { $0.status == .upcoming })
                                .padding(.top, unit.number == 1 ? 8 : 28)
                                .padding(.bottom, 18)
                            ForEach(unit.nodes) { node in
                                nodeRow(node, todayDone: todayDone)
                                    .id(node.id)
                                if node.isToday && model.isGateOpen {
                                    gateRow(after: node.number)
                                }
                                ForEach(map.milestones.filter { $0.afterNode == node.number }) { milestone in
                                    MilestoneRow(milestone: milestone)
                                }
                            }
                        }
                        if !map.laterMilestones.isEmpty {
                            FurtherAheadCard(milestones: map.laterMilestones)
                                .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    if let today = map.todayNode { proxy.scrollTo(today.id, anchor: .center) }
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) { header(todayDone: todayDone) }
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
            .onChange(of: model.todayRequests) {
                showingToday = true
            }
        }
    }

    // MARK: Header

    private func header(todayDone: Bool) -> some View {
        HStack(spacing: 8) {
            if let profile = model.profile {
                Text("\(profile.band.label) · \(profile.band.rawValue)")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Palette.coral))
            }
            if todayDone {
                Label("Day done", systemImage: "checkmark.circle.fill")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Palette.leaf))
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            StatPill(symbol: "flame.fill", value: "\(model.streak.streak)", color: Palette.sun, bounce: model.streak.streak)
            StatPill(symbol: "star.fill", value: "\(model.xp)", color: Palette.sky)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: todayDone)
    }

    // MARK: Rows

    /// Nodes wind left and right like a trail.
    private func xOffset(_ number: Int) -> CGFloat {
        sin(Double(number - 1) * .pi / 3.5) * 80
    }

    @ViewBuilder
    private func nodeRow(_ node: PathNode, todayDone: Bool) -> some View {
        let offset = xOffset(node.number)
        let highlighted = node.isToday || node.status == .unlocked
        ZStack {
            Button {
                open(node)
            } label: {
                VStack(spacing: 6) {
                    PathNodeView(status: node.status, isToday: node.isToday, date: node.date, minutes: node.minutes)
                    Text(node.isToday ? "Today" : node.date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.rounded(.caption, weight: node.isToday ? .black : .bold))
                        .foregroundStyle(node.isToday ? Palette.ink : Palette.secondaryText)
                }
            }
            .buttonStyle(PathNodeButtonStyle())
            .disabled(node.status == .upcoming)
            .modifier(FocusSource(active: node.isToday, zoom: zoom))
            .overlay(alignment: .top) {
                if let tag = bubble(for: node) {
                    StartBubble(text: tag.text, color: tag.color)
                        .offset(y: -46)
                }
            }
            if node.isToday {
                // Mirror first, then move: Pico faces the node from whichever side has room.
                PicoView(mood: todayDone ? .cheering : model.picoMood, size: 84, celebrate: model.celebrations)
                    .scaleEffect(x: offset > 0 ? 1 : -1, y: 1)
                    .offset(x: offset > 0 ? -118 : 118, y: -10)
            }
        }
        .offset(x: offset)
        .frame(maxWidth: .infinity)
        .padding(.vertical, highlighted ? 30 : 8)
    }

    private func bubble(for node: PathNode) -> (text: String, color: Color)? {
        if node.isToday {
            if node.status == .done { return ("¡Hecho!", Palette.leaf) }
            return (model.session(for: node.date) == nil ? "Start" : "Continue", Palette.coral)
        }
        if node.status == .unlocked { return ("Keep going", Palette.sky) }
        return nil
    }

    private func open(_ node: PathNode) {
        if node.isToday {
            model.showToday()
            showingToday = true
        } else if node.status == .unlocked || (node.date > .now && model.session(for: node.date) != nil) {
            // A day opened early, finished or not, opens in Today so its tasks can be continued or undone.
            model.selectedPlanDay = node.date
            showingToday = true
        } else {
            selectedDate = SelectedDay(date: node.date)
        }
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

/// Today's node is the source of the zoom into Today.
private struct FocusSource: ViewModifier {
    let active: Bool
    let zoom: Namespace.ID

    func body(content: Content) -> some View {
        if active {
            // The zoom back from Today redraws only the source's bounds, and the pulsing ring
            // (and the sparkles on a finished day) reach past the node. Pad the source so they fit,
            // then take the padding back off so the layout doesn't move.
            content
                .padding(24)
                .matchedTransitionSource(id: "focus", in: zoom)
                .padding(-24)
        } else {
            content
        }
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
        let dates = unit.nodes.map(\.date)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unidad \(unit.number)")
                    .font(.rounded(.title3, weight: .black))
                if let first = dates.first, let last = dates.last {
                    Text("\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))")
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

/// A round "3D" node: a face over a darker edge. Today and the open day pulse; a finished today
/// gets a gold ring and sparkles so it's obvious the day is complete. Upcoming nodes are flat and locked.
struct PathNodeView: View {
    let status: PathNode.Status
    var isToday = false
    var isGate = false
    /// For VoiceOver: the node's day and minutes.
    var date: Date?
    var minutes = 0

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let edge: CGFloat = 6

    private var color: Color {
        if isGate { return Palette.sun }
        switch status {
        case .done: return Palette.leaf
        case .partial: return Palette.sun
        case .missed: return Palette.lilac
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
        case .missed: return "moon.zzz.fill"
        case .current: return "star.fill"
        case .unlocked: return "forward.fill"
        case .upcoming: return "lock.fill"
        }
    }

    private var size: CGFloat {
        if isGate { return 86 }
        if isToday { return 88 }
        return status == .unlocked ? 76 : 64
    }

    private var pulses: Bool { isGate || status == .current || status == .unlocked }
    private var finishedToday: Bool { isToday && status == .done }

    var body: some View {
        let raised = status != .upcoming && status != .missed
        ZStack {
            if finishedToday {
                // A gold ring with sparkles: today is complete.
                Circle()
                    .stroke(Palette.sun, lineWidth: 6)
                    .frame(width: size + 20, height: size + 20)
                    .offset(y: Self.edge / 2)
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Palette.sun)
                        .offset(y: -(size / 2 + 22))
                        .rotationEffect(.degrees(Double(index) * 60 + (pulse ? 15 : 0)))
                        .offset(y: Self.edge / 2)
                }
            } else if pulses {
                // Centred on face + edge together, so the ring sits evenly around the whole node.
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 6)
                    .frame(width: size + 22, height: size + 22)
                    .offset(y: Self.edge / 2)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .opacity(pulse ? 0.3 : 0.9)
            }
            Image(systemName: symbol)
                .font(.system(size: size * (finishedToday ? 0.44 : 0.36), weight: .black))
                .foregroundStyle(status == .upcoming || status == .missed ? Palette.secondaryText : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(color))
                .background(Circle().fill(color.edge()).offset(y: raised ? Self.edge : 0))
        }
        .padding(.bottom, Self.edge)
        .opacity(status == .upcoming ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion, pulses || finishedToday else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isGate { return "Level-up check" }
        let day = date.map { $0.formatted(.dateTime.weekday(.wide).day().month(.wide)) + ": " } ?? ""
        let done = minutes > 0 ? ", \(minutes) minutes" : ""
        return day + statusText + done
    }

    private var statusText: String {
        switch status {
        case .done: return isToday ? "Today, complete" : "Day complete"
        case .partial: return "Day partly done"
        case .missed: return "Missed day"
        case .current: return "Today"
        case .unlocked: return "Next day, open early"
        case .upcoming: return "Locked day"
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

/// The end of the drawn path: level-ups projected more than about two years out.
struct FurtherAheadCard: View {
    let milestones: [PathMilestone]

    var body: some View {
        RaisedCard(accent: Palette.sun) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Further ahead", systemImage: "binoculars.fill")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                ForEach(milestones) { milestone in
                    HStack {
                        Text("\(milestone.band.label) · \(milestone.band.rawValue)")
                        Spacer()
                        Text("around \(milestone.expectedDate.formatted(.dateTime.month(.abbreviated).year()))")
                            .foregroundStyle(Palette.secondaryText)
                    }
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                }
                Text("These appear on the path as you get closer. More listening each week brings them nearer.")
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
            }
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

/// What happened on a day: its plan (even if done early) and any other practice logged that day.
struct DaySummarySheet: View {
    let date: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.session(for: date)
        let planned = plan?.sortedTasks.filter { $0.status == .done } ?? []
        let plannedIDs = Set(planned.compactMap(\.logID))
        let others = model.logs(on: date).filter { !plannedIDs.contains($0.id) }
        let logs = model.logs
        let minutes = planned.compactMap { task in logs.first { $0.id == task.logID }?.minutes }.reduce(0, +)
            + others.reduce(0) { $0 + $1.minutes }
        VStack(alignment: .leading, spacing: 14) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.rounded(.title2, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(minutes == 0 ? "Nothing logged that day." : "\(minutes) minutes\(plan?.isComplete == true ? " · day complete" : "")")
                .font(.rounded(.headline, weight: .bold))
                .foregroundStyle(plan?.isComplete == true ? Palette.leaf : Palette.secondaryText)
            ForEach(planned) { task in
                row(symbol: TaskCopy.symbol(for: task.task), color: task.task.strand.color, title: TaskCopy.title(for: task.task),
                    minutes: logs.first { $0.id == task.logID }?.minutes ?? task.minutesPlanned)
            }
            ForEach(others) { log in
                row(symbol: log.isBonus ? "ear.fill" : TaskCopy.symbol(for: log.task), color: log.task.strand.color,
                    title: log.isBonus ? "Extra listening" : TaskCopy.title(for: log.task), minutes: log.minutes)
            }
            Spacer()
        }
        .padding(24)
        .background(Palette.background.ignoresSafeArea())
    }

    private func row(symbol: String, color: Color, title: String, minutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.rounded(.body, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("\(minutes) min")
                .font(.rounded(.subheadline, weight: .heavy))
                .foregroundStyle(Palette.secondaryText)
        }
    }
}
