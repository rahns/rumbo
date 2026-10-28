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
        #expect((object["generation_config"] as? [String: Any])?["thinking_level"] as? String == "low")
        let lite = try #require(try JSONSerialization.jsonObject(with: Gemini.requestBody(model: "gemini-3.5-flash-lite", instructions: "", input: "")) as? [String: Any])
        #expect((lite["generation_config"] as? [String: Any])?["thinking_level"] as? String == "low")
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
