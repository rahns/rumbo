import Security
import SwiftUI
import WidgetKit

/// Milestone 0 widget: shows whether the widget can read data the app wrote,
/// through the App Group and through the shared Keychain group.
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
    let appGroupPing: Date?
    let keychainPing: Date?
    let keychainStatus: OSStatus
}

struct DiagnosticsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiagnosticsEntry {
        DiagnosticsEntry(date: .now, appGroupAvailable: true, appGroupPing: .now, keychainPing: .now, keychainStatus: errSecSuccess)
    }

    func getSnapshot(in context: Context, completion: @escaping (DiagnosticsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiagnosticsEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> DiagnosticsEntry {
        let keychain = SharedStore.readKeychainPing()
        return DiagnosticsEntry(
            date: .now,
            appGroupAvailable: SharedStore.defaults != nil,
            appGroupPing: SharedStore.readAppGroupPing(),
            keychainPing: keychain.date,
            keychainStatus: keychain.status
        )
    }
}

struct DiagnosticsWidgetView: View {
    let entry: DiagnosticsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Rumbo", systemImage: "bird.fill")
                .font(.headline)
            row("Group", ok: entry.appGroupPing != nil,
                detail: entry.appGroupAvailable ? (entry.appGroupPing == nil ? "no data" : nil) : "missing")
            row("Keychain", ok: entry.keychainPing != nil,
                detail: entry.keychainPing == nil ? "err \(entry.keychainStatus)" : nil)
            if let ping = entry.keychainPing ?? entry.appGroupPing {
                Text(ping, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ title: String, ok: Bool, detail: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(title)
            if let detail {
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}
