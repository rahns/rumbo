import Foundation
import RumboCore

/// The learner's free Groq key, kept in the Keychain and saved in backups. Groq is the backup checker.
enum GroqKey {
    private static let account = "groq.apiKey"

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

/// Sends writing to Groq (request and reply handling are in RumboCore's `Groq`). One request, not streamed:
/// Groq's structured outputs don't stream, and it answers in a few seconds.
enum GroqClient {
    static func correct(_ text: String, band: Band, prompt: String, key: String) async throws -> CorrectionService.Result {
        let input = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        let reply = try await send(input: input, instructions: CorrectionService.instructions(for: band), key: key)
        let feedback = try Gemini.feedback(from: reply)
        return CorrectionService.Result(
            corrections: Mistakes.merge(model: feedback.corrections, languageTool: []),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: Groq.displayName
        )
    }

    /// A tiny request to check a key works. Busy or rate-limited replies still mean Groq accepted the key.
    static func test(key: String) async -> (works: Bool, message: String) {
        do {
            _ = try await send(input: "Escribe: «Ayer fui a la playa.»", instructions: "Reply with the JSON asked for.", key: key)
            return (true, "It works. Groq will check your writing whenever Gemini can't.")
        } catch Gemini.Failure.rateLimited {
            return (true, "Your key works, but its free limit is used up for now. It resets soon.")
        } catch Gemini.Failure.busy {
            return (true, "Your key works. Groq is busy right now; try a check again in a minute.")
        } catch Gemini.Failure.timedOut {
            return (false, "Groq didn't answer in time, so the key isn't confirmed yet. Try again in a minute.")
        } catch Gemini.Failure.invalidKey {
            return (false, "Groq didn't accept that key. Check you copied all of it.")
        } catch {
            return (false, "Couldn't reach Groq: \(error.localizedDescription)")
        }
    }

    /// One request; if Groq is busy, waits 2 seconds and asks once more.
    private static func send(input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await attempt(input: input, instructions: instructions, key: key)
        } catch Gemini.Failure.busy {
            GeminiTrace.log("Groq busy: waiting 2 s, then trying once more")
            try await Task.sleep(for: .seconds(2))
            return try await attempt(input: input, instructions: instructions, key: key)
        }
    }

    private static func attempt(input: String, instructions: String, key: String) async throws -> String {
        var request = URLRequest(url: Groq.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = Groq.requestBody(instructions: instructions, input: input, thinking: GeminiKey.thinkingLevel)
        GeminiTrace.log("\(Groq.displayName) · one piece · \(GeminiKey.thinkingLevel.rawValue) reasoning: sent")
        let started = Date.now
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            GeminiTrace.log("Groq HTTP \(status) after \(String(format: "%.1f", Date.now.timeIntervalSince(started))) s")
            if let failure = Groq.failure(status: status, body: data) { throw failure }
            let text = try Groq.outputText(from: data)
            GeminiTrace.log("Groq answered (\(text.count) characters)")
            return text
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            GeminiTrace.log("Groq: no answer in time")
            throw Gemini.Failure.timedOut
        } catch {
            GeminiTrace.log("Groq failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// The warning above feedback when the basic checker had to do it, after Groq (and maybe Gemini) failed.
    static func notice(for error: Error, geminiAlsoFailed: Bool) -> String {
        let who = geminiAlsoFailed ? "Gemini and Groq" : "Groq"
        return switch error {
        case Gemini.Failure.rateLimited:
            geminiAlsoFailed
                ? "Gemini and Groq are both at their free limits for now, so the basic checker did this one. It's less accurate."
                : "You've used Groq's free limit for now, so the basic checker did this one. It's less accurate."
        case Gemini.Failure.invalidKey:
            "Groq didn't accept your API key, so the basic checker did this one. Check it in Settings → Writing feedback."
        case Gemini.Failure.busy, Gemini.Failure.timedOut:
            "\(who) \(geminiAlsoFailed ? "are" : "is") busy right now, so the basic checker did this one. Try checking again in a minute."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            "You're offline, so the basic checker did this one. It's less accurate."
        default:
            "\(who) couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}
