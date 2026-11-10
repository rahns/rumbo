import Foundation
import RumboCore

/// The learner's free Groq key, kept in the Keychain and saved in backups.
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

    /// The model picked from Groq's list, and when the list was last read (refreshed once a day).
    static var model: String {
        get { UserDefaults.standard.string(forKey: "groq.model") ?? Groq.defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: "groq.model") }
    }

    static var modelCheckedAt: Date? {
        get { UserDefaults.standard.object(forKey: "groq.modelCheckedAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "groq.modelCheckedAt") }
    }
}

/// Sends writing to Groq (request and reply handling are in RumboCore's `Groq`). One request, not streamed:
/// Groq's structured outputs don't stream, and it answers in a few seconds.
enum GroqClient {
    static func correct(_ text: String, band: Band, prompt: String, key: String) async throws -> CorrectionService.Result {
        let input = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        let reply = try await send(input: input, instructions: CorrectionService.instructions(for: band), key: key)
        let feedback = try Gemini.feedback(from: reply.text)
        return CorrectionService.Result(
            corrections: Mistakes.merge(model: feedback.corrections, languageTool: []),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: Groq.displayName(for: reply.model)
        )
    }

    /// A tiny request to check a key works. Busy or rate-limited replies still mean Groq accepted the key.
    static func test(key: String) async -> (works: Bool, message: String) {
        do {
            let reply = try await send(input: "Escribe: «Ayer fui a la playa.»", instructions: "Reply with the JSON asked for.", key: key)
            return (true, "It works (using \(reply.model)). Pico will use GroqCloud to check your writing.")
        } catch Gemini.Failure.rateLimited {
            return (true, "Your key works, but its free limit is used up for now. It resets soon.")
        } catch Gemini.Failure.busy {
            return (true, "Your key works. GroqCloud is busy right now; try a check again in a minute.")
        } catch Gemini.Failure.timedOut {
            return (false, "GroqCloud didn't answer in time, so the key isn't confirmed yet. Try again in a minute.")
        } catch Gemini.Failure.invalidKey {
            return (false, "GroqCloud didn't accept that key. Check you copied all of it.")
        } catch {
            return (false, "Couldn't reach GroqCloud: \(error.localizedDescription)")
        }
    }

    /// One request with the current model. If Groq is busy, waits 2 seconds and asks once more; if the model is
    /// gone (retired or renamed), reads the models list again, picks another and asks once more.
    private static func send(input: String, instructions: String, key: String) async throws -> (text: String, model: String) {
        var model = await currentModel(key: key)
        do {
            return (try await attempt(model: model, input: input, instructions: instructions, key: key), model)
        } catch Gemini.Failure.busy {
            GeminiTrace.log("GroqCloud busy: waiting 2 s, then trying once more")
            try await Task.sleep(for: .seconds(2))
            return (try await attempt(model: model, input: input, instructions: instructions, key: key), model)
        } catch Gemini.Failure.modelUnavailable {
            let previous = model
            model = await currentModel(key: key, forceRefresh: true)
            guard model != previous else { throw Gemini.Failure.modelUnavailable }
            GeminiTrace.log("GroqCloud: \(previous) is gone, switching to \(model)")
            return (try await attempt(model: model, input: input, instructions: instructions, key: key), model)
        }
    }

    /// The model to use: the one picked from Groq's list, which is read again once a day (or when a model has
    /// gone). If the list can't be read, the last pick (or GPT-OSS 120B) is used.
    static func currentModel(key: String, forceRefresh: Bool = false) async -> String {
        let fresh = GroqKey.modelCheckedAt.map { Date.now.timeIntervalSince($0) < 24 * 3600 } ?? false
        if fresh && !forceRefresh { return GroqKey.model }
        var request = URLRequest(url: Groq.modelsEndpoint)
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        guard case let (data, response)? = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let chosen = Groq.chooseModel(from: Groq.modelIDs(from: data)) else {
            GeminiTrace.log("GroqCloud: couldn't read the models list; using \(GroqKey.model)")
            return GroqKey.model
        }
        if chosen != GroqKey.model { GeminiTrace.log("GroqCloud: picked \(chosen) from its models list") }
        GroqKey.model = chosen
        GroqKey.modelCheckedAt = .now
        return chosen
    }

    private static func attempt(model: String, input: String, instructions: String, key: String) async throws -> String {
        var request = URLRequest(url: Groq.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = Groq.requestBody(model: model, instructions: instructions, input: input, thinking: GeminiKey.thinkingLevel)
        GeminiTrace.log("\(Groq.displayName(for: model)) · one piece · \(GeminiKey.thinkingLevel.rawValue) reasoning: sent")
        let started = Date.now
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            GeminiTrace.log("GroqCloud HTTP \(status) after \(String(format: "%.1f", Date.now.timeIntervalSince(started))) s")
            if let failure = Groq.failure(status: status, body: data) { throw failure }
            let text = try Groq.outputText(from: data)
            GeminiTrace.log("GroqCloud answered (\(text.count) characters)")
            return text
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            GeminiTrace.log("GroqCloud: no answer in time")
            throw Gemini.Failure.timedOut
        } catch {
            GeminiTrace.log("GroqCloud failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// One request directly (no fallback), with its trace, for Diagnostics.
    static func probe(key: String) async -> (ok: Bool, trace: [String]) {
        let trace = GeminiTrace()
        let ok: Bool = await GeminiTrace.$current.withValue(trace) {
            do {
                let reply = try await send(input: "Writing task: Write about yesterday.\n\nLearner's text:\nAyer yo voy a la playa con mis amigo.",
                                           instructions: CorrectionService.instructions(for: .a2_1), key: key)
                let feedback = try Gemini.feedback(from: reply.text)
                GeminiTrace.log("Parsed: \(feedback.errors.count) corrections, rewrite \"\(feedback.naturalRewrite)\"")
                return true
            } catch {
                return false
            }
        }
        return (ok, trace.lines)
    }

    /// The warning above feedback when the basic checker had to do it, after Groq (and maybe Gemini) failed.
    static func notice(for error: Error, geminiAlsoFailed: Bool) -> String {
        let who = geminiAlsoFailed ? "Gemini and GroqCloud" : "GroqCloud"
        return switch error {
        case Gemini.Failure.rateLimited:
            geminiAlsoFailed
                ? "Gemini and GroqCloud are both at their free limits for now, so the basic checker did this one. It's less accurate."
                : "You've used GroqCloud's free limit for now, so the basic checker did this one. It's less accurate."
        case Gemini.Failure.invalidKey:
            "GroqCloud didn't accept your API key, so the basic checker did this one. Check it in Settings → Writing feedback."
        case Gemini.Failure.busy, Gemini.Failure.timedOut:
            "\(who) \(geminiAlsoFailed ? "are" : "is") busy right now, so the basic checker did this one. Try checking again in a minute."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            "You're offline, so the basic checker did this one. It's less accurate."
        default:
            "\(who) couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}
