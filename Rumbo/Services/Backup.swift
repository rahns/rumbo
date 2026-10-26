import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Manual backup: Settings → Save backup writes one JSON file; Restore reads one back.
/// Today's plan isn't included; it's rebuilt from the restored history.
struct BackupFile: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var appVersion: String
    var profile: ProfileData
    var logs: [LogData]
    var writing: [WritingData]

    struct ProfileData: Codable {
        var createdAt: Date
        var displayName: String
        var goal: String
        var targetDate: Date?
        var band: String
        var speakingStage: Int
        var weeklyGoalMinutes: Int
        var habitCue: String
        var reminderEnabled: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var travelMode: Bool
        var enabledSources: [String]
        var keepDuolingoInB2: Bool
        var baselineInputHours: Double
        var dsDifficultyLow: Int
        var dsDifficultyHigh: Int
        var languageTransferLastTrack: Int
        var languageTransferRepeatPending: Bool
        var extraEpisodesWatched: Int
        var extraPartsDoneInEpisode: Int
        var duolingoSection: Int
        var duolingoUnit: Int
    }

    struct LogData: Codable {
        var date: Date
        var task: String
        var minutes: Int
        var comprehension: Int?
        var rating: String?
        var isBonus: Bool
        var difficultyLow: Int?
        var difficultyHigh: Int?
    }

    struct WritingData: Codable {
        var date: Date
        var task: String
        var prompt: String
        var text: String
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)
        guard file.version <= currentVersion else { throw BackupError.newerVersion }
        return file
    }
}

enum BackupError: LocalizedError {
    case newerVersion
    case unreadable

    var errorDescription: String? {
        switch self {
        case .newerVersion: "This backup was made by a newer version of Rumbo. Update the app first."
        case .unreadable: "That file couldn't be read. Pick a Rumbo backup (.json)."
        }
    }
}

extension BackupFile.ProfileData {
    init(_ profile: LearnerProfile) {
        self.init(
            createdAt: profile.createdAt, displayName: profile.displayName, goal: profile.goal,
            targetDate: profile.targetDate, band: profile.currentBandRaw, speakingStage: profile.speakingStageRaw,
            weeklyGoalMinutes: profile.weeklyGoalMinutes, habitCue: profile.habitCue,
            reminderEnabled: profile.reminderEnabled, reminderHour: profile.reminderHour, reminderMinute: profile.reminderMinute,
            travelMode: profile.travelMode, enabledSources: profile.enabledSourcesRaw, keepDuolingoInB2: profile.keepDuolingoInB2,
            baselineInputHours: profile.baselineInputHours, dsDifficultyLow: profile.dsDifficultyLow, dsDifficultyHigh: profile.dsDifficultyHigh,
            languageTransferLastTrack: profile.languageTransferLastTrack, languageTransferRepeatPending: profile.languageTransferRepeatPending,
            extraEpisodesWatched: profile.extraEpisodesWatched, extraPartsDoneInEpisode: profile.extraPartsDoneInEpisode,
            duolingoSection: profile.duolingoSection, duolingoUnit: profile.duolingoUnit
        )
    }

    func makeProfile() -> LearnerProfile {
        let profile = LearnerProfile()
        profile.createdAt = createdAt
        profile.displayName = displayName
        profile.goal = goal
        profile.targetDate = targetDate
        profile.currentBandRaw = band
        profile.speakingStageRaw = speakingStage
        profile.weeklyGoalMinutes = weeklyGoalMinutes
        profile.habitCue = habitCue
        profile.reminderEnabled = reminderEnabled
        profile.reminderHour = reminderHour
        profile.reminderMinute = reminderMinute
        profile.travelMode = travelMode
        profile.enabledSourcesRaw = enabledSources
        profile.keepDuolingoInB2 = keepDuolingoInB2
        profile.baselineInputHours = baselineInputHours
        profile.dsDifficultyLow = dsDifficultyLow
        profile.dsDifficultyHigh = dsDifficultyHigh
        profile.languageTransferLastTrack = languageTransferLastTrack
        profile.languageTransferRepeatPending = languageTransferRepeatPending
        profile.extraEpisodesWatched = extraEpisodesWatched
        profile.extraPartsDoneInEpisode = extraPartsDoneInEpisode
        profile.duolingoSection = duolingoSection
        profile.duolingoUnit = duolingoUnit
        return profile
    }
}

extension BackupFile.LogData {
    init(_ log: ActivityLog) {
        self.init(date: log.date, task: log.taskRaw, minutes: log.minutes, comprehension: log.comprehension,
                  rating: log.rating, isBonus: log.isBonus, difficultyLow: log.difficultyLow, difficultyHigh: log.difficultyHigh)
    }

    func makeLog() -> ActivityLog {
        let log = ActivityLog(date: date, task: .dsWatch, minutes: minutes)
        log.taskRaw = task
        log.comprehension = comprehension
        log.rating = rating
        log.isBonus = isBonus
        log.difficultyLow = difficultyLow
        log.difficultyHigh = difficultyHigh
        return log
    }
}

/// The backup as a document for SwiftUI's file exporter (saving to Files worked on device in M0).
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func defaultFilename(on date: Date = .now) -> String {
        "Rumbo Backup \(date.formatted(.iso8601.year().month().day()))"
    }
}

/// Picks a backup file and hands back its contents. Imports a copy, so no lasting file access is needed.
struct BackupImportPicker: UIViewControllerRepresentable {
    /// Called with the file's data, `nil` if cancelled, or an error if it couldn't be read.
    let onFinish: (Result<Data, Error>?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: (Result<Data, Error>?) -> Void

        init(onFinish: @escaping (Result<Data, Error>?) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return onFinish(nil) }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                onFinish(.success(try Data(contentsOf: url)))
            } catch {
                onFinish(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(nil)
        }
    }
}
