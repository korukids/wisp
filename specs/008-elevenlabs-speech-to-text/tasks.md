# Tasks: ElevenLabs Speech-to-Text

**Input**: Design documents from `/specs/008-elevenlabs-speech-to-text/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Remove WhisperKit, add .env loading infrastructure

- [x] T001 Remove WhisperKit dependency from Package.swift (delete the package URL and target dependency entries)
- [x] T002 [P] Create EnvLoader service to parse .env file and return key-value dictionary in Wisp/Services/EnvLoader.swift
- [x] T003 [P] Verify .env is listed in .gitignore (add if missing)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure changes that MUST be complete before user story implementation

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Define Codable structs for all WebSocket message types (InputAudioChunk, SessionStarted, PartialTranscript, CommittedTranscript, ErrorMessage) at top of Wisp/Services/TranscriptionService.swift — use snake_case CodingKeys mapping to the ElevenLabs JSON wire format
- [x] T005 [P] Remove `.loading` state and its transitions from Wisp/Models/AppState.swift
- [x] T006 [P] Remove `.modelLoading` case from Wisp/Models/IndicatorState.swift and its `from(_:)` mapping
- [x] T007 Add `onAudioChunk: ((Data) -> Void)?` property to AudioCaptureService and call it from the audio tap callback (alongside existing buffer append) in Wisp/Services/AudioCaptureService.swift

**Checkpoint**: Foundation ready — message types defined, state model updated, audio chunk emission in place

---

## Phase 3: User Story 1+2 — Cloud Streaming Transcription (Priority: P1) MVP

**Goal**: Replace local WhisperKit transcription with ElevenLabs Realtime WebSocket API. Audio streams to cloud during recording; transcript available within 1 second of stopping.

**Note**: User Stories 1 (cloud transcription) and 2 (streaming for near-instant results) are combined because the ElevenLabs Realtime WebSocket API is inherently streaming — there is no non-streaming path to implement separately.

**Independent Test**: Activate dictation via hotkey, speak a sentence, stop recording. Transcribed text should be pasted into the active app within ~1 second of pressing stop.

### Implementation

- [x] T008 [US1] Rewrite TranscriptionService in Wisp/Services/TranscriptionService.swift — implement: (1) `startSession(apiKey:, wordHints:)` opens URLSessionWebSocketTask to `wss://api.elevenlabs.io/v1/speech-to-text/realtime` with `xi-api-key` header, `audio_format=pcm_16000`, `commit_strategy=manual`, `language_code=en`; waits for `session_started` message; (2) `sendAudioChunk(_: Data)` base64-encodes PCM data and sends as `input_audio_chunk` with `commit: false` (first chunk includes `previous_text` from word hints); (3) `commitAndGetTranscript() async throws -> String` sends final empty chunk with `commit: true`, listens for `committed_transcript`, returns text; (4) `cancel()` closes WebSocket; (5) receive loop accumulates `partial_transcript` text and handles error messages
- [x] T009 [US1] Rewire AppDelegate recording flow in Wisp/App/AppDelegate.swift — (1) remove all WhisperKit model preloading and warm-up code; (2) load API key via EnvLoader at startup, store as property; (3) on recording start: call `TranscriptionService.startSession(apiKey:, wordHints:)`, set `AudioCaptureService.onAudioChunk` to call `TranscriptionService.sendAudioChunk`; (4) on recording stop: call `TranscriptionService.commitAndGetTranscript()`, pass result to existing TextCleanupService + PasteService pipeline; (5) update cancel flow: on countdown expiry call `commitAndGetTranscript()` then `transcribeAndSave`; on second Escape call `commitAndGetTranscript()` then `transcribeAndPaste`; (6) start app directly in `.idle` state (no `.loading` transition)
- [x] T010 [P] [US1] Remove model loading hourglass icon state from Wisp/UI/MenuBarController.swift — remove the `.loading` case from icon update switch and any model-loading-specific menu items
- [x] T011 [P] [US1] Remove model loading visual state (`.modelLoading` spinner + "Loading model..." text) from Wisp/UI/StatusIndicatorView.swift

**Checkpoint**: Core dictation flow works end-to-end with cloud transcription. Audio streams during recording, transcript available near-instantly on stop. This is the MVP.

---

## Phase 4: User Story 3 — Graceful Error Handling (Priority: P2)

**Goal**: Surface clear error messages for network failures, invalid API keys, rate limits, and mid-stream disconnects. Preserve partial transcripts on failure.

**Independent Test**: Disconnect network during recording — verify error notification appears and any partial transcript is preserved. Use invalid API key — verify clear error message about authentication.

### Implementation

