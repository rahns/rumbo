import ActivityKit
import CloudKit
import Foundation
import FoundationModels
import Observation
import UIKit
import UserNotifications
import WidgetKit

enum CheckStatus: Equatable {
    case pending
    case pass(String)
    case warn(String)
    case fail(String)

    var symbol: String {
        switch self {
        case .pending: "⏳"
        case .pass: "✅"
        case .warn: "⚠️"
        case .fail: "❌"
        }
    }

    var detail: String {
        switch self {
        case .pending: "Not run yet"
        case .pass(let text), .warn(let text), .fail(let text): text
        }
    }
}

enum CheckID: String, CaseIterable, Identifiable {
    case profile = "Signing profile"
    case iCloudAccount = "iCloud account"
    case cloudKit = "CloudKit sync"
    case appGroup = "App Group (widgets)"
    case push = "Push entitlement"
    case liveActivities = "Live Activities"
    case notifications = "Notifications"
    case onDeviceModel = "Apple on-device model"
    case cloudModel = "Apple cloud model (PCC)"
    case languageTool = "LanguageTool"
    case urlSchemes = "Source apps installed"
    case driveFolder = "iCloud Drive backup folder"

    var id: String { rawValue }
}

@MainActor
@Observable
final class DiagnosticsModel {
    var results: [CheckID: CheckStatus] = [:]
    var modelSample: String?
    var isRunning = false

    private let profile = ProvisioningProfile.embedded()
    private static let driveBookmarkKey = "backup.folderBookmark"

    func status(_ id: CheckID) -> CheckStatus {
        results[id] ?? .pending
    }

    func runAll() async {
        isRunning = true
        defer { isRunning = false }

        results[.profile] = checkProfile()
        results[.iCloudAccount] = checkICloudAccount()
        results[.cloudKit] = await checkCloudKit()
        results[.appGroup] = checkAppGroup()
        results[.push] = checkPush()
        results[.liveActivities] = checkLiveActivities()
        results[.notifications] = await checkNotifications()
        results[.onDeviceModel] = checkOnDeviceModel()
        results[.cloudModel] = CloudModelProbe.isAvailable
            ? .pass("Available")
            : .fail("Not available. Will use the on-device model instead.")
        results[.languageTool] = await checkLanguageTool()
        results[.urlSchemes] = checkURLSchemes()
        if results[.driveFolder] == nil {
            results[.driveFolder] = checkSavedDriveFolder()
        }
    }

    // MARK: - Checks

    private func checkProfile() -> CheckStatus {
        guard let profile else {
            return .warn("No embedded profile found. Entitlement checks below rely on runtime tests only.")
        }
        var text = "\(profile.name) · \(profile.teamName)"
        if let expiration = profile.expiration {
            text += " · expires \(expiration.formatted(date: .abbreviated, time: .omitted))"
        }
        return .pass(text)
    }

    private func checkICloudAccount() -> CheckStatus {
        FileManager.default.ubiquityIdentityToken != nil
            ? .pass("Signed in to iCloud")
            : .warn("No iCloud account available to this app")
    }

    private func checkCloudKit() async -> CheckStatus {
        // Creating a CKContainer for a container the app isn't entitled to crashes, so check the profile first.
        guard let profile,
              profile.grants("com.apple.developer.icloud-container-identifiers", SharedStore.cloudContainerID),
              profile.grants("com.apple.developer.icloud-services", "CloudKit")
        else {
            return .fail("Profile doesn't grant \(SharedStore.cloudContainerID). Rumbo will use the iCloud Drive backup.")
        }
        do {
            let status = try await CKContainer(identifier: SharedStore.cloudContainerID).accountStatus()
            switch status {
            case .available: return .pass("Container reachable, account available")
            case .noAccount: return .warn("Entitled, but no iCloud account signed in")
            case .restricted: return .warn("Entitled, but iCloud is restricted")
            case .temporarilyUnavailable: return .warn("Entitled, iCloud temporarily unavailable")
            case .couldNotDetermine: return .warn("Entitled, status could not be determined")
            @unknown default: return .warn("Entitled, unknown account status")
            }
        } catch {
            return .fail("CloudKit error: \(error.localizedDescription)")
        }
    }

