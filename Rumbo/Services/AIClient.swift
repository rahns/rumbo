import Foundation
import RumboCore

/// Writing-feedback settings (Settings → Writing feedback): the model, how hard it thinks, and the learner's
/// API key for each provider. Keys are kept in the Keychain; all of it is saved in backups.
enum AISettings {
    private static func account(_ provider: WritingModel.Provider) -> String { "\(provider.rawValue).apiKey" }

    static func key(for provider: WritingModel.Provider) -> String? {
        guard let data = KeychainShare.read(forKey: account(provider)).data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        return key
    }

    /// Saves a key; an empty one removes it.
    static func save(_ key: String, for provider: WritingModel.Provider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainShare.delete(forKey: account(provider))
        } else {
            KeychainShare.write(Data(trimmed.utf8), forKey: account(provider))
        }
    }

    static var model: WritingModel {
        get { UserDefaults.standard.string(forKey: "ai.model").flatMap(WritingModel.init(rawValue:)) ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "ai.model") }
    }

    /// Gemini's thinking level; for Claude, the effort. Same three steps either way.
    static var thinkingLevel: Gemini.ThinkingLevel {
        get { UserDefaults.standard.string(forKey: "gemini.thinkingLevel").flatMap(Gemini.ThinkingLevel.init(rawValue:)) ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "gemini.thinkingLevel") }
    }

    /// The key for the chosen model's provider, if there is one.
    static var currentKey: String? { key(for: model.provider) }
}

/// Sends writing to the chosen model (request and reply handling are in RumboCore's `Gemini` and `Claude`).
enum AIClient {
    static func correct(_ text: String, band: Band, prompt: String, model: WritingModel, key: String) async throws -> CorrectionService.Result {
        let input = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        let reply = try await send(model: model, input: input, instructions: CorrectionService.instructions(for: band), key: key)
        let feedback = try Gemini.feedback(from: reply)
        return CorrectionService.Result(
            corrections: Mistakes.merge(model: feedback.corrections, languageTool: []),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: model.displayName
        )
    }

    /// A tiny request to check a key works. Busy or rate-limited replies still mean the key was accepted.
    static func test(model: WritingModel, key: String) async -> (works: Bool, message: String) {
        let name = model.provider.name
        let company = model.provider == .gemini ? "Google" : "Anthropic"
        do {
            _ = try await send(model: model, input: "Escribe: «Ayer fui a la playa.»", instructions: "Reply with the JSON asked for.", key: key)
            return (true, "It works. Pico will use \(model.displayName) to check your writing.")
        } catch Gemini.Failure.rateLimited {
            return (true, model.provider == .gemini
                    ? "Your key works, but its free limit is used up for now. Pico uses the basic checker until it resets."
                    : "Your key works, but it's hitting Anthropic's rate limit right now. Try again in a minute.")
        } catch Gemini.Failure.busy {
            return (true, "Your key works. \(name) is busy right now, so a check may use the basic checker until it calms down.")
        } catch Gemini.Failure.timedOut {
            return (false, "\(name) didn't answer in time, so the key isn't confirmed yet. Try again in a minute.")
        } catch Gemini.Failure.invalidKey {
            return (false, "\(company) didn't accept that key. Check you copied all of it.")
        } catch {
            return (false, "Couldn't reach \(name): \(error.localizedDescription)")
        }
    }