- [x] T012 [US3] Map ElevenLabs WebSocket error message types (`auth_error`, `quota_exceeded`, `rate_limited`, `session_time_limit_exceeded`, `input_error`) to user-facing error strings in Wisp/Services/TranscriptionService.swift — add an `ElevenLabsError` enum and a mapping function
- [x] T013 [US3] Handle mid-stream WebSocket disconnection in TranscriptionService receive loop — on unexpected close, return accumulated partial transcript text (from `partial_transcript` messages) instead of throwing, so callers can preserve partial results; in Wisp/Services/TranscriptionService.swift
- [x] T014 [US3] Validate API key presence at app startup in Wisp/App/AppDelegate.swift — if EnvLoader returns nil or empty for `ELEVENLABS_API_KEY`, show error via StatusIndicatorView overlay (`.error("API key missing — add ELEVENLABS_API_KEY to .env")`) and disable hotkey recording
- [x] T015 [US3] Handle WebSocket connection failure (no network) in AppDelegate recording flow in Wisp/App/AppDelegate.swift — if `TranscriptionService.startSession` throws, transition back to `.idle`, show error overlay ("Transcription unavailable — check internet connection"), play error sound

**Checkpoint**: All error scenarios produce clear user feedback. Partial transcripts are preserved on mid-stream failures.

---

## Phase 5: User Story 4 — Word Dictionary Integration (Priority: P2)

**Goal**: Existing custom word dictionary continues to improve transcription accuracy with the new cloud backend.

**Independent Test**: Add a custom word (e.g., "Wisp") to the dictionary. Dictate a sentence containing that word. Verify the output uses the dictionary spelling.

### Implementation

- [x] T016 [US4] Pass word dictionary entries as `previous_text` on first audio chunk in Wisp/Services/TranscriptionService.swift — format as comma-separated string from wordHints parameter in `startSession`, include in first `sendAudioChunk` call
- [x] T017 [US4] Verify word hints are passed through AppDelegate to both TranscriptionService (via `startSession` wordHints parameter) and TextCleanupService (via existing `cleanup` wordHints parameter) in Wisp/App/AppDelegate.swift — ensure the same `WordDictionaryStore.words` array feeds both

**Checkpoint**: Dictionary words improve cloud transcription accuracy via API hints and post-processing cleanup.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Security hardening and end-to-end validation

- [x] T018 [P] Audit all error messages and log statements to ensure API key value is never included — check Wisp/Services/TranscriptionService.swift, Wisp/App/AppDelegate.swift, Wisp/Services/EnvLoader.swift
- [x] T019 Validate quickstart.md end-to-end flow: build, run, activate dictation, verify transcript pasted within 1 second of stop

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **US1+2 Cloud Streaming (Phase 3)**: Depends on Phase 2 — this is the MVP
- **US3 Error Handling (Phase 4)**: Depends on Phase 3 (needs working TranscriptionService to add error handling)
- **US4 Word Dictionary (Phase 5)**: Depends on Phase 3 (needs working streaming to add hints)
- **Polish (Phase 6)**: Depends on Phases 3-5

### User Story Dependencies

- **US1+2 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **US3 (P2)**: Depends on US1+2 being implemented (adds error handling to existing streaming code)
- **US4 (P2)**: Depends on US1+2 being implemented (adds dictionary integration to existing streaming code)
- **US3 and US4**: Independent of each other — can be done in either order or in parallel

### Within Each Phase

- Tasks marked [P] can run in parallel
- T008 before T009 (TranscriptionService must exist before AppDelegate can wire it)
- T010 and T011 can run in parallel with T008/T009 (different files)
- T012 before T013 (error types must be defined before disconnect handling uses them)

### Parallel Opportunities

```text
Phase 1: T002 ∥ T003 (after T001)
Phase 2: T004 ∥ T005 ∥ T006 (then T007)
Phase 3: T010 ∥ T011 (parallel with T008 → T009)
Phase 4: T012 → T013, then T014 ∥ T015
Phase 5: T016 ∥ T017
Phase 6: T018 ∥ T019
```

---

## Implementation Strategy

### MVP First (User Stories 1+2 Only)

1. Complete Phase 1: Setup (remove WhisperKit, add EnvLoader)
2. Complete Phase 2: Foundational (message types, state cleanup, chunk callback)
3. Complete Phase 3: US1+2 Cloud Streaming Transcription
4. **STOP and VALIDATE**: Test dictation end-to-end — speak, stop, verify paste within 1 second
5. Ship if ready — error handling and dictionary integration are incremental improvements

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. Add US1+2 → Test end-to-end → **MVP ships here**
3. Add US3 → Test error scenarios → More robust
4. Add US4 → Test dictionary words → Full feature parity
5. Polish → Security audit + validation → Done

---

## Notes

- US1 and US2 are merged into a single phase because the ElevenLabs Realtime API is inherently streaming
- No test tasks generated (not explicitly requested in spec)
- WhisperKit removal means the app starts instantly — no model download or preload step
- The `pcm_16000` audio format matches existing AudioCaptureService output — no transcoding needed
- Total: 19 tasks across 6 phases
