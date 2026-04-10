import AppKit
import XCTest
@testable import Wisp

@MainActor
final class StatusIndicatorViewTests: XCTestCase {

    private func makeView() -> StatusIndicatorView {
        StatusIndicatorView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
    }

    private func findLabel(in view: NSView) -> NSTextField? {
        view.subviews.compactMap { $0 as? NSTextField }.first
    }

    private func findSpinner(in view: NSView) -> NSProgressIndicator? {
        view.subviews.compactMap { $0 as? NSProgressIndicator }.first
    }

    // MARK: - Recording

    func testRecordingShowsLabel() {
        let view = makeView()
        view.update(.recording)
        let label = findLabel(in: view)
        XCTAssertEqual(label?.stringValue, "Recording...")
    }

    func testRecordingHidesSpinner() {
        let view = makeView()
        view.update(.recording)
        let spinner = findSpinner(in: view)
        XCTAssertTrue(spinner?.isHidden ?? true)
    }

    func testRecordingIsVisible() {
        let view = makeView()
        view.update(.recording)
        XCTAssertFalse(view.isHidden)
    }

    // MARK: - Transcribing

    func testTranscribingShowsLabel() {
        let view = makeView()
        view.update(.transcribing)
        let label = findLabel(in: view)
        XCTAssertEqual(label?.stringValue, "Transcribing...")
    }

    func testTranscribingShowsSpinner() {
        let view = makeView()
        view.update(.transcribing)
        let spinner = findSpinner(in: view)
        XCTAssertFalse(spinner!.isHidden)
    }

    func testTranscribingLabelIsBlue() {
        let view = makeView()
        view.update(.transcribing)
        let label = findLabel(in: view)
        XCTAssertEqual(label?.textColor, NSColor.systemBlue)
    }

    // MARK: - Error

    func testErrorShowsMessage() {
        let view = makeView()
        view.update(.error("Something went wrong"))
        let label = findLabel(in: view)
        XCTAssertEqual(label?.stringValue, "Something went wrong")
    }

    func testErrorHidesSpinner() {
        let view = makeView()
        view.update(.error("fail"))
        let spinner = findSpinner(in: view)
        XCTAssertTrue(spinner?.isHidden ?? true)
    }

    // MARK: - Hidden

    func testHiddenHidesView() {
        let view = makeView()
        view.update(.recording)
        XCTAssertFalse(view.isHidden)
        view.update(.hidden)
        XCTAssertTrue(view.isHidden)
    }

    // MARK: - Error Auto-Dismiss

    func testErrorAutoDismissesAfterDelay() {
        let view = makeView()
        let expectation = expectation(description: "Error dismissed")
        view.onErrorDismissed = {
            expectation.fulfill()
        }
        view.update(.error("test error"))
        XCTAssertFalse(view.isHidden)
        wait(for: [expectation], timeout: 5)
        XCTAssertTrue(view.isHidden)
    }
}