    private func checkAppGroup() -> CheckStatus {
        guard SharedStore.writePing() else {
            return .fail("App Group container unavailable. Widgets can't read today's plan.")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .pass("Shared container works. Add the Rumbo diagnostics widget to confirm it shows \"App Group: OK\".")
    }

    private func checkPush() -> CheckStatus {
        guard let profile else { return .warn("Unknown (no profile)") }
        let values = profile.strings(for: "aps-environment")
        return values.isEmpty
            ? .warn("Not granted. CloudKit sync would only update when the app opens.")
            : .pass("aps-environment: \(values.joined(separator: ", "))")
    }

    private func checkLiveActivities() -> CheckStatus {
        ActivityAuthorizationInfo().areActivitiesEnabled
            ? .pass("Enabled. Use \"Start test timer\" to see the Dynamic Island.")
            : .fail("Disabled in Settings or unsupported")
    }

    private func checkNotifications() async -> CheckStatus {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .pass("Allowed") : .warn("Not allowed")
        } catch {
            return .fail(error.localizedDescription)
        }
    }

    private func checkOnDeviceModel() -> CheckStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .pass("Available. Use \"Test writing correction\" for a sample.")
        case .unavailable(let reason):
            return .fail("Unavailable: \(String(describing: reason))")
        }
    }

    private func checkLanguageTool() async -> CheckStatus {
        struct Response: Decodable {
            struct Match: Decodable { let message: String }
            let matches: [Match]
        }

        var request = URLRequest(url: URL(string: "https://api.languagetool.org/v2/check")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "text", value: "Ella son muy alto y yo tengo veinte año."),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return .fail("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let first = decoded.matches.first?.message ?? "none"
            return .pass("\(decoded.matches.count) errors found. First: \(first)")
        } catch {
            return .fail("Offline or blocked: \(error.localizedDescription)")
        }
    }

    private func checkURLSchemes() -> CheckStatus {
        let schemes = ["duolingo", "youtube", "dreamingspanish", "dreaming", "languagetransfer", "tandem", "spotify"]
        let found = schemes.filter { UIApplication.shared.canOpenURL(URL(string: "\($0)://")!) }
        return found.isEmpty
            ? .warn("None of the tested URL schemes opened. Rumbo will use web links.")
            : .pass("Opens: \(found.joined(separator: ", "))")
    }

    private func checkSavedDriveFolder() -> CheckStatus {
        guard let data = UserDefaults.standard.data(forKey: Self.driveBookmarkKey) else {
            return .pending
        }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
            return .fail("Saved folder can't be resolved. Pick it again.")
        }
        return writeTestFile(in: url)
    }

    // MARK: - Actions

    func useDriveFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            results[.driveFolder] = .fail("No permission for that folder")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        if let bookmark = try? url.bookmarkData() {
            UserDefaults.standard.set(bookmark, forKey: Self.driveBookmarkKey)
        }
        results[.driveFolder] = writeTestFile(in: url)
    }

    private func writeTestFile(in folder: URL) -> CheckStatus {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appendingPathComponent("rumbo-backup-test.json")
        do {
            let payload = #"{"app":"Rumbo","test":true,"date":"\#(Date.now.ISO8601Format())"}"#
            try Data(payload.utf8).write(to: file, options: .atomic)
            return .pass("Wrote \(file.lastPathComponent) to \(folder.lastPathComponent)")
        } catch {
            return .fail("Couldn't write: \(error.localizedDescription)")
        }
    }

    func startTestTimer() {
        let now = Date.now
        let attributes = RumboTimerAttributes(taskTitle: "Dreaming Spanish", sourceSymbol: "play.tv.fill")
        let state = RumboTimerAttributes.ContentState(startedAt: now, endsAt: now.addingTimeInterval(10 * 60))
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            results[.liveActivities] = .pass("Test timer started. Lock the phone or go home to see it.")
        } catch {
            results[.liveActivities] = .fail("Couldn't start: \(error.localizedDescription)")
        }
    }

    func endTestTimers() async {
        for activity in Activity<RumboTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func testWritingCorrection() async {
        modelSample = "Thinking…"
        do {
            let session = LanguageModelSession(instructions: """
                You are a friendly Spanish tutor for an A2 learner. Correct the learner's text. \
                List each error with the fix and a one-sentence explanation in English, then give a natural rewrite.
                """)
            let response = try await session.respond(to: "Ayer yo voy a la playa con mis amigo y nosotros comimos mucho pescados.")
            modelSample = response.content
        } catch {
            modelSample = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Report

    var report: String {
        var lines = ["Rumbo diagnostics · \(Date.now.formatted())",
                     "iOS \(UIDevice.current.systemVersion)"]
        for id in CheckID.allCases {
            let status = status(id)
            lines.append("\(status.symbol) \(id.rawValue): \(status.detail)")
        }
        if let modelSample {
            lines.append("\nOn-device model sample:\n\(modelSample)")
        }
        return lines.joined(separator: "\n")
    }
}
