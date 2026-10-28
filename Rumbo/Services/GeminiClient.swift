import Foundation
import RumboCore

/// The learner's Gemini API key, kept in the Keychain on this phone only (never in backups).
enum GeminiKey {
    private static let account = "gemini.apiKey"

    static var current: String? {
        guard let data = KeychainShare.read(forKey: account).data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        return key
    }

    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainShare.delete(forKey: account)
        } else {
            KeychainShare.write(Data(trimmed.utf8), forKey: account)
        }
    }

    static func remove() { KeychainShare.delete(forKey: account) }
}

/// Sends writing to Gemini (request and reply handling are in RumboCore's `Gemini`).
enum GeminiClient {
    static func correct(_ text: String, band: Band, prompt: String, key: String) async throws -> CorrectionService.Result {
        let input = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        let reply = try await send(input: input, instructions: CorrectionService.instructions(for: band), key: key)
        let feedback = try Gemini.feedback(from: reply.text)
        return CorrectionService.Result(
            corrections: Mistakes.merge(model: feedback.corrections, languageTool: []),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: reply.model == Gemini.models.first ? "Gemini" : "Gemini (lighter model)"
        )
    }

    /// A tiny request to check a key works. Returns nil when it does, or what's wrong.
    static func test(key: String) async -> String? {
        do {
            _ = try await send(input: "Escribe: «Ayer fui a la playa.»", instructions: "Reply with the JSON asked for.", key: key)
            return nil
        } catch Gemini.Failure.rateLimited {
            // The key is real; it's just out of free requests for now.
            return nil
        } catch Gemini.Failure.invalidKey {
            return "Google didn't accept that key. Check you copied all of it."
        } catch {
            return "Couldn't reach Gemini: \(error.localizedDescription)"
        }
    }

    /// Tries each model in turn: each has its own free quota, so the lighter one covers when the first is used up.
    private static func send(input: String, instructions: String, key: String) async throws -> (text: String, model: String) {
        var lastError: Error = Gemini.Failure.rateLimited
        for model in Gemini.models {
            var request = URLRequest(url: Gemini.endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = Gemini.requestBody(model: model, instructions: instructions, input: input)
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch Gemini.failure(status: status, body: data) {
            case nil:
                return (try Gemini.outputText(from: data), model)
            case .rateLimited?, .modelUnavailable?:
                lastError = Gemini.failure(status: status, body: data)!
                continue
            case let failure?:
                throw failure
            }
        }
        throw lastError
    }

    /// The small warning shown above feedback from the basic checker.
    static func notice(for error: Error) -> String {
        switch error {
        case Gemini.Failure.rateLimited:
            "You've used Gemini's free limit for now, so the basic checker did this one. It's less accurate. The limit resets daily."
        case Gemini.Failure.invalidKey:
            "Gemini didn't accept your API key, so the basic checker did this one. Check the key in Settings → Writing feedback."
        case Gemini.Failure.modelUnavailable:
            "Gemini's models aren't available to your key right now, so the basic checker did this one."
        case let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost:
            "You're offline, so the basic checker did this one. It's less accurate than Gemini."
        default:
            "Gemini couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}
