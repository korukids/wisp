import Foundation

enum AppState: Equatable, Sendable {
    case idle
    case recording
    case cancelling
    case processing

    enum TransitionError: Error, Equatable {
        case invalidTransition(from: AppState, to: AppState)
    }

    func transition(to newState: AppState) -> Result<AppState, TransitionError> {
        switch (self, newState) {
        case (.idle, .recording):
            return .success(.recording)
        case (.recording, .cancelling):
            return .success(.cancelling)
        case (.recording, .processing):
            return .success(.processing)
        case (.cancelling, .processing):
            return .success(.processing)
        case (.cancelling, .idle):
            return .success(.idle)
        case (.processing, .idle):
            return .success(.idle)
        default:
            return .failure(.invalidTransition(from: self, to: newState))
        }
    }
}
