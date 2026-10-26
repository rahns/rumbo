import SwiftUI
import UIKit

/// Lets the user choose where Rumbo's backup file lives (e.g. iCloud Drive/Rumbo).
///
/// Uses the document picker in *move* mode (`asCopy: false`): the file is moved to the chosen place and
/// the picker hands back a security-scoped URL to it, which can be bookmarked and rewritten later.
/// Choosing a folder didn't work on device; saving a file does.
struct BackupFilePicker: UIViewControllerRepresentable {
    /// The freshly written file to move into place.
    let file: URL
    /// Called with the file's new location, or `nil` if the user cancelled.
    let onFinish: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: false)
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
