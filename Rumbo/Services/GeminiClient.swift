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

    /// A tiny request to check a key works. Busy or rate-limited replies still mean Google accepted the key.
    static func test(key: String) async -> (works: Bool, message: String) {
        do {
            _ = try await send(input: "Escribe: «Ayer fui a la playa.»", instructions: "Reply with the JSON asked for.", key: key)
            return (true, "It works. Pico will use Gemini to check your writing.")
        } catch Gemini.Failure.rateLimited {
            return (true, "Your key works, but its free limit is used up for now. Pico uses the basic checker until it resets.")
        } catch Gemini.Failure.busy {
            return (true, "Your key works. Gemini is busy right now, so a check may use the basic checker until it calms down.")
        } catch Gemini.Failure.timedOut {
            return (false, "Gemini didn't answer in time, so the key isn't confirmed yet. Google is probably busy: try again in a minute.")
        } catch Gemini.Failure.invalidKey {
            return (false, "Google didn't accept that key. Check you copied all of it.")
        } catch {
            return (false, "Couldn't reach Gemini: \(error.localizedDescription)")
        }
    }

    /// Tries each model in turn: each has its own free quota and load, so the lighter one covers when the first is
    /// used up, busy or too slow. A model that failed rests for 30 minutes (tried last), so checks don't keep waiting on it. If they're all just busy and there's time left, waits 2 seconds and goes round once more.
    private static func send(input: String, instructions: String, key: String) async throws -> (text: String, model: String) {
        let started = Date.now
        // When every model fails, report the most useful reason: out of free requests, then busy, then slow, then unavailable.
        var lastError: Gemini.Failure = .modelUnavailable
        func note(_ failure: Gemini.Failure) {
            let rank: [Gemini.Failure: Int] = [.rateLimited: 3, .busy: 2, .timedOut: 1, .modelUnavailable: 0]
            if rank[failure, default: 0] >= rank[lastError, default: 0] { lastError = failure }
        }
        for round in 0..<2 {
            if round > 0 {
                guard lastError == .busy, Date.now.timeIntervalSince(started) < 15 else { break }
                try await Task.sleep(for: .seconds(2))
            }
            for (index, model) in Gemini.order(resting: resting).enumerated() {
                var request = URLRequest(url: Gemini.endpoint)
                request.httpMethod = "POST"
                // Short enough that the lighter model still gets its turn while Pico is "reading".
                request.timeoutInterval = index == 0 ? 25 : 20
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                request.httpBody = Gemini.requestBody(model: model, instructions: instructions, input: input)
                let data: Data, response: URLResponse
                do {
                    (data, response) = try await URLSession.shared.data(for: request)
                } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                    note(.timedOut)
                    rest(model)
                    continue
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                switch Gemini.failure(status: status, body: data) {
                case nil:
                    return (try Gemini.outputText(from: data), model)
                case let failure? where [.rateLimited, .busy, .modelUnavailable].contains(failure):
                    note(failure)
                    rest(model)
                case let failure?:
                    throw failure
                }
            }
        }
        throw lastError
    }

    // MARK: Resting busy models

    private static let restingKey = "gemini.restingUntil"

    /// Models resting after a failure, and until when (kept across launches).
    private static var resting: [String: Date] {
        (UserDefaults.standard.dictionary(forKey: restingKey) as? [String: Date]) ?? [:]
    }

    private static func rest(_ model: String) {
        var resting = resting
        resting[model] = Date.now.addingTimeInterval(Gemini.restAfterFailure)
        UserDefaults.standard.set(resting, forKey: restingKey)
    }

    /// The small warning shown above feedback from the basic checker.
    static func notice(for error: Error) -> String {
        switch error {
        case Gemini.Failure.rateLimited:
            "You've used Gemini's free limit for now, so the basic checker did this one. It's less accurate. The limit resets daily."
        case Gemini.Failure.invalidKey:
            "Gemini didn't accept your API key, so the basic checker did this one. Check the key in Settings → Writing feedback."
        case Gemini.Failure.busy, Gemini.Failure.timedOut:
            "Gemini is busy right now (high demand), so the basic checker did this one. Try checking again in a minute."
        case Gemini.Failure.modelUnavailable:
            "Gemini's models aren't available to your key right now, so the basic checker did this one."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            "You're offline, so the basic checker did this one. It's less accurate than Gemini."
        default:
            "Gemini couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}
