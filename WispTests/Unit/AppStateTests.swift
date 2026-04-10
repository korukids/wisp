import XCTest
@testable import Wisp

final class AppStateTests: XCTestCase {

    func testIdleToRecordingSucceeds() {
        let state = AppState.idle
        let result = state.transition(to: .recording)
        XCTAssertEqual(try result.get(), .recording)
    }

    func testRecordingToProcessingSucceeds() {
        let state = AppState.recording
        let result = state.transition(to: .processing)
        XCTAssertEqual(try result.get(), .processing)
    }

    func testProcessingToIdleSucceeds() {
        let state = AppState.processing
        let result = state.transition(to: .idle)
        XCTAssertEqual(try result.get(), .idle)
    }

    func testIdleToProcessingFails() {
        let state = AppState.idle
        let result = state.transition(to: .processing)
        if case .failure(let error) = result {
            XCTAssertEqual(error, .invalidTransition(from: .idle, to: .processing))
        } else {
            XCTFail("Expected failure for idle → processing")
        }
    }

    func testIdleToIdleFails() {
        let state = AppState.idle
        let result = state.transition(to: .idle)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected failure for idle → idle")
        }
    }

    func testRecordingToIdleFails() {
        let state = AppState.recording
        let result = state.transition(to: .idle)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected failure for recording → idle")
        }
    }

    func testProcessingToRecordingFails() {
        let state = AppState.processing
        let result = state.transition(to: .recording)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected failure for processing → recording")
        }
    }

    // MARK: - Cancelling State Transitions

    func testRecordingToCancellingSucceeds() {
        let state = AppState.recording
        let result = state.transition(to: .cancelling)
        XCTAssertEqual(try result.get(), .cancelling)
    }

    func testCancellingToProcessingSucceeds() {
        let state = AppState.cancelling
        let result = state.transition(to: .processing)
        XCTAssertEqual(try result.get(), .processing)
    }

    func testCancellingToIdleSucceeds() {
        let state = AppState.cancelling
        let result = state.transition(to: .idle)
        XCTAssertEqual(try result.get(), .idle)
    }

    func testIdleToCancellingFails() {
        let state = AppState.idle
        let result = state.transition(to: .cancelling)
        if case .failure(let error) = result {
            XCTAssertEqual(error, .invalidTransition(from: .idle, to: .cancelling))
        } else {
            XCTFail("Expected failure for idle → cancelling")
        }
    }

    func testCancellingToRecordingFails() {
        let state = AppState.cancelling
        let result = state.transition(to: .recording)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected failure for cancelling → recording")
        }
    }

    func testCancellingToCancellingFails() {
        let state = AppState.cancelling
        let result = state.transition(to: .cancelling)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected failure for cancelling → cancelling")
        }
    }
}
