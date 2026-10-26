import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @State private var model = DiagnosticsModel()
    @State private var pickingFolder = false
    @State private var copied = false

    var body: some View {
        List {
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
                Text("Checks")
            }

            Section("Try it") {
                Button("Pick iCloud Drive backup folder", systemImage: "folder.badge.plus") {
                    pickingFolder = true
                }
                Button("Start test timer", systemImage: "timer") {
                    model.startTestTimer()
                }
                Button("End test timers", systemImage: "stop.circle") {
                    Task { await model.endTestTimers() }
                }
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
                Button(copied ? "Copied" : "Copy report", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = model.report
                    copied = true
                }
                .sensoryFeedback(.success, trigger: copied)
            } footer: {
                Text("Paste the report back into your Claude session.")
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            Button("Run", systemImage: "arrow.clockwise") {
                Task { await model.runAll() }
            }
            .disabled(model.isRunning)
        }
        .task { await model.runAll() }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                model.useDriveFolder(url)
            }
        }
    }
}
