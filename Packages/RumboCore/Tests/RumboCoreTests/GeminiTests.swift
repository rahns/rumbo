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
        #expect(Gemini.model == "gemini-3.5-flash-lite", "Flash-Lite only")
        let high = try #require(try JSONSerialization.jsonObject(with: Gemini.requestBody(model: "m", instructions: "", input: "", thinking: .high)) as? [String: Any])
        #expect((high["generation_config"] as? [String: Any])?["thinking_level"] as? String == "high")
        #expect(Gemini.ThinkingLevel.standard == .medium)
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
        #expect(limits.stall(started: start, firstEvent: nil, lastEvent: nil, now: at(9)) == nil)
        #expect(limits.stall(started: start, firstEvent: nil, lastEvent: nil, now: at(11)) == .neverStarted)
        #expect(limits.stall(started: start, firstEvent: at(1), lastEvent: at(40), now: at(60)) == nil, "still thinking")
        #expect(limits.stall(started: start, firstEvent: at(1), lastEvent: at(5), now: at(31)) == .wentQuiet)
        #expect(limits.stall(started: start, firstEvent: at(1), lastEvent: at(90), now: at(91)) == .tooLong)
    }
}

@Suite struct GroqTests {
    @Test func requestUsesStrictSchemaAndReasoningEffort() throws {
        let body = try #require(try JSONSerialization.jsonObject(with: Groq.requestBody(model: "openai/gpt-oss-120b", instructions: "Be kind.", input: "Ayer yo voy.", thinking: .high)) as? [String: Any])
        #expect(body["model"] as? String == "openai/gpt-oss-120b")
        #expect(body["stream"] == nil, "structured outputs don't stream on Groq")
        #expect(body["reasoning_effort"] as? String == "high")
        #expect(body["include_reasoning"] as? Bool == false)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user"])
        let format = try #require(body["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["strict"] as? Bool == true)
        let root = try #require(schema["schema"] as? [String: Any])
        #expect(root["additionalProperties"] as? Bool == false)
        let items = ((root["properties"] as? [String: Any])?["errors"] as? [String: Any])?["items"] as? [String: Any]
        #expect(items?["additionalProperties"] as? Bool == false)
    }

    @Test func readsTheAnswerAndClassifiesErrors() throws {
        let reply = #"{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"{\"errors\":[],\"naturalRewrite\":\"Hola\",\"strengths\":[]}"}}]}"#
        #expect(try Gemini.feedback(from: Groq.outputText(from: Data(reply.utf8))).naturalRewrite == "Hola")
        #expect(throws: Gemini.Failure.self) { try Groq.outputText(from: Data(#"{"choices":[{"finish_reason":"length","message":{"content":"{"}}]}"#.utf8)) }
        #expect(Groq.failure(status: 200, body: Data()) == nil)
        #expect(Groq.failure(status: 401, body: Data()) == .invalidKey)
        #expect(Groq.failure(status: 429, body: Data()) == .rateLimited)
        #expect(Groq.failure(status: 498, body: Data()) == .busy)
        #expect(Groq.failure(status: 400, body: Data(#"{"error":{"message":"Bad schema","type":"invalid_request_error"}}"#.utf8)) == .other("Bad schema"))
        // Gemini's schema stays open (it doesn't need additionalProperties).
        #expect(Gemini.feedbackSchema(closed: false)["additionalProperties"] == nil)
    }
}

@Suite struct GroqModelChoiceTests {
    @Test func picksTheBestChatModelOnTheList() {
        let list = Data(#"{"object":"list","data":[{"id":"whisper-large-v3","active":true},{"id":"llama-3.1-8b-instant","active":true},{"id":"openai/gpt-oss-20b","active":true},{"id":"openai/gpt-oss-120b","active":true},{"id":"openai/gpt-oss-safeguard-20b","active":true},{"id":"old-model","active":false}]}"#.utf8)
        let ids = Groq.modelIDs(from: list)
        #expect(!ids.contains("old-model"), "inactive models are left out")
        #expect(Groq.chooseModel(from: ids) == "openai/gpt-oss-120b")
        #expect(Groq.chooseModel(from: ["openai/gpt-oss-120b-2", "llama-3.3-70b-versatile"]) == "openai/gpt-oss-120b-2", "a renamed GPT-OSS 120B")
        #expect(Groq.chooseModel(from: ["openai/gpt-oss-20b", "llama-3.3-70b-versatile"]) == "openai/gpt-oss-20b")
        #expect(Groq.chooseModel(from: ["whisper-large-v3", "llama-3.3-70b-versatile", "llama-3.1-8b-instant"]) == "llama-3.3-70b-versatile")
        #expect(Groq.chooseModel(from: ["openai/gpt-oss-safeguard-20b", "canopylabs/orpheus-v1"]) == nil, "only special models: nothing usable")
        #expect(Groq.displayName(for: "openai/gpt-oss-120b") == "GroqCloud (gpt-oss-120b)")
    }

    @Test func otherModelsGetJSONModeWithoutReasoning() throws {
        let body = try #require(try JSONSerialization.jsonObject(with: Groq.requestBody(model: "llama-3.3-70b-versatile", instructions: "Be kind.", input: "Hola")) as? [String: Any])
        #expect((body["response_format"] as? [String: Any])?["type"] as? String == "json_object")
        #expect(body["reasoning_effort"] == nil)
        let system = (body["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(system.contains("JSON"), "JSON mode needs the word JSON in the prompt")
        let qwen = try #require(try JSONSerialization.jsonObject(with: Groq.requestBody(model: "qwen/qwen3.8-27b", instructions: "", input: "")) as? [String: Any])
        #expect(qwen["reasoning_format"] as? String == "hidden" && qwen["include_reasoning"] == nil)
        #expect(Groq.failure(status: 400, body: Data(#"{"error":{"message":"The model `x` has been decommissioned","type":"invalid_request_error"}}"#.utf8)) == .modelUnavailable)
    }
}

@Suite struct WritingCheckerTests {
    @Test func theDefaultGoesFirstThenTheOthersWithKeys() {
        #expect(WritingChecker.order(default: .gemini, available: [.gemini, .groq]) == [.gemini, .groq])
        #expect(WritingChecker.order(default: .groq, available: [.gemini, .groq]) == [.groq, .gemini])
        #expect(WritingChecker.order(default: .groq, available: [.gemini]) == [.gemini], "a default without a key is skipped")
        #expect(WritingChecker.order(default: .gemini, available: []).isEmpty)
        #expect(WritingChecker.summary(default: .groq, available: [.gemini, .groq]) == "GroqCloud, then Gemini")
        #expect(WritingChecker.summary(default: .gemini, available: []) == "Not set up")
        #expect(WritingChecker.standardDefault == .gemini)
    }
}
