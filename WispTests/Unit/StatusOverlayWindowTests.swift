import AppKit
import XCTest
@testable import Wisp

@MainActor
final class StatusOverlayWindowTests: XCTestCase {

    func testDefaultWindowLevelIsFloating() {
        let window = StatusOverlayWindow()
        XCTAssertEqual(window.level, .floating)
    }

    func testIgnoresMouseEvents() {
        let window = StatusOverlayWindow()
        XCTAssertTrue(window.ignoresMouseEvents)
    }

    func testPositionIsBottomCenter() {
        let window = StatusOverlayWindow()
        window.positionAtBottomCenter()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            XCTFail("No screen available")
            return
        }

        let screenFrame = screen.visibleFrame
        let expectedX = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
        let expectedY = screenFrame.origin.y + 40

        XCTAssertEqual(window.frame.origin.x, expectedX, accuracy: 1)
        XCTAssertEqual(window.frame.origin.y, expectedY, accuracy: 1)
    }

    func testShowWithRecordingSetsAboveFullscreenLevel() {
        let window = StatusOverlayWindow()
        window.show(state: .recording)
        let expectedLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        XCTAssertEqual(window.level, expectedLevel)
    }

    func testShowWithTranscribingSetsAboveFullscreenLevel() {
        let window = StatusOverlayWindow()
        window.show(state: .transcribing)
        let expectedLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        XCTAssertEqual(window.level, expectedLevel)
    }

    func testHideOrdersOut() {
        let window = StatusOverlayWindow()
        window.show(state: .recording)
        XCTAssertTrue(window.isVisible)
        window.hide()
        // Animation completes asynchronously; verify after a short delay
        let expectation = expectation(description: "Window hidden after animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(window.isVisible)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
}
