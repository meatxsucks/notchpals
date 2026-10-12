import XCTest
@testable import NotchPals

final class ChatPromptTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ChatPrompt.overrideKey)
        super.tearDown()
    }

    func testDefaultAsksForShortPlainText() {
        UserDefaults.standard.removeObject(forKey: ChatPrompt.overrideKey)
        let prompt = ChatPrompt.system
        XCTAssertEqual(prompt, ChatPrompt.defaultText)
        XCTAssertTrue(prompt.contains("1 a 3 frases"))
        XCTAssertTrue(prompt.contains("Markdown"))
    }

    func testOverrideAndBlankFallback() {
        UserDefaults.standard.set("Responde como un pirata.", forKey: ChatPrompt.overrideKey)
        XCTAssertEqual(ChatPrompt.system, "Responde como un pirata.")
        UserDefaults.standard.set("   ", forKey: ChatPrompt.overrideKey)
        XCTAssertEqual(ChatPrompt.system, ChatPrompt.defaultText)
    }

    func testBothClientsUseTheSharedPrompt() throws {
        UserDefaults.standard.removeObject(forKey: ChatPrompt.overrideKey)
        let messages = [ChatMessage(role: .user, text: "hola")]

        let claude = try ClaudeClient.makeRequest(apiKey: "k", messages: messages)
        let claudeBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(claude.httpBody)) as? [String: Any])
        XCTAssertEqual(claudeBody["system"] as? String, ChatPrompt.defaultText)

        let local = try LocalLLM.makeChatRequest(baseURL: "http://127.0.0.1:11434", model: "m", messages: messages)
        let localBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(local.httpBody)) as? [String: Any])
        let first = (localBody["messages"] as? [[String: Any]])?.first
        XCTAssertEqual(first?["content"] as? String, ChatPrompt.defaultText)
    }
}
