import ActivityKit
import Foundation
import FoundationModels
import Observation
import RumboCore
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
    case gemini = "Gemini API key"
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
    /// Step-by-step output of the Gemini tests.
    var geminiTrace: String?
    var geminiRunning = false
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
        results[.gemini] = await checkGemini()
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

    private func checkGemini() async -> CheckStatus {
        guard let key = GeminiKey.current else {
            return .warn("Not set up. Writing is checked by the basic checker. Add a key in Settings → Writing feedback.")
        }
        let result = await GeminiClient.test(key: key)
        return result.works ? .pass("\(result.message) Use \"Test writing correction\" for a sample.") : .fail(result.message)
    }

    private func checkOnDeviceModel() -> CheckStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .pass("Available (used when Gemini isn't set up or can't answer).")
        case .unavailable(let reason):
            return .fail("Unavailable: \(String(describing: reason))")
        }
    }

    private func checkLanguageTool() async -> CheckStatus {
        do {
            let matches = try await LanguageTool.check("Ella son muy alto y yo tengo veinte año.")
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
        let attributes = RumboTimerAttributes(taskTitle: "Dreaming Spanish", sourceSymbol: "play.tv.fill", colorHex: 0xF25C4A)
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

    /// Runs the real writing-correction pipeline (CorrectionService) on a sample with known errors.
    func testWritingCorrection() async {
        modelSample = "Thinking…"
        do {
            let result = try await CorrectionService.correct(Self.sampleText, band: .a2_1, prompt: "Write about yesterday.")
            var lines = result.corrections.map { "• \($0.original) → \($0.corrected): \($0.explanation) [\($0.source)]" }
            if !result.naturalRewrite.isEmpty { lines.append("Rewrite: \(result.naturalRewrite)") }
            lines += result.strengths.map { "✓ \($0)" }
            lines.append("Engine: \(result.engine)")
            if let notice = result.notice { lines.append("⚠️ \(notice)") }
            modelSample = lines.joined(separator: "\n")
        } catch {
            modelSample = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Gemini

    /// A full writing check exactly as a task runs it, with every step: order, model, method, timings, fallback.
    func traceGeminiCheck() async {
        geminiRunning = true
        defer { geminiRunning = false }
        geminiTrace = "Running a full check…"
        let (result, trace) = await GeminiClient.traced(Self.sampleText, band: .a2_1, prompt: "Write about yesterday.")
        var lines = ["Full check" + (GeminiKey.current == nil ? " (no Gemini key: basic checker only)" : "")] + trace
        switch result {
        case .success(let feedback):
            lines.append("Checked by: \(feedback.engine)")
            if let notice = feedback.notice { lines.append("⚠️ \(notice)") }
            lines += feedback.corrections.map { "• \($0.original) → \($0.corrected)" }
        case .failure(let error):
            lines.append("❌ \(error.localizedDescription)")
        }
        geminiTrace = lines.joined(separator: "\n")
    }

    /// Streaming and one piece, directly (no retry or fallback). Uses 2 of the free requests.
    func probeGeminiMethods() async {
        guard let key = GeminiKey.current else {
            geminiTrace = "No Gemini key. Add one in Settings → Writing feedback."
            return
        }
        geminiRunning = true
        defer { geminiRunning = false }
        var lines: [String] = []
        for stream in [true, false] {
            let label = "\(Gemini.displayName) · \(stream ? "streaming" : "one piece")"
            lines.append("— \(label): running…")
            geminiTrace = lines.joined(separator: "\n")
            let (ok, trace) = await GeminiClient.probe(stream: stream, key: key)
            lines.removeLast()
            lines.append("— \(label): \(ok ? "✅ works" : "❌ failed")")
            lines += trace
            geminiTrace = lines.joined(separator: "\n")
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
        if let geminiTrace {
            lines.append("\nGemini:\n\(geminiTrace)")
        }
        return lines.joined(separator: "\n")
    }
}
