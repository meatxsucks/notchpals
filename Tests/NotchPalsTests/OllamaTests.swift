import XCTest
@testable import NotchPals

final class OllamaTests: XCTestCase {
    let base = URL(string: "http://127.0.0.1:11434")!

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func testChatRequestHasSystemFirstAndStreams() throws {
        let request = try OllamaClient.makeChatRequest(
            baseURL: base, model: "qwen3", messages: [ChatMessage(role: .user, text: "hola")])
        XCTAssertEqual(request.url?.path, "/api/chat")
        let json = try body(request)
        XCTAssertEqual(json["model"] as? String, "qwen3")
        XCTAssertEqual(json["stream"] as? Bool, true)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertEqual(messages.last?["content"] as? String, "hola")
    }

    func testImageAndTextAttachments() throws {
        let image = try Attachment.make(name: "a.png", data: Data([1, 2, 3]))
        let withImage = try OllamaClient.encode(ChatMessage(role: .user, text: "qué es", attachment: image))
        XCTAssertEqual((withImage["images"] as? [String])?.count, 1)

        let file = try Attachment.make(name: "a.txt", data: Data("contenido".utf8))
        let withText = try OllamaClient.encode(ChatMessage(role: .user, text: "resume", attachment: file))
        XCTAssertTrue((withText["content"] as? String ?? "").contains("contenido"))
    }

    func testPDFIsRejected() throws {
        let pdf = try Attachment.make(name: "a.pdf", data: Data([1, 2, 3]))
        XCTAssertThrowsError(try OllamaClient.encode(ChatMessage(role: .user, text: "x", attachment: pdf)))
    }

    func testParseStreamLines() throws {
        let chunk = try OllamaClient.parseStreamLine(#"{"message":{"role":"assistant","content":"ho"},"done":false}"#)
        XCTAssertEqual(chunk?.text, "ho")
        XCTAssertEqual(chunk?.done, false)
        XCTAssertEqual(try OllamaClient.parseStreamLine(#"{"message":{"content":""},"done":true}"#)?.done, true)
        XCTAssertNil(try OllamaClient.parseStreamLine("  "))
        XCTAssertThrowsError(try OllamaClient.parseStreamLine(#"{"error":"model not found"}"#))
    }

    func testParseModelsSorted() {
        let data = Data(#"{"models":[{"name":"b:7b"},{"name":"a:3b"}]}"#.utf8)
        XCTAssertEqual(OllamaClient.parseModels(data), ["a:3b", "b:7b"])
    }
}
