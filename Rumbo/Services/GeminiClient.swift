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

    /// How hard Gemini thinks (Settings → Writing feedback). Kept on this phone, like the key.
    static var thinkingLevel: Gemini.ThinkingLevel {
        get { UserDefaults.standard.string(forKey: "gemini.thinkingLevel").flatMap(Gemini.ThinkingLevel.init(rawValue:)) ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "gemini.thinkingLevel") }
    }
}

/// Sends writing to Gemini (request and reply handling are in RumboCore's `Gemini`).
enum GeminiClient {
    static func correct(_ text: String, band: Band, prompt: String, key: String) async throws -> CorrectionService.Result {
        let input = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        let reply = try await send(input: input, instructions: CorrectionService.instructions(for: band), key: key)
        let feedback = try Gemini.feedback(from: reply)
        return CorrectionService.Result(
            corrections: Mistakes.merge(model: feedback.corrections, languageTool: []),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: Gemini.displayName
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

    /// Asks Flash-Lite. If Google is busy, waits 2 seconds and asks once more.
    private static func send(input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await answer(model: Gemini.model, input: input, instructions: instructions, key: key)
        } catch Gemini.Failure.busy {
            GeminiTrace.log("Busy: waiting 2 s, then trying once more")
            try await Task.sleep(for: .seconds(2))
            return try await answer(model: Gemini.model, input: input, instructions: instructions, key: key)
        }
    }

    /// The answer, streamed, so a model that's thinking is told apart from one that's stuck. If streaming
    /// itself goes wrong in an unexpected way, asks once more for the whole answer in one piece.
    private static func answer(model: String, input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await attempt(model: model, input: input, instructions: instructions, key: key, stream: true)
        } catch let failure as Gemini.Failure {
            guard case .other = failure else { throw failure }
            GeminiTrace.log("Streaming didn't work, so asking for the answer in one piece")
            return try await attempt(model: model, input: input, instructions: instructions, key: key, stream: false)
        }
    }

    /// One request to one model, streamed or in one piece, with every step traced.
    private static func attempt(model: String, input: String, instructions: String, key: String, stream: Bool) async throws -> String {
        let name = Gemini.displayName
        let method = stream ? "streaming" : "one piece"
        GeminiTrace.log("\(name) · \(method) · \(GeminiKey.thinkingLevel.rawValue) thinking: sent")
        let started = Date.now
        do {
            let text = stream
                ? try await streamed(request(model: model, input: input, instructions: instructions, key: key, stream: true))
                : try await onePiece(request(model: model, input: input, instructions: instructions, key: key, stream: false))
            GeminiTrace.log("\(name) · \(method): answered in \(seconds(since: started)) (\(text.count) characters)")
            return text
        } catch {
            GeminiTrace.log("\(name) · \(method): \(describe(error)) after \(seconds(since: started))")
            throw error
        }
    }

