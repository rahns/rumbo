import Foundation
import Testing
@testable import RumboCore

@Suite struct GeminiTests {
    @Test func requestAsksForJSONWithoutStoring() throws {
        let body = Gemini.requestBody(model: "gemini-3.8-flash", instructions: "Be kind.", input: "Ayer yo voy.")
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == "gemini-3.8-flash")
        #expect(object["input"] as? String == "Ayer yo voy.")
        #expect(object["system_instruction"] as? String == "Be kind.")
        #expect(object["store"] as? Bool == false)
        let format = try #require(object["response_format"] as? [String: Any])
        #expect(format["mime_type"] as? String == "application/json")
        #expect((object["generation_config"] as? [String: Any])?["thinking_level"] as? String == "medium")
        let lite = try #require(try JSONSerialization.jsonObject(with: Gemini.requestBody(model: "gemini-3.5-flash-lite", instructions: "", input: "")) as? [String: Any])
        #expect((lite["generation_config"] as? [String: Any])?["thinking_level"] as? String == "medium")
        #expect(Gemini.models.first == "gemini-3.5-flash-lite", "Flash-Lite is the default")
        #expect(Gemini.displayName(for: "gemini-3.5-flash-lite") == "Gemini Flash-Lite")
        #expect(Gemini.displayName(for: "gemini-3.8-flash") == "Gemini Flash")
    }

    @Test func readsTheModelOutputStep() throws {
        let reply = """
        {"id":"v1_x","status":"completed","steps":[
          {"type":"thought","content":[{"type":"text","text":"thinking"}]},
          {"type":"model_output","content":[{"type":"text","text":"```json\\n{\\"errors\\":[{\\"original\\":\\"voy\\",\\"corrected\\":\\"fui\\",\\"explanation\\":\\"Ayer needs the preterite.\\"}],"},
                                            {"type":"text","text":"\\"naturalRewrite\\":\\"Ayer fui a la playa.\\",\\"strengths\\":[\\"Good vocabulary\\"]}\\n```"}]}
        ]}
        """
        let text = try Gemini.outputText(from: Data(reply.utf8))
        let feedback = try Gemini.feedback(from: text)
        #expect(feedback.corrections == [Correction(original: "voy", corrected: "fui", explanation: "Ayer needs the preterite.", source: "gemini")])
        #expect(feedback.naturalRewrite == "Ayer fui a la playa.")
        #expect(feedback.strengths == ["Good vocabulary"])
    }

    @Test func emptyOrMalformedRepliesThrow() {
        #expect(throws: Gemini.Failure.self) { try Gemini.outputText(from: Data(#"{"steps":[]}"#.utf8)) }
        #expect(throws: Gemini.Failure.self) { try Gemini.feedback(from: "Sorry, I can't help.") }
    }

    @Test func restingModelsAreTriedLast() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(Gemini.order(resting: [:], now: now) == Gemini.models)
        let resting = [Gemini.models[0]: now.addingTimeInterval(Gemini.restAfterFailure)]
        #expect(Gemini.order(resting: resting, now: now) == [Gemini.models[1], Gemini.models[0]])
        #expect(Gemini.order(resting: resting, now: now.addingTimeInterval(Gemini.restAfterFailure + 1)) == Gemini.models,
                "after its rest, the main model goes first again")
    }

    @Test func classifiesErrors() {
        let body = Data(#"{"error":{"code":"quota_exceeded","message":"You have exceeded your daily quota."}}"#.utf8)
        #expect(Gemini.failure(status: 200, body: Data()) == nil)
        #expect(Gemini.failure(status: 429, body: body) == .rateLimited)
        #expect(Gemini.failure(status: 401, body: Data()) == .invalidKey)
        #expect(Gemini.failure(status: 400, body: Data(#"{"error":{"code":400,"message":"API key not valid.","status":"INVALID_ARGUMENT"}}"#.utf8)) == .invalidKey)
        #expect(Gemini.failure(status: 404, body: Data()) == .modelUnavailable)
        let busy = Data(#"{"error":{"code":503,"message":"gemini-3.8-flash is currently experiencing high demand.","status":"UNAVAILABLE"}}"#.utf8)
        #expect(Gemini.failure(status: 503, body: busy) == .busy)
        #expect(Gemini.failure(status: 500, body: Data()) == .busy)
        #expect(Gemini.failure(status: 418, body: Data(#"{"error":{"code":"teapot","message":"Boom"}}"#.utf8)) == .other("Boom"))
    }
}

@Suite struct GeminiStreamTests {
    @Test func streamedRequestsAskForThoughtSummaries() throws {
        let body = try #require(try JSONSerialization.jsonObject(with: Gemini.requestBody(model: "m", instructions: "", input: "", stream: true)) as? [String: Any])
        #expect(body["stream"] as? Bool == true)
        #expect((body["generation_config"] as? [String: Any])?["thinking_summaries"] as? String == "auto")
        let plain = try #require(try JSONSerialization.jsonObject(with: Gemini.requestBody(model: "m", instructions: "", input: "")) as? [String: Any])
        #expect(plain["stream"] == nil)
    }

    @Test func readsTextOnlyFromTheOutputStep() {
        var reader = Gemini.StreamReader()
        let lines = [
            "event: interaction.created",
            #"data: {"interaction":{"id":"v1_x","status":"in_progress"},"event_type":"interaction.created"}"#,
            #"data: {"index":0,"step":{"type":"thought"},"event_type":"step.start"}"#,
            #"data: {"index":0,"delta":{"type":"thought_summary","content":{"type":"text","text":"Checking tenses"}},"event_type":"step.delta"}"#,
            #"data: {"index":0,"delta":{"type":"text","text":"not the answer"},"event_type":"step.delta"}"#,
            #"data: {"index":1,"step":{"type":"model_output"},"event_type":"step.start"}"#,
            #"data: {"index":1,"delta":{"text":"{\"errors\":[],","type":"text"},"event_type":"step.delta"}"#,
            #"data: {"index":1,"delta":{"text":"\"naturalRewrite\":\"Hola\",\"strengths\":[]}","type":"text"},"event_type":"step.delta"}"#,
            #"data: {"interaction":{"id":"v1_x","status":"completed"},"event_type":"interaction.completed"}"#,
            "data: [DONE]",
        ]
        let events = lines.compactMap { reader.read(line: $0) }
        let text = events.compactMap { if case .text(let t) = $0 { t } else { nil } }.joined()
        #expect(text == #"{"errors":[],"naturalRewrite":"Hola","strengths":[]}"#)
        #expect(events.first == .activity)
        #expect(events.filter { $0 == .completed }.count == 2)
        #expect((try? Gemini.feedback(from: text))?.naturalRewrite == "Hola")
    }

    @Test func errorEventsAreClassified() {
        var reader = Gemini.StreamReader()
        #expect(reader.read(line: #"data: {"error":{"message":"Deadline expired before operation could complete.","code":"gateway_timeout"},"event_type":"error"}"#) == .failed(.busy))
        #expect(reader.read(line: #"data: {"error":{"code":"quota_exceeded","message":"daily"},"event_type":"error"}"#) == .failed(.rateLimited))
        #expect(reader.read(line: #"data: {"error":{"code":"weird","message":"Boom"},"event_type":"error"}"#) == .failed(.other("Boom")))
    }

    @Test func stallRules() {
        let limits = Gemini.StreamLimits()
        let start = Date(timeIntervalSince1970: 0)
        func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }
        #expect(!limits.hasStalled(started: start, firstEvent: nil, lastEvent: nil, now: at(9)))
        #expect(limits.hasStalled(started: start, firstEvent: nil, lastEvent: nil, now: at(11)), "never started")
        #expect(!limits.hasStalled(started: start, firstEvent: at(1), lastEvent: at(40), now: at(60)), "still thinking")
        #expect(limits.hasStalled(started: start, firstEvent: at(1), lastEvent: at(5), now: at(31)), "went quiet")
        #expect(limits.hasStalled(started: start, firstEvent: at(1), lastEvent: at(90), now: at(91)), "total cap")
    }
}
