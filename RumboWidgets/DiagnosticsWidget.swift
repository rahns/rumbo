import SwiftUI
import WidgetKit

/// Milestone 0 widget: shows whether the widget can read data the app wrote to the App Group.
struct DiagnosticsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RumboDiagnostics", provider: DiagnosticsProvider()) { entry in
            DiagnosticsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Rumbo diagnostics")
        .description("Checks that the widget can read data from the app.")
        .supportedFamilies([.systemSmall])
    }
}

struct DiagnosticsEntry: TimelineEntry {
    let date: Date
    let appGroupAvailable: Bool
    let lastPing: Date?
}

struct DiagnosticsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiagnosticsEntry {
        DiagnosticsEntry(date: .now, appGroupAvailable: true, lastPing: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DiagnosticsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiagnosticsEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> DiagnosticsEntry {
        DiagnosticsEntry(
            date: .now,
            appGroupAvailable: SharedStore.defaults != nil,
            lastPing: SharedStore.readPing()
        )
    }
}

struct DiagnosticsWidgetView: View {
    let entry: DiagnosticsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Rumbo", systemImage: "bird.fill")
                .font(.headline)
            if !entry.appGroupAvailable {
                Text("App Group: missing")
                    .foregroundStyle(.red)
            } else if let ping = entry.lastPing {
                Text("App Group: OK")
                    .foregroundStyle(.green)
                Text(ping, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("App Group: OK, no data yet. Run diagnostics.")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
