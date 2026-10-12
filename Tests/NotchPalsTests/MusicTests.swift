import AppKit
import XCTest
@testable import NotchPals

@MainActor
private final class MockBackend: MusicBackend {
    let app: MusicApp
    var running: Bool
    var result: Result<MusicSnapshot, MusicError>
    var sent: [MusicCommand] = []

    init(app: MusicApp, running: Bool = true, result: Result<MusicSnapshot, MusicError>) {
        self.app = app
        self.running = running
        self.result = result
    }

    func isRunning() -> Bool { running }
    func fetchSnapshot() throws -> MusicSnapshot { try result.get() }
    func artwork(for track: MusicTrack) async -> NSImage? { nil }
    func send(_ command: MusicCommand) throws { sent.append(command) }
}

final class MusicTests: XCTestCase {
    private let sep = String(MusicParser.separator)

    func testParseStopped() {
        let s = MusicParser.parse("stopped", app: .spotify)
        XCTAssertEqual(s?.state, .stopped)
        XCTAssertNil(s?.track)
    }

    func testParsePlayingWithArtwork() {
        let out = ["playing", "Song", "Artist", "Album", "https://x.test/a.jpg"].joined(separator: sep)
        let s = MusicParser.parse(out, app: .spotify)
        XCTAssertEqual(s?.state, .playing)
        XCTAssertEqual(s?.track?.title, "Song")
        XCTAssertEqual(s?.track?.artist, "Artist")
        XCTAssertEqual(s?.track?.artworkURL?.absoluteString, "https://x.test/a.jpg")
    }

    func testParseWithoutArtworkField() {
        let out = ["paused", "Song", "Artist", "Album"].joined(separator: sep)
        let s = MusicParser.parse(out, app: .appleMusic)
        XCTAssertEqual(s?.state, .paused)
        XCTAssertNil(s?.track?.artworkURL)
    }

    func testParseGarbage() {
        XCTAssertNil(MusicParser.parse("", app: .spotify))
        XCTAssertNil(MusicParser.parse("playing\(sep)only", app: .spotify))
    }

    func testErrorMapping() {
        XCTAssertEqual(MusicError.from(code: -1743, message: "", app: .spotify), .permissionDenied(.spotify))
        XCTAssertEqual(MusicError.from(code: -600, message: "", app: .appleMusic), .notRunning(.appleMusic))
        XCTAssertEqual(MusicError.from(code: 5, message: "x", app: .spotify), .scriptFailed("x"))
    }

    func testChooserPrefersPlaying() {
        let t = MusicTrack(title: "a", artist: "b", album: "c", artworkURL: nil)
        let paused = MusicSnapshot(app: .spotify, state: .paused, track: t)
        let playing = MusicSnapshot(app: .appleMusic, state: .playing, track: t)
        XCTAssertEqual(MusicPlayerChooser.choose([paused, playing]), playing)
        XCTAssertNil(MusicPlayerChooser.choose([]))
    }

    @MainActor
    func testServiceNothingRunning() {
        let b = MockBackend(app: .spotify, running: false, result: .failure(.notRunning(.spotify)))
        let service = MusicService(backends: [b])
        service.refresh()
        XCTAssertNil(service.snapshot)
        XCTAssertNotNil(service.message)
    }

    @MainActor
    func testServicePermissionDeniedShowsMessage() {
        let b = MockBackend(app: .spotify, result: .failure(.permissionDenied(.spotify)))
        let service = MusicService(backends: [b])
        service.refresh()
        XCTAssertNil(service.snapshot)
        XCTAssertEqual(service.message, MusicError.permissionDenied(.spotify).userMessage)
    }

    @MainActor
    func testServicePerformSendsCommand() {
        let t = MusicTrack(title: "a", artist: "b", album: "c", artworkURL: nil)
        let b = MockBackend(app: .spotify, result: .success(MusicSnapshot(app: .spotify, state: .playing, track: t)))
        let service = MusicService(backends: [b])
        service.refresh()
        service.perform(.next)
        XCTAssertEqual(b.sent, [.next])
        XCTAssertEqual(service.snapshot?.track?.title, "a")
    }
}
