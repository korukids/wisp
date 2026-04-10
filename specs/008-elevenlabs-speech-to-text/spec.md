# Feature Specification: ElevenLabs Speech-to-Text API

**Feature Branch**: `008-elevenlabs-speech-to-text`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "replace local model with elevenlabs voice to text api, streaming if possible. api key is in .env"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dictate Text with Cloud Transcription (Priority: P1)

A user activates dictation via the keyboard shortcut, speaks into their microphone, and stops recording. The spoken audio is transcribed using a cloud-based speech-to-text service instead of the current local model. The transcription result is pasted into the active application, exactly as it works today, but faster.

**Why this priority**: This is the core replacement — without it, no other improvements matter. The local model is too slow, and switching to a cloud service is the entire motivation for this feature.

**Independent Test**: Can be fully tested by activating dictation, speaking a sentence, stopping, and verifying the transcribed text appears in the clipboard/active field within an acceptable timeframe.

**Acceptance Scenarios**:

1. **Given** the app is running and the user has a valid API key configured, **When** the user activates dictation and speaks a sentence, **Then** the audio is sent to the cloud transcription service and the resulting text is produced.
2. **Given** the user has finished speaking and stops recording, **When** transcription completes, **Then** the transcribed text is available to the user (pasted into the active application) with noticeably less delay than the current local model.
3. **Given** the user dictates multiple sentences, **When** recording is stopped, **Then** the full transcription is accurate and preserves the order of speech.

---

### User Story 2 - Streaming Transcription for Near-Instant Results (Priority: P1)

Audio is streamed to the cloud service in real time during recording so that transcription happens concurrently with speaking. When the user stops recording, the transcript is available immediately (or near-immediately) rather than requiring a separate transcription phase after recording ends.

**Why this priority**: The user specifically requested streaming to eliminate the wait time between stopping recording and receiving the transcript. This is the key latency improvement over the current local model approach.

**Independent Test**: Can be tested by recording a 10-second clip and measuring the time between pressing stop and the transcript being available. Should be under 1 second for the final result after stop.

**Acceptance Scenarios**:

1. **Given** the user is actively recording, **When** audio is captured from the microphone, **Then** audio data is streamed to the transcription service in real time (not buffered until recording stops).
2. **Given** the user stops recording, **When** the final audio chunk is sent, **Then** the complete transcript is available within 1 second of pressing stop.
3. **Given** the user speaks for 30 seconds or more, **When** recording is stopped, **Then** the transcript is still available near-instantly because audio was processed during recording.

---

### User Story 3 - Graceful Handling of Service Unavailability (Priority: P2)

If the cloud transcription service is unavailable (network error, invalid API key, rate limiting, service outage), the user receives clear feedback about what went wrong rather than a silent failure or crash.

**Why this priority**: Cloud services introduce a new failure mode that the local model didn't have. Users need to understand when and why transcription fails so they can take corrective action.

**Independent Test**: Can be tested by simulating network disconnection or using an invalid API key and verifying the user sees an appropriate error indication.

**Acceptance Scenarios**:

1. **Given** the network is unavailable, **When** the user attempts to dictate, **Then** the user is shown a clear error indication that transcription could not be completed due to a connectivity issue.
2. **Given** the API key is missing or invalid, **When** the user attempts to dictate, **Then** the user is shown a clear error indicating the API key needs to be configured or is incorrect.
3. **Given** the service returns a rate-limit or server error during streaming, **When** the error occurs, **Then** the user is notified and any partial transcription that was received is preserved rather than discarded.

---

### User Story 4 - Custom Word Dictionary Applied to Cloud Transcription (Priority: P2)

The existing custom word dictionary feature continues to work with the new cloud transcription service. Specialized vocabulary, names, and technical terms that the user has taught the app are still corrected in the final transcription output.

**Why this priority**: The word dictionary is an existing feature that users rely on for accuracy with domain-specific terms. It must continue to function after the transcription backend is replaced.

**Independent Test**: Can be tested by adding a custom word to the dictionary, dictating a sentence containing that word, and verifying the output reflects the learned spelling.

**Acceptance Scenarios**:

1. **Given** the user has custom words in their dictionary, **When** they dictate text containing those words, **Then** the post-processing cleanup step applies the dictionary corrections to the cloud transcription output.

---

### Edge Cases

- What happens when the network connection drops mid-recording? The system should handle partial transcription gracefully and notify the user.
- What happens when the user records silence or very short audio (under 1 second)? The system should handle this without errors.
- What happens when the API key is present in the environment but has expired or been revoked? The user should receive a clear, specific error message.
- What happens when the transcription service returns an empty result? The system should not paste empty text or overwrite the clipboard with nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST send recorded audio to the cloud transcription service for speech-to-text conversion instead of using the local model.
- **FR-002**: System MUST stream audio to the transcription service in real time during recording so that transcription happens concurrently with audio capture.
- **FR-003**: System MUST read the API key from the local environment configuration file (`.env`).
- **FR-004**: System MUST produce the final transcript within 1 second of the user stopping recording (for typical dictation lengths under 60 seconds).
- **FR-005**: System MUST display a clear error indication to the user when transcription fails due to network issues, authentication errors, or service errors.
- **FR-006**: System MUST preserve any partial transcription received before a mid-stream failure rather than discarding it.
- **FR-007**: System MUST continue to apply the existing text cleanup and custom word dictionary post-processing to cloud transcription results.
- **FR-008**: System MUST securely handle the API key — it must not be logged, displayed in the UI, or included in error messages.
- **FR-009**: System MUST support the existing recording flow (hotkey to start, hotkey/escape to stop) without changes to the user-facing interaction model.

### Key Entities

- **Transcription Session**: Represents a single dictation from start to stop — includes the audio stream, the connection to the transcription service, and the resulting transcript.
- **API Configuration**: The API key and any service-specific settings needed to authenticate with the cloud transcription provider.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users receive their transcription within 1 second of stopping recording for dictations under 60 seconds, compared to the current multi-second delay with the local model.
- **SC-002**: Transcription accuracy is equal to or better than the current local model for English speech in typical dictation conditions.
- **SC-003**: 95% of dictation sessions complete successfully when the device has a stable internet connection.
- **SC-004**: Users receive a visible error notification within 3 seconds when transcription fails for any reason.
- **SC-005**: The existing custom word dictionary produces the same correction results regardless of which transcription backend was used.

## Assumptions

- The user has a stable internet connection during dictation (cloud service requires network access).
- The existing `.env` file mechanism is sufficient for API key storage — no additional secrets management is needed.
- The current audio capture format and sample rate are compatible with the cloud service, or can be adapted without user-facing changes.
- The existing text cleanup pipeline (including the ML-based cleanup and custom word dictionary) operates on plain text output and is backend-agnostic.
- The local model will be fully removed rather than kept as a fallback (the user said "replace", not "add alternative").
- The cloud transcription service supports streaming/real-time transcription.
