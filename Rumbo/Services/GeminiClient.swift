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
            engine: Gemini.displayName(for: reply.model)
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

    /// Tries each model in turn: each has its own free quota and load, so the other covers when the first is
    /// used up, busy or stuck. A model that failed rests for 30 minutes (tried last), so checks don't keep waiting on it.
    /// If they're all just busy and there's time left, waits 2 seconds and goes round once more.
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
                guard lastError == .busy, Date.now.timeIntervalSince(started) < 30 else { break }
                try await Task.sleep(for: .seconds(2))
            }
            for model in Gemini.order(resting: resting) {
                do {
                    return (try await answer(model: model, input: input, instructions: instructions, key: key), model)
                } catch let failure as Gemini.Failure where [.rateLimited, .busy, .timedOut, .modelUnavailable].contains(failure) {
                    note(failure)
                    rest(model)
                }
            }
        }
        throw lastError
    }

    /// One model's answer: streamed, so a model that's thinking is told apart from one that's stuck. If streaming
    /// itself goes wrong in an unexpected way, asks once more for the whole answer in one piece.
    private static func answer(model: String, input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await streamed(request(model: model, input: input, instructions: instructions, key: key, stream: true))
        } catch Gemini.Failure.other {
            var plain = request(model: model, input: input, instructions: instructions, key: key, stream: false)
            plain.timeoutInterval = 50
            do {
                let (data, response) = try await URLSession.shared.data(for: plain)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let failure = Gemini.failure(status: status, body: data) { throw failure }
                return try Gemini.outputText(from: data)
            } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                throw Gemini.Failure.timedOut
            }
        }
    }

    private static func request(model: String, input: String, instructions: String, key: String, stream: Bool) -> URLRequest {
        var request = URLRequest(url: Gemini.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        if stream { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.httpBody = Gemini.requestBody(model: model, instructions: instructions, input: input, stream: stream)
        return request
    }

    /// Reads a streamed answer while a watchdog checks the stall rules in `Gemini.StreamLimits`:
    /// a first event within 10 s, no more than 25 s of silence after it, 90 s in all.
    private static func streamed(_ request: URLRequest) async throws -> String {
        let activity = StreamActivity()
        let limits = Gemini.StreamLimits()
        return try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                try await read(request, activity: activity)
            }
            group.addTask {
                repeat {
                    try await Task.sleep(for: .seconds(1))
                    let (first, last) = activity.times
                    if limits.hasStalled(started: activity.started, firstEvent: first, lastEvent: last, now: .now) {
                        throw Gemini.Failure.timedOut
                    }
                } while !Task.isCancelled
                return nil
            }
            defer { group.cancelAll() }
            while let result = try await group.next() {
                if let text = result { return text }
            }
            throw Gemini.Failure.timedOut
        }
    }

    private static func read(_ request: URLRequest, activity: StreamActivity) async throws -> String? {
        let bytes: URLSession.AsyncBytes, response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw Gemini.failure(status: status, body: body) ?? .other("Gemini returned error \(status).")
        }
        var reader = Gemini.StreamReader()
        var text = ""
        do {
            for try await line in bytes.lines {
                guard let event = reader.read(line: line) else { continue }
                activity.touch()
                switch event {
                case .activity: continue
                case .text(let piece): text += piece
                case .completed:
                    guard !text.isEmpty else { throw Gemini.Failure.other("Gemini sent an empty reply.") }
                    return text
                case .failed(let failure): throw failure
                }
            }
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
        // The stream ended without saying it was complete; use what arrived if there is any.
        guard !text.isEmpty else { throw Gemini.Failure.other("Gemini's stream ended early.") }
        return text
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

/// When a streamed answer started and last showed signs of life, shared with its watchdog.
private final class StreamActivity: @unchecked Sendable {
    let started = Date.now
    private let lock = NSLock()
    private var first: Date?
    private var last: Date?

    var times: (first: Date?, last: Date?) {
        lock.withLock { (first, last) }
    }

    func touch() {
        lock.withLock {
            let now = Date.now
            if first == nil { first = now }
            last = now
        }
    }
}
