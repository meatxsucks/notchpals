import XCTest
@testable import NotchPals

final class ClaudeTests: XCTestCase {
    func testParseBashRequest() {
        let json = #"{"tool_name":"Bash","tool_input":{"command":"ls -la"},"cwd":"/tmp"}"#
        let request = ApprovalProtocol.parse(Data(json.utf8))
        XCTAssertEqual(request?.tool, "Bash")
        XCTAssertEqual(request?.summary, "ls -la")
        XCTAssertEqual(request?.cwd, "/tmp")
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(ApprovalProtocol.parse(Data("no es json".utf8)))
    }

    func testPermissionRequestResponses() throws {
        let json = #"{"tool_name":"Bash","tool_input":{"command":"ls"},"permission_suggestions":[{"type":"addRules"}]}"#
        let request = try XCTUnwrap(ApprovalProtocol.parse(Data(json.utf8)))
        XCTAssertNotNil(request.suggestions)

        func decision(_ d: ApprovalDecision) throws -> [String: Any]? {
            guard let data = ApprovalProtocol.responseJSON(d, request: request) else { return nil }
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let output = root?["hookSpecificOutput"] as? [String: Any]
            XCTAssertEqual(output?["hookEventName"] as? String, "PermissionRequest")
            return output?["decision"] as? [String: Any]
        }
        XCTAssertEqual(try decision(.allow)?["behavior"] as? String, "allow")
        XCTAssertNil(try decision(.allow)?["updatedPermissions"])
        XCTAssertNotNil(try decision(.always)?["updatedPermissions"])
        XCTAssertEqual(try decision(.deny)?["behavior"] as? String, "deny")
        XCTAssertNil(ApprovalProtocol.responseJSON(.ask, request: request))
    }

    func testHTTPParserWaitsForBody() {
        let partial = "POST /approve HTTP/1.1\r\nContent-Length: 5\r\nX-NotchPals-Token: abc\r\n\r\nhel"
        XCTAssertNil(HTTPRequestParser.parse(Data(partial.utf8)))
        let full = partial + "lo"
        let parsed = HTTPRequestParser.parse(Data(full.utf8))
        XCTAssertEqual(parsed?.path, "/approve")
        XCTAssertEqual(parsed?.headers["x-notchpals-token"], "abc")
        XCTAssertEqual(parsed.flatMap { String(data: $0.body, encoding: .utf8) }, "hello")
    }

    func testRequestBuilder() throws {
        let request = try ClaudeClient.makeRequest(apiKey: "k", messages: [ChatMessage(role: .user, text: "hola")])
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "k")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "claude-opus-5-5")
    }

    func testParseReply() throws {
        let ok = #"{"content":[{"type":"text","text":"hola"}],"stop_reason":"end_turn"}"#
        XCTAssertEqual(try ClaudeClient.parseReply(Data(ok.utf8)), "hola")
        let refusal = #"{"content":[],"stop_reason":"refusal"}"#
        XCTAssertThrowsError(try ClaudeClient.parseReply(Data(refusal.utf8)))
    }
}
