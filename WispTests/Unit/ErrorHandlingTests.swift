import XCTest
@testable import Wisp

final class ErrorHandlingTests: XCTestCase {

    func testTooShortDiscardReason() {
        let result = TranscriptionResult.discarded(reason: .tooShort)
        if case .discarded(let reason) = result {
            XCTAssertEqual(reason, .tooShort)
        } else {
            XCTFail("Expected discarded result")
        }
    }

    func testNoSpeechDiscardReason() {
        let result = TranscriptionResult.discarded(reason: .noSpeechDetected)
        if case .discarded(let reason) = result {
            XCTAssertEqual(reason, .noSpeechDetected)
        } else {
            XCTFail("Expected discarded result")
        }
    }

    func testMicrophoneUnavailableError() {
        let result = TranscriptionResult.failed(error: .microphoneUnavailable)
        if case .failed(let error) = result {
            XCTAssertEqual(error, .microphoneUnavailable)
        } else {
            XCTFail("Expected failed result")
        }
    }

    func testModelNotAvailableError() {
        let result = TranscriptionResult.failed(error: .processingFailed(message: "Model not available"))
        if case .failed(let error) = result {
            XCTAssertEqual(error, .processingFailed(message: "Model not available"))
        } else {
            XCTFail("Expected failed result")
        }
    }

    func testPermissionDeniedError() {
        let result = TranscriptionResult.failed(error: .permissionDenied)
        if case .failed(let error) = result {
            XCTAssertEqual(error, .permissionDenied)
        } else {
            XCTFail("Expected failed result")
        }
    }

    func testProcessingFailedError() {
        let result = TranscriptionResult.failed(
            error: .processingFailed(message: "timeout"))
        if case .failed(let error) = result {
            XCTAssertEqual(error, .processingFailed(message: "timeout"))
        } else {
            XCTFail("Expected failed result")
        }
    }

    func testStateReturnsToIdleAfterDiscard() {
        var state = AppState.recording
        // Simulate: recording → processing (on stop)
        if case .success(let newState) = state.transition(to: .processing) {
            state = newState
        }
        // processing → idle (after error)
        if case .success(let newState) = state.transition(to: .idle) {
            state = newState
        }
        XCTAssertEqual(state, .idle)
    }

    func testStateReturnsToIdleAfterFailure() {
        var state = AppState.recording
        if case .success(let newState) = state.transition(to: .processing) {
            state = newState
        }
        if case .success(let newState) = state.transition(to: .idle) {
            state = newState
        }
        XCTAssertEqual(state, .idle)
    }
}
