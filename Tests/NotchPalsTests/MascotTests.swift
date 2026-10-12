import XCTest
@testable import NotchPals

final class MascotTests: XCTestCase {
    private func resolve(approval: Bool = false, working: Bool = false, music: Bool = false,
                         drag: Bool = false, finished: Bool = false) -> MascotMood {
        MascotMood.resolve(hasPendingApproval: approval, isWorking: working, isMusicPlaying: music,
                           isDraggingFile: drag, justFinished: finished)
    }

    func testIdleByDefault() {
        XCTAssertEqual(resolve(), .idle)
    }

    func testSingleSignals() {
        XCTAssertEqual(resolve(working: true), .working)
        XCTAssertEqual(resolve(music: true), .dancing)
        XCTAssertEqual(resolve(finished: true), .happy)
        XCTAssertEqual(resolve(drag: true), .curious)
        XCTAssertEqual(resolve(approval: true), .alert)
    }

    func testPriorityOrder() {
        XCTAssertEqual(resolve(approval: true, working: true, music: true, drag: true, finished: true), .alert)
        XCTAssertEqual(resolve(working: true, music: true, drag: true, finished: true), .curious)
        XCTAssertEqual(resolve(working: true, music: true, finished: true), .happy)
        XCTAssertEqual(resolve(working: true, music: true), .dancing)
    }

    func testPoseIsFiniteAndBlinkInRange() {
        for mood in MascotMood.allCases {
            for i in 0..<200 {
                let t = Double(i) * 0.07
                let p = MascotPose.make(mood: mood, at: t)
                XCTAssertTrue(p.blink >= 0 && p.blink <= 1)
                XCTAssertTrue(p.scaleX.isFinite && p.scaleY.isFinite && p.offsetY.isFinite)
            }
        }
    }

    func testAlertIsAmberOthersNot() {
        XCTAssertTrue(MascotPose.make(mood: .alert, at: 1).amber)
        XCTAssertFalse(MascotPose.make(mood: .idle, at: 1).amber)
    }
}
