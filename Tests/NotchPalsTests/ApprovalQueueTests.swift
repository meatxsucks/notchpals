import XCTest
@testable import NotchPals

final class ApprovalQueueTests: XCTestCase {
    private func request(_ name: String) -> ApprovalRequest {
        ApprovalRequest(tool: name, summary: name, cwd: nil)
    }

    func testFIFOOrder() {
        var queue = ApprovalQueue()
        let a = request("a"), b = request("b"), c = request("c")
        XCTAssertEqual(queue.enqueue(a), .queued(position: 1))
        XCTAssertEqual(queue.enqueue(b), .queued(position: 2))
        XCTAssertEqual(queue.enqueue(c), .queued(position: 3))
        XCTAssertEqual(queue.entries.map(\.request.tool), ["a", "b", "c"])
        XCTAssertEqual(queue.first?.id, a.id)
        queue.resolve(a.id)
        XCTAssertEqual(queue.first?.id, b.id)
    }

    func testSixthRequestOverflowsToAsk() {
        var queue = ApprovalQueue()
        for i in 1...5 { XCTAssertEqual(queue.enqueue(request("r\(i)")), .queued(position: i)) }
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.enqueue(request("r6")), .overflow(.ask))
        XCTAssertEqual(queue.count, 5)
        XCTAssertEqual(queue.entries.map(\.request.tool), ["r1", "r2", "r3", "r4", "r5"])
    }

    func testResolveFreesSpace() {
        var queue = ApprovalQueue()
        let first = request("r1")
        _ = queue.enqueue(first)
        for i in 2...5 { _ = queue.enqueue(request("r\(i)")) }
        XCTAssertEqual(queue.enqueue(request("x")), .overflow(.ask))
        XCTAssertEqual(queue.resolve(first.id)?.id, first.id)
        XCTAssertNil(queue.resolve(first.id))
        XCTAssertEqual(queue.enqueue(request("r6")), .queued(position: 5))
        XCTAssertEqual(queue.count, 5)
    }

    func testExpireUsesInjectedClock() {
        var queue = ApprovalQueue()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let old = request("old"), recent = request("recent")
        _ = queue.enqueue(old, now: t0)
        _ = queue.enqueue(recent, now: t0.addingTimeInterval(60))
        XCTAssertTrue(queue.expire(now: t0.addingTimeInterval(99), timeout: 100).isEmpty)
        let expired = queue.expire(now: t0.addingTimeInterval(100), timeout: 100)
        XCTAssertEqual(expired.map(\.id), [old.id])
        XCTAssertEqual(queue.entries.map(\.id), [recent.id])
        XCTAssertEqual(queue.expire(now: t0.addingTimeInterval(500), timeout: 100).count, 1)
        XCTAssertTrue(queue.isEmpty)
    }

    func testClear() {
        var queue = ApprovalQueue()
        _ = queue.enqueue(request("a"))
        _ = queue.enqueue(request("b"))
        XCTAssertEqual(queue.clear().count, 2)
        XCTAssertTrue(queue.isEmpty)
    }
}
