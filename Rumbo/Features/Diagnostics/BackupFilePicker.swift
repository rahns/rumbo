import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Document picker for Rumbo's backup file (e.g. iCloud Drive/Rumbo/Rumbo Backup.json).
///
/// - `.create` saves a new file by moving it into place (picking a folder didn't work on device).
/// - `.open` picks an existing file. Opened files come back as security-scoped URLs, which is what a
///   bookmark needs to keep working after a relaunch.
struct BackupFilePicker: UIViewControllerRepresentable {
    enum Mode {
        case create(URL)
        case open
    }

    let mode: Mode
    /// Called with the picked or saved file, or `nil` if the user cancelled.
    let onFinish: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = switch mode {
        case .create(let file): UIDocumentPickerViewController(forExporting: [file], asCopy: false)
        case .open: UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: false)
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: (URL?) -> Void

        init(onFinish: @escaping (URL?) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(nil)
        }
    }
}
