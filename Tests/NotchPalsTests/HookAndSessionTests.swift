import XCTest
@testable import NotchPals

final class HookAndSessionTests: XCTestCase {
    let command = "/Users/x/.notchpals/hook.sh"

    func testInstallPreservesOtherSettingsAndIsIdempotent() throws {
        let original: [String: Any] = ["model": "opus", "hooks": ["Stop": [["hooks": [["type": "command", "command": "mi-script"]]]]]]
        let once = try HookInstaller.installing(into: original, command: command)
        XCTAssertEqual(once["model"] as? String, "opus")
        XCTAssertTrue(HookInstaller.isInstalled(once, command: command))
        let stop = (once["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 2) // el hook del usuario + el nuestro
        let twice = try HookInstaller.installing(into: once, command: command)
        XCTAssertEqual(HookInstaller.render(once), HookInstaller.render(twice))
    }

    func testRemoveLeavesUserHooks() throws {
        let original: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "mi-script"]]]]]]
        let installed = try HookInstaller.installing(into: original, command: command)
        let removed = HookInstaller.removing(from: installed, command: command)
        XCTAssertEqual(HookInstaller.render(removed), HookInstaller.render(original))
        XCTAssertFalse(HookInstaller.isInstalled(removed, command: command))
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try HookInstaller.parse(Data("{ no json".utf8)))
        XCTAssertEqual(try HookInstaller.parse(nil).count, 0)
    }

    func testDiffShowsOnlyRealChanges() throws {
        let old = HookInstaller.render([:])
        let new = HookInstaller.render(try HookInstaller.installing(into: [:], command: command))
        let lines = HookInstaller.diff(old: old, new: new)
        XCTAssertTrue(lines.contains { $0.contains("PermissionRequest") })
        XCTAssertTrue(lines.allSatisfy { $0.hasPrefix("+") || $0.hasPrefix("-") })
    }

    func testSessionLifecycle() throws {
        func event(_ json: String) throws -> SessionEvent { try XCTUnwrap(SessionEvent.parse(Data(json.utf8))) }
        var sessions: [String: SessionInfo] = [:]
        let now = Date()
        SessionReducer.apply(try event(#"{"session_id":"s","cwd":"/tmp/app","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/app/a.swift"}}"#), to: &sessions, now: now)
        XCTAssertEqual(sessions["s"]?.project, "app")
        XCTAssertEqual(sessions["s"]?.action, "Leyendo a.swift")
        XCTAssertEqual(sessions["s"]?.state, .working)
        SessionReducer.apply(try event(#"{"session_id":"s","cwd":"/tmp/app","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/a.swift","old_string":"a\nb","new_string":"a\nb\nc"}}"#), to: &sessions, now: now)
        XCTAssertEqual(sessions["s"]?.totalAdded, 3)
        XCTAssertEqual(sessions["s"]?.totalRemoved, 2)
        SessionReducer.apply(try event(#"{"session_id":"s","cwd":"/tmp/app","hook_event_name":"Stop"}"#), to: &sessions, now: now)
        XCTAssertEqual(sessions["s"]?.state, .idle)
        SessionReducer.apply(try event(#"{"session_id":"s","cwd":"/tmp/app","hook_event_name":"SessionEnd"}"#), to: &sessions, now: now)
        XCTAssertNil(sessions["s"])
    }

    func testStaleSessionsArePruned() throws {
        var sessions: [String: SessionInfo] = [:]
        let old = Date().addingTimeInterval(-7200)
        SessionReducer.apply(try XCTUnwrap(SessionEvent.parse(Data(#"{"session_id":"a","hook_event_name":"Stop"}"#.utf8))), to: &sessions, now: old)
        SessionReducer.apply(try XCTUnwrap(SessionEvent.parse(Data(#"{"session_id":"b","hook_event_name":"Stop"}"#.utf8))), to: &sessions, now: Date())
        XCTAssertNil(sessions["a"])
        XCTAssertNotNil(sessions["b"])
    }
}
