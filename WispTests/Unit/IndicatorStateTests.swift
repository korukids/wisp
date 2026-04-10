import XCTest
@testable import Wisp

final class IndicatorStateTests: XCTestCase {

    func testIdleMapsToHidden() {
        XCTAssertEqual(IndicatorState.from(.idle), .hidden)
    }

    func testRecordingMapsToRecording() {
        XCTAssertEqual(IndicatorState.from(.recording), .recording)
    }

    func testProcessingMapsToTranscribing() {
        XCTAssertEqual(IndicatorState.from(.processing), .transcribing)
    }

    func testCancellingMapsToCancelling() {
        XCTAssertEqual(IndicatorState.from(.cancelling), .cancelling)
    }
}