    private static func request(model: String, input: String, instructions: String, key: String, stream: Bool) -> URLRequest {
        var request = URLRequest(url: Gemini.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = stream ? 30 : 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        if stream { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.httpBody = Gemini.requestBody(model: model, instructions: instructions, input: input, stream: stream,
                                              thinking: GeminiKey.thinkingLevel)
        return request
    }

    private static func onePiece(_ request: URLRequest) async throws -> String {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            GeminiTrace.log("HTTP \(status)")
            if let failure = Gemini.failure(status: status, body: data) { throw failure }
            return try Gemini.outputText(from: data)
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
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
                    if let stall = limits.stall(started: activity.started, firstEvent: first, lastEvent: last, now: .now) {
                        switch stall {
                        case .neverStarted: GeminiTrace.log("Stopped waiting: no sign of life in \(Int(limits.firstEvent)) s")
                        case .wentQuiet: GeminiTrace.log("Stopped waiting: silent for \(Int(limits.silence)) s after starting")
                        case .tooLong: GeminiTrace.log("Stopped waiting: over \(Int(limits.total)) s in all")
                        }
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
        GeminiTrace.log("HTTP \(status) after \(seconds(since: activity.started))")
        guard (200..<300).contains(status) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw Gemini.failure(status: status, body: body) ?? .other("Gemini returned error \(status).")
        }
        var reader = Gemini.StreamReader()
        var text = ""
        var thoughts = 0
        var longestGap: TimeInterval = 0
        func finish() -> String {
            GeminiTrace.log("Stream finished: \(thoughts) thinking updates, longest silence \(String(format: "%.1f", longestGap)) s")
            return text
        }
        do {
            for try await line in bytes.lines {
                guard let event = reader.read(line: line) else { continue }
                let (first, last) = activity.times
                if first == nil { GeminiTrace.log("First event after \(seconds(since: activity.started))") }
                if let last { longestGap = max(longestGap, Date.now.timeIntervalSince(last)) }
                activity.touch()
                switch event {
                case .activity:
                    if line.contains("thought") { thoughts += 1 }
                case .text(let piece):
                    if text.isEmpty { GeminiTrace.log("Answer started after \(seconds(since: activity.started))") }
                    text += piece
                case .completed:
                    guard !text.isEmpty else { throw Gemini.Failure.other("Gemini sent an empty reply.") }
                    return finish()
                case .failed(let failure):
                    GeminiTrace.log("Error event in the stream")
                    throw failure
                }
            }
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
        // The stream ended without saying it was complete; use what arrived if there is any.
        guard !text.isEmpty else { throw Gemini.Failure.other("Gemini's stream ended early.") }
        GeminiTrace.log("Stream ended without a completion event; using what arrived")
        return finish()
    }

    // MARK: Diagnostics

    /// Asks with one method directly (no retry or fallback), for Diagnostics.
    static func probe(stream: Bool, key: String) async -> (ok: Bool, trace: [String]) {
        let trace = GeminiTrace()
        let ok: Bool = await GeminiTrace.$current.withValue(trace) {
            do {
                let text = try await attempt(model: Gemini.model, input: "Writing task: Write about yesterday.\n\nLearner's text:\nAyer yo voy a la playa con mis amigo.",
                                             instructions: CorrectionService.instructions(for: .a2_1), key: key, stream: stream)
                let feedback = try Gemini.feedback(from: text)
                GeminiTrace.log("Parsed: \(feedback.errors.count) corrections, rewrite \"\(feedback.naturalRewrite)\"")
                return true
            } catch {
                return false
            }
        }
        return (ok, trace.lines)
    }

    /// A full check exactly as a writing task runs it, with its trace.
    static func traced(_ text: String, band: Band, prompt: String) async -> (result: Result<CorrectionService.Result, Error>, trace: [String]) {
        let trace = GeminiTrace()
        let result: Result<CorrectionService.Result, Error> = await GeminiTrace.$current.withValue(trace) {
            do {
                return .success(try await CorrectionService.correct(text, band: band, prompt: prompt))
            } catch {
                return .failure(error)
            }
        }
        return (result, trace.lines)
    }

    private static func seconds(since date: Date) -> String {
        String(format: "%.1f s", Date.now.timeIntervalSince(date))
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case Gemini.Failure.rateLimited: "out of free requests (429)"
        case Gemini.Failure.busy: "busy (high demand)"
        case Gemini.Failure.timedOut: "no answer in time"
        case Gemini.Failure.invalidKey: "key not accepted"
        case Gemini.Failure.modelUnavailable: "model not available (404)"
        case Gemini.Failure.other(let message): "failed: \(message)"
        default: "failed: \(error.localizedDescription)"
        }
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
            "Gemini Flash-Lite isn't available to your key right now, so the basic checker did this one."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            "You're offline, so the basic checker did this one. It's less accurate than Gemini."
        default:
            "Gemini couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}

/// A step-by-step log of one Gemini check, for Diagnostics. Set as a task-local, so it follows the check
/// into its child tasks; when nothing set it, logging does nothing.
final class GeminiTrace: @unchecked Sendable {
    @TaskLocal static var current: GeminiTrace?

    private let started = Date.now
    private let lock = NSLock()
    private var entries: [String] = []

    var lines: [String] { lock.withLock { entries } }

    static func log(_ message: String) {
        guard let trace = current else { return }
        let offset = String(format: "%5.1f s", Date.now.timeIntervalSince(trace.started))
        trace.lock.withLock { trace.entries.append("\(offset)  \(message)") }
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
