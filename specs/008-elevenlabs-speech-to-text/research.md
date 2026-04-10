# Research: ElevenLabs Speech-to-Text Integration

**Feature**: 008-elevenlabs-speech-to-text  
**Date**: 2026-04-10

## R1: ElevenLabs Realtime STT WebSocket API

**Decision**: Use the ElevenLabs Realtime Speech-to-Text WebSocket API (`wss://api.elevenlabs.io/v1/speech-to-text/realtime`) with manual commit strategy.

**Rationale**: The realtime WebSocket API streams audio during recording and returns transcripts incrementally. The `pcm_16000` audio format matches the existing 16kHz float32 mono capture in `AudioCaptureService`, requiring only base64 encoding of chunks. Manual commit strategy lets us trigger final transcription when the user stops recording, giving us control over when the committed transcript is produced.

**Alternatives considered**:
- ElevenLabs batch STT endpoint (`POST /v1/speech-to-text/convert`): Would require buffering all audio then uploading after stop — same latency problem as local model.
- VAD commit strategy: Auto-commits on silence, but we want a single committed transcript when the user presses stop, not mid-sentence commits.

## R2: Audio Format Compatibility

**Decision**: Use `pcm_16000` format with base64 encoding per chunk.

**Rationale**: `AudioCaptureService` already captures at 16kHz float32 mono PCM. The WebSocket API accepts `pcm_16000` natively. Each audio tap callback produces a chunk of PCM data that can be base64-encoded and sent as an `input_audio_chunk` message. No sample rate conversion or format transcoding needed.

**Alternatives considered**:
- `pcm_44100` or `pcm_48000`: Higher quality but unnecessary bandwidth — Whisper-class models work optimally at 16kHz.
- `ulaw_8000`: Lower bandwidth but reduced quality.

## R3: Authentication Approach

**Decision**: Read API key from `.env` file at app startup, pass via `xi-api-key` header on WebSocket connection.

**Rationale**: The `.env` file already exists with `ELEVENLABS_API_KEY`. Header-based auth is simpler than token-based (which requires a separate HTTP call to generate single-use tokens). Token-based auth is designed for client-side web apps where the API key can't be embedded — not relevant for a native desktop app.

**Alternatives considered**:
- Single-use token endpoint: Adds HTTP request latency before each session; designed for browser security, unnecessary for desktop.
- Keychain storage: More secure but adds complexity; `.env` is already gitignored and sufficient for a personal tool.

## R4: WebSocket Lifecycle per Recording Session

**Decision**: Open a new WebSocket connection when recording starts, close it after receiving the committed transcript.

**Rationale**: Each dictation session is independent. Opening per-session avoids managing long-lived connections, reconnection logic, and session timeout errors (`session_time_limit_exceeded`). Connection establishment adds ~100-200ms which is masked by the recording start beep sound.

**Alternatives considered**:
- Persistent WebSocket kept open: Would need reconnection handling, heartbeats, and session timeout management. No latency benefit since audio streaming starts immediately after connection.

## R5: Streaming Architecture Change

**Decision**: Add a chunk callback to `AudioCaptureService` that fires for each audio tap buffer. The new transcription service subscribes to these chunks and forwards them over WebSocket.

**Rationale**: Minimal change to `AudioCaptureService` — it still accumulates the full buffer (needed for cancel/save flows) but also emits each chunk as it arrives. The transcription service handles WebSocket communication independently. Clean separation of concerns.

**Alternatives considered**:
- AsyncStream-based: More idiomatic Swift concurrency but complicates the existing callback-based tap and buffer accumulation pattern.
- Transcription service manages its own audio tap: Duplicates audio capture logic, breaks single-responsibility.

## R6: WhisperKit Removal

**Decision**: Fully remove WhisperKit dependency from Package.swift and delete all WhisperKit-specific code.

**Rationale**: The user explicitly said "replace" the local model. WhisperKit is a ~500MB model download and the sole reason for the `.loading` app state. Removing it simplifies startup, eliminates the model download/preload step, and reduces app size significantly.

**Alternatives considered**:
- Keep WhisperKit as offline fallback: User explicitly chose "replace" over "add alternative". Keeping it adds maintenance burden and dependency weight for an unused feature.

## R7: Word Dictionary Integration with ElevenLabs

**Decision**: Pass word dictionary entries via the `previous_text` field on the first audio chunk, and continue using them in the TextCleanupService post-processing.

**Rationale**: The ElevenLabs API accepts a `previous_text` string with the first chunk that provides context for transcription. Formatting dictionary words as a comma-separated list gives the model hints about expected vocabulary. The existing TextCleanupService already handles dictionary-based corrections in post-processing, providing a second pass.

**Alternatives considered**:
- Only post-processing: Misses the opportunity to improve initial transcription accuracy.
- Only API hints: The on-device LLM cleanup is more reliable for enforcing exact spelling.
