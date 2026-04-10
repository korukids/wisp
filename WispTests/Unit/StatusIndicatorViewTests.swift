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

    private func findWaveformBars(in view: NSView) -> NSView? {
        view.subviews.first { $0 is WaveformBarsView }
    }

    // MARK: - Recording

    func testRecordingShowsWaveformBars() {
        let view = makeView()
        view.update(.recording)
        let waveform = findWaveformBars(in: view)
        XCTAssertNotNil(waveform, "Waveform bars should exist as subview")
        XCTAssertFalse(waveform!.isHidden, "Waveform bars should be visible during recording")
    }

    func testRecordingHidesLabel() {
        let view = makeView()
        view.update(.recording)
        let label = findLabel(in: view)
        XCTAssertTrue(label?.isHidden ?? false, "Label should be hidden during recording")
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

    // MARK: - Waveform Bars

    func testWaveformBarsHasFiveLayers() {
        let view = makeView()
        view.update(.recording)
        guard let waveform = findWaveformBars(in: view) as? WaveformBarsView else {
            XCTFail("WaveformBarsView not found")
            return
        }
        let barLayers = waveform.layer?.sublayers?.filter { $0.name == "bar" } ?? []
        XCTAssertEqual(barLayers.count, 5, "Should have exactly 5 bar layers")
    }

    func testWaveformBarsHiddenWhenTranscribing() {
        let view = makeView()
        view.update(.recording)
        view.update(.transcribing)
        let waveform = findWaveformBars(in: view)
        XCTAssertTrue(waveform?.isHidden ?? true, "Waveform bars should be hidden when transcribing")
    }

    func testWaveformBarsHiddenWhenCancelling() {
        let view = makeView()
        view.update(.recording)
        view.update(.cancelling)
        let waveform = findWaveformBars(in: view)
        XCTAssertTrue(waveform?.isHidden ?? true, "Waveform bars should be hidden when cancelling")
    }

    func testWaveformBarsHiddenWhenError() {
        let view = makeView()
        view.update(.recording)
        view.update(.error("test"))
        let waveform = findWaveformBars(in: view)
        XCTAssertTrue(waveform?.isHidden ?? true, "Waveform bars should be hidden on error")
    }

    func testWaveformBarsHiddenWhenHidden() {
        let view = makeView()
        view.update(.recording)
        view.update(.hidden)
        let waveform = findWaveformBars(in: view)
        XCTAssertTrue(waveform?.isHidden ?? true, "Waveform bars should be hidden when state is hidden")
    }

    func testLabelRestoredWhenTranscribing() {
        let view = makeView()
        view.update(.recording)
        view.update(.transcribing)
        let label = findLabel(in: view)
        XCTAssertFalse(label?.isHidden ?? true, "Label should be visible when transcribing")
        XCTAssertEqual(label?.stringValue, "Transcribing...")
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