    /// Asks the model. If it's busy, waits 2 seconds and asks once more.
    private static func send(model: WritingModel, input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await answer(model: model, input: input, instructions: instructions, key: key)
        } catch Gemini.Failure.busy {
            AITrace.log("Busy: waiting 2 s, then trying once more")
            try await Task.sleep(for: .seconds(2))
            return try await answer(model: model, input: input, instructions: instructions, key: key)
        }
    }

    /// The answer, streamed, so a model that's thinking is told apart from one that's stuck. If streaming
    /// itself goes wrong in an unexpected way, asks once more for the whole answer in one piece.
    private static func answer(model: WritingModel, input: String, instructions: String, key: String) async throws -> String {
        do {
            return try await attempt(model: model, input: input, instructions: instructions, key: key, stream: true)
        } catch let failure as Gemini.Failure {
            guard case .other = failure else { throw failure }
            AITrace.log("Streaming didn't work, so asking for the answer in one piece")
            return try await attempt(model: model, input: input, instructions: instructions, key: key, stream: false)
        }
    }

    /// One request to one model, streamed or in one piece, with every step traced.
    private static func attempt(model: WritingModel, input: String, instructions: String, key: String, stream: Bool) async throws -> String {
        let name = model.displayName
        let method = stream ? "streaming" : "one piece"
        AITrace.log("\(name) · \(method) · \(AISettings.thinkingLevel.rawValue) thinking: sent")
        let started = Date.now
        do {
            let text = stream
                ? try await streamed(request(model: model, input: input, instructions: instructions, key: key, stream: true), provider: model.provider)
                : try await onePiece(request(model: model, input: input, instructions: instructions, key: key, stream: false), provider: model.provider)
            AITrace.log("\(name) · \(method): answered in \(seconds(since: started)) (\(text.count) characters)")
            return text
        } catch {
            AITrace.log("\(name) · \(method): \(describe(error)) after \(seconds(since: started))")
            throw error
        }
    }

    private static func request(model: WritingModel, input: String, instructions: String, key: String, stream: Bool) -> URLRequest {
        let thinking = AISettings.thinkingLevel
        var request: URLRequest
        switch model.provider {
        case .gemini:
            request = URLRequest(url: Gemini.endpoint)
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = Gemini.requestBody(model: model.rawValue, instructions: instructions, input: input, stream: stream, thinking: thinking)
        case .claude:
            request = URLRequest(url: Claude.endpoint)
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue(Claude.apiVersion, forHTTPHeaderField: "anthropic-version")
            if Claude.usesFallbacks(model.rawValue) { request.setValue(Claude.fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
            request.httpBody = Claude.requestBody(model: model.rawValue, instructions: instructions, input: input, stream: stream, thinking: thinking)
        }
        request.httpMethod = "POST"
        request.timeoutInterval = stream ? 30 : 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if stream { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        return request
    }

    private static func httpFailure(_ provider: WritingModel.Provider, status: Int, body: Data) -> Gemini.Failure? {
        provider == .gemini ? Gemini.failure(status: status, body: body) : Claude.failure(status: status, body: body)
    }

    private static func onePiece(_ request: URLRequest, provider: WritingModel.Provider) async throws -> String {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            AITrace.log("HTTP \(status)")
            if let failure = httpFailure(provider, status: status, body: data) { throw failure }
            return try provider == .gemini ? Gemini.outputText(from: data) : Claude.outputText(from: data)
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
    }

    /// Reads a streamed answer while a watchdog checks the stall rules in `Gemini.StreamLimits`:
    /// a first event within 10 s, no more than 25 s of silence after it, 90 s in all.
    private static func streamed(_ request: URLRequest, provider: WritingModel.Provider) async throws -> String {
        let activity = StreamActivity()
        let limits = Gemini.StreamLimits()
        return try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                try await read(request, provider: provider, activity: activity)
            }
            group.addTask {
                repeat {
                    try await Task.sleep(for: .seconds(1))
                    let (first, last) = activity.times
                    if let stall = limits.stall(started: activity.started, firstEvent: first, lastEvent: last, now: .now) {
                        switch stall {
                        case .neverStarted: AITrace.log("Stopped waiting: no sign of life in \(Int(limits.firstEvent)) s")
                        case .wentQuiet: AITrace.log("Stopped waiting: silent for \(Int(limits.silence)) s after starting")
                        case .tooLong: AITrace.log("Stopped waiting: over \(Int(limits.total)) s in all")
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

    private static func read(_ request: URLRequest, provider: WritingModel.Provider, activity: StreamActivity) async throws -> String? {
        let bytes: URLSession.AsyncBytes, response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        AITrace.log("HTTP \(status) after \(seconds(since: activity.started))")
        guard (200..<300).contains(status) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw httpFailure(provider, status: status, body: body) ?? .other("\(provider.name) returned error \(status).")
        }
        var geminiReader = Gemini.StreamReader()
        var claudeReader = Claude.StreamReader()
        var text = ""
        var thoughts = 0
        var longestGap: TimeInterval = 0
        func finish() -> String {
            AITrace.log("Stream finished: \(thoughts) thinking updates, longest silence \(String(format: "%.1f", longestGap)) s")
            return text
        }
        do {
            for try await line in bytes.lines {
                guard let event = provider == .gemini ? geminiReader.read(line: line) : claudeReader.read(line: line) else { continue }
                let (first, last) = activity.times
                if first == nil { AITrace.log("First event after \(seconds(since: activity.started))") }
                if let last { longestGap = max(longestGap, Date.now.timeIntervalSince(last)) }
                activity.touch()
                switch event {
                case .activity:
                    if line.contains("thought") || line.contains("thinking_delta") { thoughts += 1 }
                case .text(let piece):
                    if text.isEmpty { AITrace.log("Answer started after \(seconds(since: activity.started))") }
                    text += piece
                case .completed:
                    guard !text.isEmpty else { throw Gemini.Failure.other("\(provider.name) sent an empty reply.") }
                    return finish()
                case .failed(let failure):
                    AITrace.log("Error event in the stream")
                    throw failure
                }
            }
        } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
            throw Gemini.Failure.timedOut
        }
        // The stream ended without saying it was complete; use what arrived if there is any.
        guard !text.isEmpty else { throw Gemini.Failure.other("\(provider.name)'s stream ended early.") }
        AITrace.log("Stream ended without a completion event; using what arrived")
        return finish()
    }

    // MARK: Diagnostics

    /// Asks with one method directly (no retry or fallback), for Diagnostics.
    static func probe(model: WritingModel, stream: Bool, key: String) async -> (ok: Bool, trace: [String]) {
        let trace = AITrace()
        let ok: Bool = await AITrace.$current.withValue(trace) {
            do {
                let text = try await attempt(model: model, input: "Writing task: Write about yesterday.\n\nLearner's text:\nAyer yo voy a la playa con mis amigo.",
                                             instructions: CorrectionService.instructions(for: .a2_1), key: key, stream: stream)
                let feedback = try Gemini.feedback(from: text)
                AITrace.log("Parsed: \(feedback.errors.count) corrections, rewrite \"\(feedback.naturalRewrite)\"")
                return true
            } catch {
                return false
            }
        }
        return (ok, trace.lines)
    }

    /// A full check exactly as a writing task runs it, with its trace.
    static func traced(_ text: String, band: Band, prompt: String) async -> (result: Result<CorrectionService.Result, Error>, trace: [String]) {
        let trace = AITrace()
        let result: Result<CorrectionService.Result, Error> = await AITrace.$current.withValue(trace) {
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
        case Gemini.Failure.rateLimited: "rate-limited or out of free requests (429)"
        case Gemini.Failure.busy: "busy (high demand)"
        case Gemini.Failure.timedOut: "no answer in time"
        case Gemini.Failure.invalidKey: "key not accepted"
        case Gemini.Failure.modelUnavailable: "model not available (404)"
        case Gemini.Failure.other(let message): "failed: \(message)"
        default: "failed: \(error.localizedDescription)"
        }
    }

    /// The small warning shown above feedback from the basic checker.
    static func notice(for error: Error, model: WritingModel) -> String {
        let name = model.provider.name
        return switch error {
        case Gemini.Failure.rateLimited:
            model.provider == .gemini
                ? "You've used Gemini's free limit for now, so the basic checker did this one. It's less accurate. The limit resets daily."
                : "Claude's rate limit was reached, so the basic checker did this one. Try checking again in a minute."
        case Gemini.Failure.invalidKey:
            "\(name) didn't accept your API key, so the basic checker did this one. Check the key in Settings → Writing feedback."
        case Gemini.Failure.busy, Gemini.Failure.timedOut:
            "\(name) is busy right now (high demand), so the basic checker did this one. Try checking again in a minute."
        case Gemini.Failure.modelUnavailable:
            "\(model.displayName) isn't available to your key right now, so the basic checker did this one."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            "You're offline, so the basic checker did this one. It's less accurate than \(name)."
        default:
            "\(name) couldn't check this (\(error.localizedDescription)), so the basic checker did. It's less accurate."
        }
    }
}

/// A step-by-step log of one AI check, for Diagnostics. Set as a task-local, so it follows the check
/// into its child tasks; when nothing set it, logging does nothing.
final class AITrace: @unchecked Sendable {
    @TaskLocal static var current: AITrace?

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
