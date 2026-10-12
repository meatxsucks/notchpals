import XCTest
@testable import NotchPals

final class AttachmentTests: XCTestCase {
    func testClassification() {
        XCTAssertEqual(Attachment.category(forFileName: "a.SWIFT"), .text)
        XCTAssertEqual(Attachment.category(forFileName: "Makefile"), .text)
        XCTAssertEqual(Attachment.category(forFileName: "x.jpg"), .image(mediaType: "image/jpeg"))
        XCTAssertEqual(Attachment.category(forFileName: "x.webp"), .image(mediaType: "image/webp"))
        XCTAssertEqual(Attachment.category(forFileName: "x.pdf"), .pdf)
        XCTAssertNil(Attachment.category(forFileName: "x.zip"))
    }

    func testLimits() throws {
        XCTAssertThrowsError(try Attachment.validate(name: "x.zip", size: 10)) {
            XCTAssertEqual($0 as? AttachmentError, .unsupported("x.zip"))
        }
        XCTAssertThrowsError(try Attachment.validate(name: "a.txt", size: Attachment.maxTextBytes + 1))
        XCTAssertNoThrow(try Attachment.validate(name: "a.txt", size: Attachment.maxTextBytes))
        XCTAssertThrowsError(try Attachment.validate(name: "a.pdf", size: Attachment.maxPDFBytes + 1))
        XCTAssertNotNil(AttachmentError.tooLarge(name: "a", limit: 1024).errorDescription)
    }

    func testMakeTextAndInvalidUTF8() throws {
        let ok = try Attachment.make(name: "n.md", data: Data("hola".utf8))
        XCTAssertEqual(ok.payload, .text("hola"))
        XCTAssertThrowsError(try Attachment.make(name: "n.md", data: Data([0xFF, 0xFE, 0xFD])))
    }

    func testContentBlocks() throws {
        let image = try Attachment.make(name: "p.png", data: Data([1, 2, 3]))
        let blocks = image.contentBlocks(prompt: "¿qué es?")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0]["type"] as? String, "image")
        let source = try XCTUnwrap(blocks[0]["source"] as? [String: Any])
        XCTAssertEqual(source["media_type"] as? String, "image/png")
        XCTAssertEqual(source["data"] as? String, Data([1, 2, 3]).base64EncodedString())
        XCTAssertEqual(blocks[1]["text"] as? String, "¿qué es?")

        let pdf = try Attachment.make(name: "d.pdf", data: Data([4]))
        XCTAssertEqual(pdf.contentBlocks(prompt: "x")[0]["type"] as? String, "document")
    }

    func testRequestContentShape() throws {
        let plain = try ClaudeClient.makeRequest(apiKey: "k", messages: [ChatMessage(role: .user, text: "hi")])
        let plainBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(plain.httpBody)) as? [String: Any])
        let plainMessages = try XCTUnwrap(plainBody["messages"] as? [[String: Any]])
        XCTAssertEqual(plainMessages[0]["content"] as? String, "hi")

        let file = try Attachment.make(name: "a.txt", data: Data("abc".utf8))
        let withFile = try ClaudeClient.makeRequest(
            apiKey: "k", messages: [ChatMessage(role: .user, text: "resume", attachment: file)])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(withFile.httpBody)) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let blocks = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue((blocks[0]["text"] as? String ?? "").contains("abc"))
    }
}
