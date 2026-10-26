import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @State private var model = DiagnosticsModel()
    @State private var pickingFolder = false
    @State private var exporting = false
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
                Text("Checks · Rumbo \(DiagnosticsModel.appVersion)")
            }

            Section {
                Button("Pick iCloud Drive backup folder", systemImage: "folder.badge.plus") {
                    pickingFolder = true
                }
                Button("Save a test backup file", systemImage: "square.and.arrow.down") {
                    exporting = true
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("When picking a folder, open it first (tap into it), then tap Open.")
            }

            Section("Live Activity") {
                Button("Start test timer", systemImage: "timer") {
                    model.startTestTimer()
                }
                Button("End test timers", systemImage: "stop.circle") {
                    Task { await model.endTestTimers() }
                }
            }

            Section("Writing correction") {
                Button("Test on-device model", systemImage: "iphone") {
                    Task { await model.testWritingCorrection() }
                }
                if let sample = model.modelSample {
                    Text(sample)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                Button("Test cloud model", systemImage: "icloud") {
                    Task { await model.testCloudWritingCorrection() }
                }
                if let sample = model.cloudModelSample {
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
        .sheet(isPresented: $pickingFolder) {
            FolderPicker { url in
                pickingFolder = false
                model.folderPickerFinished(url)
            }
            .ignoresSafeArea()
        }
        .fileExporter(
            isPresented: $exporting,
            document: model.backupTestDocument,
            contentType: .json,
            defaultFilename: "rumbo-backup-test"
        ) { result in
            model.exportFinished(result)
        }
    }
}
