import ActivityKit
import SwiftUI
import WidgetKit

struct RumboTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RumboTimerAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.attributes.sourceSymbol)
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                    ProgressView(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.orange)
                }
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .font(.title3.monospacedDigit())
                    .frame(width: 70, alignment: .trailing)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.sourceSymbol)
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                        .font(.title3.monospacedDigit())
                        .frame(width: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.orange)
                }
            } compactLeading: {
                Image(systemName: context.attributes.sourceSymbol)
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
}
