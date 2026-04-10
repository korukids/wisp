import Foundation

enum TranscriptionResult: Sendable {
    case completed(text: String)
    case discarded(reason: DiscardReason)
    case failed(error: TranscriptionError)
}

enum DiscardReason: String, Sendable, Equatable {
    case tooShort
    case noSpeechDetected
}

enum TranscriptionError: Error, Sendable, Equatable {
    case processingFailed(message: String)
    case microphoneUnavailable
    case permissionDenied
}
