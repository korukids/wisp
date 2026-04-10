import Foundation

// MARK: - WebSocket Message Types

struct InputAudioChunk: Encodable {
    let messageType = "input_audio_chunk"
    let audioBase64: String
    let commit: Bool
    let sampleRate: Int = 16000
    var previousText: String?

    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case audioBase64 = "audio_base_64"
        case commit
        case sampleRate = "sample_rate"
        case previousText = "previous_text"
    }
}

private struct InboundMessage: Decodable {
    let messageType: String
    var text: String?
    var sessionId: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case text
        case sessionId = "session_id"
        case error
    }
}

// MARK: - Errors

enum ElevenLabsError: Error, Sendable, Equatable {
    case authError(String)
    case quotaExceeded(String)
    case rateLimited(String)
    case sessionTimeLimitExceeded(String)
    case inputError(String)
    case connectionFailed(String)
    case unexpectedDisconnect(partialTranscript: String)
    case serverError(String)

    var userMessage: String {
        switch self {
        case .authError:
            return "Authentication failed — check your ElevenLabs API key."
        case .quotaExceeded:
            return "ElevenLabs usage quota exceeded."
        case .rateLimited:
            return "Rate limited — try again in a moment."
        case .sessionTimeLimitExceeded:
            return "Recording session exceeded the maximum duration."
        case .inputError(let detail):
            return "Transcription input error: \(detail)"
        case .connectionFailed:
            return "Transcription unavailable — check internet connection."
        case .unexpectedDisconnect(let partial):
            if partial.isEmpty {
                return "Connection lost during transcription."
            }
            return "Connection lost — partial transcript preserved."
        case .serverError(let detail):
            return "Transcription service error: \(detail)"
        }
    }
}

// MARK: - TranscriptionService

final class TranscriptionService: @unchecked Sendable {

    private static let endpoint = "wss://api.elevenlabs.io/v1/speech-to-text/realtime"

    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var partialTranscript = ""
    private var wordHints: [String] = []
    private var isFirstChunk = true
    private let lock = NSLock()

    private var committedContinuation: CheckedContinuation<String, Error>?

    func startSession(apiKey: String, wordHints: [String] = []) async throws {
        var components = URLComponents(string: Self.endpoint)!
        components.queryItems = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "manual"),
            URLQueryItem(name: "language_code", value: "en"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        urlSession = session
        let task = session.webSocketTask(with: request)
        webSocketTask = task

        resetSessionState(wordHints: wordHints)

        task.resume()

        let firstMessage = try await receiveOne()
        guard firstMessage.messageType == "session_started" else {
            let errorMsg = firstMessage.error ?? "Unexpected initial message: \(firstMessage.messageType)"
            task.cancel(with: .goingAway, reason: nil)
            throw mapError(type: firstMessage.messageType, detail: errorMsg)
        }

        startReceiveLoop()
    }

