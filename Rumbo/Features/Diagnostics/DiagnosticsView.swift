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
                Button("Test each model and method", systemImage: "square.grid.2x2") {
                    Task { await model.probeGeminiModels() }
                }
                .disabled(model.geminiRunning)
                LabeledContent("Resting", value: model.geminiRestingSummary)
                    .font(.footnote)
                Button("Clear rests", systemImage: "arrow.uturn.backward") {
                    model.clearGeminiResting()
                }
                if let trace = model.geminiTrace {
                    Text(trace)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                Text("Gemini")
            } footer: {
                Text("Trace a full check runs a writing check exactly like a task: which model goes first, streaming or one piece, when the first event arrived, thinking updates, the longest silence, and any fallback. Test each model and method tries Flash-Lite and Flash, streaming and in one piece, directly (uses 4 free requests). A model that was busy or stuck rests for 30 minutes; Clear rests lets it go first again.")
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
