import ActivityKit
import Foundation
import FoundationModels
import Observation
import Security
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
    case keychainShare = "Keychain sharing (widgets fallback)"
    case liveActivities = "Live Activities"
    case notifications = "Notifications"
    case onDeviceModel = "Apple on-device model"
    case languageTool = "LanguageTool"
    case urlSchemes = "Source apps installed"

    var id: String { rawValue }
}

@MainActor
@Observable
final class DiagnosticsModel {
    var results: [CheckID: CheckStatus] = [:]
    var modelSample: String?
    var isRunning = false

    private let profile = ProvisioningProfile.embedded()

    func status(_ id: CheckID) -> CheckStatus {
        results[id] ?? .pending
    }

    func runAll() async {
        isRunning = true
        defer { isRunning = false }

        results[.profile] = checkProfile()
        let ping = SharedStore.writePing()
        results[.keychainShare] = checkKeychainShare(status: ping.keychain)
        WidgetCenter.shared.reloadAllTimelines()
        results[.liveActivities] = checkLiveActivities()
        results[.notifications] = await checkNotifications()
        results[.onDeviceModel] = checkOnDeviceModel()
        results[.languageTool] = await checkLanguageTool()
        results[.urlSchemes] = checkURLSchemes()
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
        let appID = profile.strings(for: "application-identifier").joined(separator: ", ")
        let keychainGroups = profile.strings(for: "keychain-access-groups").joined(separator: ", ")
        text += "\nApp ID: \(appID.isEmpty ? "none" : appID)"
        text += "\nKeychain groups: \(keychainGroups.isEmpty ? "none" : keychainGroups)"
        text += "\nBundle ID: \(Bundle.main.bundleIdentifier ?? "?")"
        return .pass(text)
    }

    private func checkKeychainShare(status: OSStatus) -> CheckStatus {
        let group = KeychainShare.defaultGroup ?? "unknown"
        guard status == errSecSuccess else {
            return .fail("Write failed: \(KeychainShare.describe(status)). App's default group: \(group)")
        }
        return .pass("Wrote to the default group \(group). The diagnostics widget should show a ✓ for Keychain and the same group.")
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
        do {
            let matches = try await LanguageToolProbe.check("Ella son muy alto y yo tengo veinte año.")
            let first = matches.first?.message ?? "none"
            return .pass("\(matches.count) errors found. First: \(first)")
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

    // MARK: - Live Activity

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

    // MARK: - Writing correction

    private static let sampleText = "Ayer yo voy a la playa con mis amigo y nosotros comimos mucho pescados."

    /// The planned M4 pipeline in miniature: LanguageTool finds errors, the on-device model explains them
    /// with structured output, and corrections that don't change anything are dropped.
    func testWritingCorrection() async {
        modelSample = "Thinking…"
        let hints = (try? await LanguageToolProbe.check(Self.sampleText)) ?? []
        var prompt = "Learner's text:\n\(Self.sampleText)"
        if !hints.isEmpty {
            prompt += "\n\nA grammar checker flagged:\n" + hints.map { "- «\($0.flaggedText(in: Self.sampleText))»: \($0.message)" }.joined(separator: "\n")
        }
        do {
            let session = LanguageModelSession(instructions: """
                You are a friendly Spanish tutor for an A2 learner. Find every real error in the learner's text. \
                Check that each verb tense matches the time expressions (for example "ayer" needs the preterite), \
                and check gender and number agreement. Use the grammar checker's hints when given. \
                Never list something that is already correct.
                """)
            let feedback = try await session.respond(to: prompt, generating: WritingFeedback.self).content
            let real = feedback.errors.filter {
                $0.original.trimmingCharacters(in: .whitespaces).lowercased() != $0.corrected.trimmingCharacters(in: .whitespaces).lowercased()
            }
            var lines = real.map { "• \($0.original) → \($0.corrected): \($0.explanation)" }
            let dropped = feedback.errors.count - real.count
            if dropped > 0 { lines.append("(dropped \(dropped) non-changes)") }
            lines.append("Rewrite: \(feedback.naturalRewrite)")
            lines.append("LanguageTool hints used: \(hints.count)")
            modelSample = lines.joined(separator: "\n")
        } catch {
            modelSample = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Report

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var report: String {
        var lines = ["Rumbo \(Self.appVersion) diagnostics · \(Date.now.formatted())",
                     "iOS \(UIDevice.current.systemVersion)"]
        for id in CheckID.allCases {
            let status = status(id)
            lines.append("\(status.symbol) \(id.rawValue): \(status.detail)")
        }
        if let modelSample {
            lines.append("\nWriting correction sample:\n\(modelSample)")
        }
        return lines.joined(separator: "\n")
    }
}

@Generable
struct WritingFeedback {
    @Guide(description: "Each real error in the learner's text, most important first. Skip anything already correct.")
    var errors: [WritingError]
    @Guide(description: "The whole text rewritten the way a native speaker would say it.")
    var naturalRewrite: String
}

@Generable
struct WritingError {
    @Guide(description: "The exact wrong words from the learner's text.")
    var original: String
    @Guide(description: "The corrected words. Must be different from original.")
    var corrected: String
    @Guide(description: "One short sentence in English explaining the rule.")
    var explanation: String
}

enum LanguageToolProbe {
    struct Match: Decodable {
        let message: String
        let offset: Int
        let length: Int

        func flaggedText(in text: String) -> String {
            let characters = Array(text)
            guard offset >= 0, offset + length <= characters.count else { return "" }
            return String(characters[offset..<offset + length])
        }
    }

    private struct Response: Decodable {
        let matches: [Match]
    }

    static func check(_ text: String) async throws -> [Match] {
        var request = URLRequest(url: URL(string: "https://api.languagetool.org/v2/check")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "text", value: text),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).matches
    }
}
