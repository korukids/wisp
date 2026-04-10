import XCTest
@testable import Wisp

final class TranscriptionResultTests: XCTestCase {

    func testCompletedResultContainsText() {
        let result = TranscriptionResult.completed(text: "Hello world.")
        if case .completed(let text) = result {
            XCTAssertEqual(text, "Hello world.")
        } else {
            XCTFail("Expected completed result")
        }
    }

    func testDiscardedTooShort() {
        let result = TranscriptionResult.discarded(reason: .tooShort)
        if case .discarded(let reason) = result {
            XCTAssertEqual(reason, .tooShort)
        } else {
            XCTFail("Expected discarded result")
        }
    }

    func testDiscardedNoSpeech() {
        let result = TranscriptionResult.discarded(reason: .noSpeechDetected)
        if case .discarded(let reason) = result {
            XCTAssertEqual(reason, .noSpeechDetected)
        } else {
            XCTFail("Expected discarded result")
        }
    }

    func testFailedProcessingError() {
        let error = TranscriptionError.processingFailed(message: "out of memory")
        XCTAssertEqual(error, .processingFailed(message: "out of memory"))
    }

    func testFailedMicrophoneUnavailable() {
        let error = TranscriptionError.microphoneUnavailable
        XCTAssertEqual(error, .microphoneUnavailable)
    }

    func testFailedPermissionDenied() {
        let error = TranscriptionError.permissionDenied
        XCTAssertEqual(error, .permissionDenied)
    }
}
