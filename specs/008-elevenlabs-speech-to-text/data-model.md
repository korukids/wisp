# Data Model: ElevenLabs Speech-to-Text Integration

**Feature**: 008-elevenlabs-speech-to-text  
**Date**: 2026-04-10

## Entities

### ElevenLabsConfig

Configuration for connecting to the ElevenLabs API.

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| apiKey | String | `.env` file (`ELEVENLABS_API_KEY`) | Read once at startup, validated non-empty |

### WebSocket Messages (Outbound)

#### InputAudioChunk

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| message_type | String | Yes | Always `"input_audio_chunk"` |
| audio_base_64 | String | Yes | Base64-encoded PCM audio data |
| commit | Bool | Yes | `false` for streaming chunks, `true` for final chunk |
| sample_rate | Int | Yes | Always `16000` |
| previous_text | String | No | Word dictionary hints; first chunk only |

### WebSocket Messages (Inbound)

#### SessionStarted

| Field | Type | Notes |
|-------|------|-------|
| message_type | String | `"session_started"` |
| session_id | String | Unique session identifier |

#### PartialTranscript

| Field | Type | Notes |
|-------|------|-------|
| message_type | String | `"partial_transcript"` |
| text | String | Interim transcription result (may change) |

#### CommittedTranscript

| Field | Type | Notes |
|-------|------|-------|
| message_type | String | `"committed_transcript"` |
| text | String | Final transcription result |

#### ErrorMessage

| Field | Type | Notes |
|-------|------|-------|
| message_type | String | One of: `error`, `auth_error`, `quota_exceeded`, `rate_limited`, `session_time_limit_exceeded`, etc. |
| error | String | Human-readable error description |

## State Transitions

### Transcription Session Lifecycle

```
[Idle] → (hotkey press) → [Connecting WebSocket]
[Connecting WebSocket] → (session_started received) → [Streaming]
[Streaming] → (audio chunks sent, partial_transcripts received) → [Streaming]
[Streaming] → (hotkey press / stop) → [Committing] (final chunk with commit: true)
[Committing] → (committed_transcript received) → [Complete]
[Complete] → (WebSocket closed) → [Idle]

Error paths:
[Connecting WebSocket] → (connection failure) → [Error]
[Streaming] → (WebSocket disconnected) → [Error] (preserve partial transcript)
[Committing] → (error message) → [Error] (preserve partial transcript)
```

## Modified Entities

### AppState (existing)

Remove `.loading` state. App starts directly in `.idle` since there is no model to preload.

```
States: .idle, .recording, .cancelling, .processing
```

### AudioCaptureService (existing)

Add chunk emission alongside existing buffer accumulation:

| New Field | Type | Notes |
|-----------|------|-------|
| onAudioChunk | `((Data) -> Void)?` | Called for each audio tap buffer; nil when not streaming |