    func sendAudioChunk(_ pcmData: Data) {
        lock.lock()
        let isFirst = isFirstChunk
        let hints = wordHints
        if isFirst { isFirstChunk = false }
        lock.unlock()

        let int16Data = Self.float32ToInt16(pcmData)

        var chunk = InputAudioChunk(
            audioBase64: int16Data.base64EncodedString(),
            commit: false
        )
        if isFirst, !hints.isEmpty {
            chunk.previousText = hints.joined(separator: ", ")
        }

        guard let data = try? JSONEncoder().encode(chunk),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error {
                print("[Wisp] WebSocket send error: \(error.localizedDescription)")
            }
        }
    }

    func commitAndGetTranscript() async throws -> String {
        let commitChunk = InputAudioChunk(
            audioBase64: "",
            commit: true
        )
        guard let data = try? JSONEncoder().encode(commitChunk),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw ElevenLabsError.inputError("Failed to encode commit message")
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocketTask?.send(message)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.committedContinuation = continuation
            lock.unlock()
        }
    }

    func cancel() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        lock.lock()
        let continuation = committedContinuation
        committedContinuation = nil
        lock.unlock()

        continuation?.resume(throwing: CancellationError())
    }

    // MARK: - Private

    private static func float32ToInt16(_ data: Data) -> Data {
        let floatCount = data.count / MemoryLayout<Float>.size
        var result = Data(capacity: floatCount * MemoryLayout<Int16>.size)
        data.withUnsafeBytes { raw in
            guard let floats = raw.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            for i in 0..<floatCount {
                let clamped = max(-1.0, min(1.0, floats[i]))
                var sample = Int16(clamped * 32767.0)
                withUnsafeBytes(of: &sample) { result.append(contentsOf: $0) }
            }
        }
        return result
    }

    private nonisolated func resetSessionState(wordHints: [String]) {
        lock.lock()
        self.wordHints = wordHints
        self.isFirstChunk = true
        self.partialTranscript = ""
        lock.unlock()
    }

    private func receiveOne() async throws -> InboundMessage {
        guard let task = webSocketTask else {
            throw ElevenLabsError.connectionFailed("No active WebSocket connection")
        }
        let wsMessage = try await task.receive()
        return try decodeMessage(wsMessage)
    }

    private func startReceiveLoop() {
        guard let task = webSocketTask else { return }

        task.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let wsMessage):
                guard let message = try? self.decodeMessage(wsMessage) else {
                    self.startReceiveLoop()
                    return
                }
                self.handleInboundMessage(message)
                self.startReceiveLoop()

            case .failure(let error):
                self.lock.lock()
                let continuation = self.committedContinuation
                self.committedContinuation = nil
                let partial = self.partialTranscript
                self.lock.unlock()

                if let continuation {
                    if !partial.isEmpty {
                        continuation.resume(returning: partial)
                    } else {
                        continuation.resume(
                            throwing: ElevenLabsError.unexpectedDisconnect(partialTranscript: ""))
                    }
                }
                _ = error
            }
        }
    }

    private func handleInboundMessage(_ message: InboundMessage) {
        switch message.messageType {
        case "partial_transcript":
            if let text = message.text, !text.isEmpty {
                lock.lock()
                partialTranscript = text
                lock.unlock()
            }

        case "committed_transcript":
            let text = message.text ?? ""
            lock.lock()
            let continuation = committedContinuation
            committedContinuation = nil
            lock.unlock()

            continuation?.resume(returning: text)
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            urlSession?.invalidateAndCancel()
            urlSession = nil

        default:
            if isErrorMessageType(message.messageType) {
                let error = mapError(
                    type: message.messageType,
                    detail: message.error ?? "Unknown error"
                )
                lock.lock()
                let continuation = committedContinuation
                committedContinuation = nil
                lock.unlock()

                continuation?.resume(throwing: error)
                webSocketTask?.cancel(with: .goingAway, reason: nil)
                webSocketTask = nil
                urlSession?.invalidateAndCancel()
                urlSession = nil
            }
        }
    }

    private func decodeMessage(_ wsMessage: URLSessionWebSocketTask.Message) throws -> InboundMessage {
        let data: Data
        switch wsMessage {
        case .string(let text):
            guard let d = text.data(using: .utf8) else {
                throw ElevenLabsError.inputError("Invalid UTF-8 in WebSocket message")
            }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            throw ElevenLabsError.inputError("Unknown WebSocket message format")
        }
        return try JSONDecoder().decode(InboundMessage.self, from: data)
    }

    private func isErrorMessageType(_ type: String) -> Bool {
        [
            "error", "auth_error", "quota_exceeded", "rate_limited",
            "session_time_limit_exceeded", "input_error", "chunk_size_exceeded",
            "transcriber_error", "resource_exhausted", "queue_overflow",
        ].contains(type)
    }

    private func mapError(type: String, detail: String) -> ElevenLabsError {
        switch type {
        case "auth_error":
            return .authError(detail)
        case "quota_exceeded":
            return .quotaExceeded(detail)
        case "rate_limited", "commit_throttled":
            return .rateLimited(detail)
        case "session_time_limit_exceeded":
            return .sessionTimeLimitExceeded(detail)
        case "input_error", "chunk_size_exceeded":
            return .inputError(detail)
        default:
            return .serverError(detail)
        }
    }
}
