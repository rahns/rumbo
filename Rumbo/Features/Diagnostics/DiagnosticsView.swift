import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @State private var model = DiagnosticsModel()
    @State private var copied = false
    @State private var practicingGate = false

    var body: some View {
        List {
            Group {
            Section {
                ForEach(CheckID.allCases) { id in
                    let status = model.status(id)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(status.symbol)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(id.rawValue).font(.body.weight(.semibold))
                            Text(status.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .animation(.snappy, value: status)
                }
            } header: {
                Text("Checks · Rumbo \(DiagnosticsModel.appVersion)")
            }

            Section("Live Activity") {
                Button("Start test timer", systemImage: "timer") {
                    model.startTestTimer()
                }
                Button("End test timers", systemImage: "stop.circle") {
                    Task { await model.endTestTimers() }
                }
            }

            Section {
                Button("Practice level-up check", systemImage: "trophy") {
                    practicingGate = true
                }
            } header: {
                Text("Level up")
            } footer: {
                Text("Runs the real check for your next level, but nothing is saved: your level stays the same.")
            }

            Section("Writing correction") {
                Button("Test writing correction", systemImage: "text.badge.checkmark") {
                    Task { await model.testWritingCorrection() }
                }
                if let sample = model.modelSample {
                    Text(sample)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }

            Section {
                Button("Trace a full check", systemImage: "list.bullet.rectangle") {
                    Task { await model.traceGeminiCheck() }
                }
                .disabled(model.geminiRunning)
                Button("Test streaming and one piece", systemImage: "square.split.2x1") {
                    Task { await model.probeGeminiMethods() }
                }
                .disabled(model.geminiRunning)
                if let trace = model.geminiTrace {
                    Text(trace)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                Text("Gemini")
            } footer: {
                Text("Trace a full check runs a writing check exactly like a task: streaming or one piece, when the first event arrived, thinking updates, the longest silence, and any retry or fallback. Test streaming and one piece asks Gemini Flash-Lite both ways, directly (uses 2 free requests).")
            }

            Section {
                Button(copied ? "Copied" : "Copy report", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = model.report
                    copied = true
                }
                .sensoryFeedback(.success, trigger: copied)
            } footer: {
                Text("Paste the report back into your Claude session.")
            }
            }
            .rumboRows()
        }
        .rumboListBackground()
        .navigationTitle("Diagnostics")
        .toolbar {
            Button("Run", systemImage: "arrow.clockwise") {
                Task { await model.runAll() }
            }
            .disabled(model.isRunning)
        }
        .task { await model.runAll() }
        .fullScreenCover(isPresented: $practicingGate) {
            GateView(isPractice: true)
        }
    }
}
