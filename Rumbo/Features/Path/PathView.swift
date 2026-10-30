import RumboCore
import SwiftUI

/// Home: a winding path with one node per calendar day, in units of 7, running on into the future
/// with projected level-ups. Extra practice after today is done happens on Today ("Keep going").
/// See docs/03-experience.md §3.4 "Path".
struct PathView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var selectedDate: SelectedDay?
    /// The day summary's height; reset to half every time one opens.
    @State private var summaryDetent: PresentationDetent = .medium
    @State private var showingToday = false
    @State private var showingGate = false
    /// Bumped to play the ice-shatter on the streak flame (a freeze saved the streak).
    @State private var freezeShatters = 0
    /// Shows "1 of 2 streak freezes" under the freeze pill for a moment.
    @State private var showingFreezeTip = false
    /// Bumped to bounce the freeze pill when one is earned.
    @State private var freezeEarned = 0
    /// The unit whose banner is flipping to "¡Unidad completa!".
    @State private var celebratingUnit: Int?

    var body: some View {
        let map = model.pathMap
        let todayDone = map.todayNode?.status == .done
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(map.units) { unit in
                            UnitBanner(unit: unit, isFuture: unit.nodes.allSatisfy { $0.status == .upcoming },
                                       celebrating: celebratingUnit == unit.number)
                                .padding(.top, unit.number == 1 ? 8 : 28)
                                .padding(.bottom, 18)
                            ForEach(unit.nodes) { node in
                                nodeRow(node, todayDone: todayDone)
                                    .id(node.id)
                                if node.isToday && model.isGateOpen {
                                    gateRow(after: node.number)
                                }
                                ForEach(map.freezeMarkers.filter { $0.afterNode == node.number }) { marker in
                                    FreezeRow(marker: marker)
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
                    playMoments(map)
                }
                // Moments wait until the path is on screen again (not behind Today).
                .onChange(of: showingToday) { _, showing in
                    if !showing { playMoments(map) }
                }
                .onChange(of: map.units.filter(\.isComplete).count) {
                    if !showingToday { playMoments(map) }
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
                    // Always opens half-height; it can be pulled up when a day has lots in it.
                    .presentationDetents([.medium, .large], selection: $summaryDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.background)
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
            // The left chips use the longest wording that fits the screen, so nothing is squashed or cut off:
            // "Explorador · A2.1" + "Day done", then "A2.1" + "Day done", then "A2.1" + a tick.
            ViewThatFits(in: .horizontal) {
                leftChips(fullLevel: true, doneText: true, todayDone: todayDone)
                leftChips(fullLevel: false, doneText: true, todayDone: todayDone)
                leftChips(fullLevel: false, doneText: false, todayDone: todayDone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StatPill(symbol: "flame.fill", value: "\(model.streak.streak)", color: Palette.sun, bounce: model.streak.streak,
                     accessibilityText: "\(model.streak.streak) day streak")
                .overlay { IceShatter(trigger: freezeShatters) }
            freezePill
            StatPill(symbol: "clock.fill", value: "\(Int(model.trainingHours)) h", color: Palette.sky, bounce: Int(model.trainingHours),
                     accessibilityText: "\(Int(model.trainingHours)) training hours")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: todayDone)
    }

    /// Streak freezes held, out of the maximum. Tapping says what it is.
    private var freezePill: some View {
        let freezes = model.streak.freezes
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingFreezeTip = true }
        } label: {
            StatPill(symbol: "snowflake", value: "\(freezes)", color: Palette.ice, bounce: freezeEarned + freezeShatters,
                     accessibilityText: "\(freezes) of \(StreakCalculator.maxFreezes) streak freezes")
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showingFreezeTip {
                TipBubble(text: "\(freezes) of \(StreakCalculator.maxFreezes) streak freezes", pointsUp: true)
                    .offset(y: 40)
                    .transition(.scale(scale: 0.5, anchor: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.easeOut(duration: 0.2)) { showingFreezeTip = false }
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: showingFreezeTip)
        .zIndex(1)
    }

    private func leftChips(fullLevel: Bool, doneText: Bool, todayDone: Bool) -> some View {
        HStack(spacing: 8) {
            if let profile = model.profile {
                Text(fullLevel ? "\(profile.band.label) · \(profile.band.rawValue)" : profile.band.rawValue)
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Palette.coral))
                    .fixedSize()
                    .accessibilityLabel("\(profile.band.label), \(profile.band.rawValue)")
            }
            if todayDone {
                Group {
                    if doneText {
                        Label("Day done", systemImage: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                .font(.rounded(.subheadline, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Capsule().fill(Palette.leaf))
                .fixedSize()
                .accessibilityLabel("Day done")
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    /// One-off moments for the path: a freeze that saved the streak, and a newly completed unit.
    private func playMoments(_ map: PathMap) {
        if let day = model.takeUnseenFreeze() {
            freezeShatters += 1
            model.banner = AppModel.Banner(
                title: "🧊 A streak freeze saved you",
                message: "Nothing was logged on \(day.formatted(.dateTime.weekday(.wide))), so a freeze kept the streak going. Every second week you meet your weekly goal earns another (you can hold \(StreakCalculator.maxFreezes))."
            )
        } else if model.takeUnseenFreezeEarned() != nil {
            freezeEarned += 1
            model.banner = AppModel.Banner(
                title: "🧊 You earned a streak freeze",
                message: "Two weeks with your weekly goal met. If you miss a day, a freeze keeps your streak going. You have \(model.streak.freezes) of \(StreakCalculator.maxFreezes)."
            )
        }
        if let unit = map.units.last(where: { model.takeUnitCompletion($0) }) {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                celebratingUnit = unit.number
            }
        }
    }

    // MARK: Rows

    /// Nodes wind left and right like a trail.
    private func xOffset(_ number: Int) -> CGFloat {
        sin(Double(number - 1) * .pi / 3.5) * 80
    }

    @ViewBuilder
    private func nodeRow(_ node: PathNode, todayDone: Bool) -> some View {
        let offset = xOffset(node.number)
        let highlighted = node.isToday
        ZStack {
            Button {
                open(node)
            } label: {
                VStack(spacing: 6) {
                    PathNodeView(status: node.status, isToday: node.isToday, date: node.date, minutes: node.minutes)
                    Text(node.isToday ? "Hoy" : SpanishDate.shortDay(node.date))
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
        return nil
    }

    private func open(_ node: PathNode) {
        if node.isToday {
            model.showToday()
            showingToday = true
        } else if node.date > .now && model.session(for: node.date) != nil {
            // A day done early in an older version opens in Today, so its tasks can still be undone.
            model.selectedPlanDay = node.date
            showingToday = true
        } else {
            summaryDetent = .medium
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

/// A unit's header. A complete unit turns gold ("¡Unidad completa!"); when it has just been
/// completed (`celebrating`), the banner flips over to the gold side and the seal stamps down.
struct UnitBanner: View {
    let unit: PathUnit
    let isFuture: Bool
    var celebrating = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// During the flip: show the old (unfinished) side until it's edge-on.
    @State private var showingOldSide = false
    @State private var angle: Double = 0
    @State private var sealScale: CGFloat = 1

    var body: some View {
        let gold = unit.isComplete && !showingOldSide
        let color = gold ? Palette.sun : isFuture ? Palette.secondaryText.opacity(0.55) : Palette.sky
        let dates = unit.nodes.map(\.date)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unidad \(unit.number)")
                    .font(.rounded(.title3, weight: .black))
                if gold {
                    Text("¡Unidad completa!")
                        .font(.rounded(.subheadline, weight: .black))
                } else if let first = dates.first, let last = dates.last {
                    Text("\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.rounded(.subheadline, weight: .bold))
                        .opacity(0.85)
                }
            }
            Spacer()
            if gold {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .scaleEffect(sealScale)
            } else if isFuture {
                Image(systemName: "lock.fill").font(.title3)
            }
        }
        .foregroundStyle(gold ? Palette.inkOnBright : .white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.edge()).offset(y: 4))
        .padding(.bottom, 4)
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .onChange(of: celebrating) { _, now in
            if now { Task { await flip() } }
        }
    }

    private func flip() async {
        if !reduceMotion {
            showingOldSide = true
            withAnimation(.easeIn(duration: 0.25)) { angle = 90 }
            try? await Task.sleep(for: .milliseconds(250))
            showingOldSide = false
            angle = -90
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { angle = 0 }
            try? await Task.sleep(for: .milliseconds(350))
        }
        // The seal stamps down.
        sealScale = 2.2
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { sealScale = 1 }
        try? await Task.sleep(for: .milliseconds(120))
        Haptics.stamp()
    }
}

/// A round "3D" node: a face over a darker edge. Today pulses; a finished today
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
        case .frozen: return Palette.ice
        case .current: return Palette.coral
        case .upcoming: return Palette.lilac
        }
    }

    private var symbol: String {
        if isGate { return "trophy.fill" }
        switch status {
        case .done: return "checkmark"
        case .partial: return "circle.lefthalf.filled"
        case .missed: return "moon.zzz.fill"
        case .frozen: return "snowflake"
        case .current: return "star.fill"
        case .upcoming: return "lock.fill"
        }
    }

    private var size: CGFloat {
        if isGate { return 86 }
        if isToday { return 88 }
        return 64
    }

    private var pulses: Bool { isGate || status == .current }
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
        case .frozen: return "Missed day, saved by a streak freeze"
        case .current: return "Today"
        case .upcoming: return "Locked day"
        }
    }
}

/// A streak freeze on the path: one earned at the end of a week, or the next one still to earn.
struct FreezeRow: View {
    let marker: PathFreezeMarker

    private var earned: Bool { marker.kind == .earned }

    private var title: String { earned ? "+1 streak freeze" : "Next streak freeze" }

    private var detail: String {
        switch marker.kind {
        case .earned: "Weekly goal met for the second time"
        case .next(let left): left <= 1 ? "Meet this week's goal to earn it" : "Meet your goal this week and next"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "snowflake")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Palette.ice))
                .background(Circle().fill(Palette.ice.edge()).offset(y: 5))
                .opacity(earned ? 1 : 0.5)
            VStack(spacing: 2) {
                Text(title)
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
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
            Text(SpanishDate.longDay(date))
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
        }
        .padding(24)
        .padding(.top, 8)
        // Fill the whole sheet, so its background reaches the edges.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

/// Day names on the path in Spanish: "Lun 26" on nodes, "Lunes 26 de octubre" on a day's summary.
enum SpanishDate {
    private static let spanish = Locale(identifier: "es")

    static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().locale(spanish)).capitalizedFirstLetter
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(spanish)).capitalizedFirstLetter
    }
}

private extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}
