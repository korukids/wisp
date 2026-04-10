import Foundation

enum IndicatorState: Equatable, Sendable {
    case recording
    case cancelling
    case transcribing
    case error(String)
    case hidden

    static func from(_ appState: AppState) -> IndicatorState {
        switch appState {
        case .idle:
            return .hidden
        case .recording:
            return .recording
        case .cancelling:
            return .cancelling
        case .processing:
            return .transcribing
        }
    }
}
