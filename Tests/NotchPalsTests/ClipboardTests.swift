import XCTest
@testable import NotchPals

final class ClipboardTests: XCTestCase {
    func testAddInsertsAtFront() {
        var h = ClipboardHistory()
        h.add("a"); h.add("b")
        XCTAssertEqual(h.items.map(\.text), ["b", "a"])
    }

    func testConsecutiveDuplicateIgnored() {
        var h = ClipboardHistory()
        XCTAssertTrue(h.add("a"))
        XCTAssertFalse(h.add("a"))
        h.add("b"); h.add("a")
        XCTAssertEqual(h.items.map(\.text), ["a", "b", "a"])
    }

    func testEmptyIgnored() {
        var h = ClipboardHistory()
        XCTAssertFalse(h.add("  \n"))
        XCTAssertTrue(h.items.isEmpty)
    }

    func testLimit() {
        var h = ClipboardHistory()
        for i in 0..<30 { h.add("\(i)") }
        XCTAssertEqual(h.items.count, 20)
        XCTAssertEqual(h.items.first?.text, "29")
        XCTAssertEqual(h.items.last?.text, "10")
    }

    func testPinnedSurvivesTrimAndSortsFirst() {
        var h = ClipboardHistory(limit: 3)
        h.add("keep")
        h.togglePin(id: h.items[0].id)
        for i in 0..<5 { h.add("\(i)") }
        XCTAssertEqual(h.items.count, 3)
        XCTAssertTrue(h.items.contains { $0.text == "keep" })
        XCTAssertEqual(h.displayItems.first?.text, "keep")
    }

    func testRemoveAndClearUnpinned() {
        var h = ClipboardHistory()
        h.add("a"); h.add("b"); h.add("c")
        h.togglePin(id: h.items[2].id) // a
        h.remove(id: h.items[0].id)    // c
        XCTAssertEqual(h.items.map(\.text), ["b", "a"])
        h.clearUnpinned()
        XCTAssertEqual(h.items.map(\.text), ["a"])
    }

    func testModuleMetadata() {
        let m = ClipboardModule()
        XCTAssertEqual(m.id, "clipboard")
        XCTAssertEqual(m.title, "Portapapeles")
        XCTAssertEqual(m.systemImage, "doc.on.clipboard")
    }
}
