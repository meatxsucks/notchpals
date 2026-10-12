import XCTest
@testable import NotchPals

final class LocalLLMTests: XCTestCase {
    func testNormaliseURL() {
        XCTAssertEqual(LocalLLM.normaliseURL(" http://localhost:11434/ "), "http://localhost:11434")
        XCTAssertEqual(LocalLLM.normaliseURL("http://localhost:11434/v1"), "http://localhost:11434")
        XCTAssertEqual(LocalLLM.normaliseURL("http://localhost:1234/api/"), "http://localhost:1234")
    }

    func testParseSSEDelta() {
        XCTAssertEqual(LocalLLM.parseSSEDelta(#"data: {"choices":[{"delta":{"content":"hola"}}]}"#), "hola")
        XCTAssertEqual(LocalLLM.parseSSEDelta(#"data:{"choices":[{"delta":{"content":"x"}}]}"#), "x")
        XCTAssertNil(LocalLLM.parseSSEDelta("data: [DONE]"))
        XCTAssertNil(LocalLLM.parseSSEDelta(": keep-alive"))
        XCTAssertNil(LocalLLM.parseSSEDelta(#"data: {"choices":[{"delta":{}}]}"#))
    }

    func testThinkingIsHiddenWhileStreaming() {
        XCTAssertEqual(LocalLLM.visibleText("<think>pienso"), "")
        XCTAssertEqual(LocalLLM.visibleText("<think>pienso</think>\n\nHola"), "Hola")
        XCTAssertEqual(LocalLLM.visibleText("Hola <think>pien"), "Hola")
        XCTAssertEqual(LocalLLM.removeThinking("a<think>x</think>b"), "ab")
    }

    func testParseModelsFiltersEmbeddingsAndSorts() {
        let data = Data(#"{"data":[{"id":"qwen3:8b"},{"id":"nomic-embed-text"},{"id":"llama3:8b"}]}"#.utf8)
        XCTAssertEqual(LocalLLM.parseModels(data), ["llama3:8b", "qwen3:8b"])
    }

    func testParseErrorMessage() {
        XCTAssertEqual(LocalLLM.parseErrorMessage(#"{"error":{"message":"boom"}}"#), "boom")
        XCTAssertEqual(LocalLLM.parseErrorMessage(#"{"error":"plano"}"#), "plano")
        XCTAssertNil(LocalLLM.parseErrorMessage("no json"))
    }

    func testChatRequest() throws {
        let request = try LocalLLM.makeChatRequest(
            baseURL: "http://127.0.0.1:11434", model: "qwen3", messages: [ChatMessage(role: .user, text: "hola")])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertEqual(messages.last?["content"] as? String, "hola")
    }

    func testAttachments() throws {
        let image = try Attachment.make(name: "a.png", data: Data([1, 2, 3]))
        let encoded = try LocalLLM.encode(ChatMessage(role: .user, text: "qué es", attachment: image))
        let parts = try XCTUnwrap(encoded["content"] as? [[String: Any]])
        XCTAssertEqual(parts.last?["type"] as? String, "image_url")

        let file = try Attachment.make(name: "a.txt", data: Data("contenido".utf8))
        let text = try LocalLLM.encode(ChatMessage(role: .user, text: "resume", attachment: file))
        XCTAssertTrue((text["content"] as? String ?? "").contains("contenido"))

        let pdf = try Attachment.make(name: "a.pdf", data: Data([1]))
        XCTAssertThrowsError(try LocalLLM.encode(ChatMessage(role: .user, text: "x", attachment: pdf)))
    }

    func testProviderKeysAreSeparate() {
        XCTAssertNotEqual(ChatProvider.ollama.urlKey, ChatProvider.lmstudio.urlKey)
        XCTAssertTrue(ChatProvider.ollama.isLocal)
        XCTAssertFalse(ChatProvider.claude.isLocal)
        XCTAssertEqual(LocalServer.lmstudio.defaultURL, "http://127.0.0.1:1234")
    }
}
