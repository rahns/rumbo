import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The task timer on the Lock Screen and in the Dynamic Island, with Pause/Resume and Done.
struct RumboTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RumboTimerAttributes.self) { context in
            LockScreenTimer(context: context)
                .activityBackgroundTint(Palette.background)
        } dynamicIsland: { context in
            let tint = Color(uiColor: UIColor(hex: context.attributes.colorHex))
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.sourceSymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state)
                        .font(.title3.monospacedDigit().weight(.heavy))
                        .frame(width: 76, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        TimerBar(state: context.state, tint: tint)
                        TimerButtons(isPaused: context.state.isPaused, tint: tint)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.sourceSymbol)
                    .foregroundStyle(tint)
            } compactTrailing: {
                TimerText(state: context.state)
                    .monospacedDigit()
                    .frame(width: 44)
                    .foregroundStyle(tint)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(tint)
            }
            .widgetURL(URL(string: "rumbo://today"))
        }
    }
}

private struct LockScreenTimer: View {
    let context: ActivityViewContext<RumboTimerAttributes>

    var body: some View {
        let tint = Color(uiColor: UIColor(hex: context.attributes.colorHex))
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: context.attributes.sourceSymbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.taskTitle)
                        .font(.rounded(.headline, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(context.state.isPaused ? "Paused" : "Rumbo")
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundStyle(context.state.isPaused ? Palette.coral : Palette.secondaryText)
                }
                Spacer()
                TimerText(state: context.state)
                    .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ink)
                    .frame(width: 96, alignment: .trailing)
            }
            TimerBar(state: context.state, tint: tint)
            TimerButtons(isPaused: context.state.isPaused, tint: tint)
        }
        .padding(16)
    }
}

/// Counts up while running; frozen while paused.
private struct TimerText: View {
    let state: RumboTimerAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(Duration.seconds(state.pausedElapsed).formatted(.time(pattern: .minuteSecond)))
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

private struct TimerBar: View {
    let state: RumboTimerAttributes.ContentState
    let tint: Color

    var body: some View {
        if state.isPaused {
            let planned = max(state.endsAt.timeIntervalSince(state.startedAt), 1)
            ProgressView(value: min(state.pausedElapsed / planned, 1))
                .tint(tint)
        } else {
            ProgressView(timerInterval: state.startedAt...state.endsAt, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }
}

private struct TimerButtons: View {
    let isPaused: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: PauseTimerIntent()) {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .frame(maxWidth: .infinity)
            }
            .tint(Palette.secondaryText)
            Link(destination: URL(string: "rumbo://finish")!) {
                Label("Done", systemImage: "checkmark")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(tint))
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
}
