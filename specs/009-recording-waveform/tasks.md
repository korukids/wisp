# Tasks: Recording Waveform Indicator

**Input**: Design documents from `/specs/009-recording-waveform/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Included — constitution principle III (Test-First Development) requires TDD.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify baseline compiles and identify integration points

- [x] T001 Verify project builds cleanly on current branch in Wisp/

---

## Phase 2: Foundational (Audio Level Extraction)

**Purpose**: Extract RMS audio levels from the existing AVAudioEngine tap — MUST be complete before any user story

**⚠️ CRITICAL**: All user stories depend on this audio level data pipeline

### Tests

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T002 [P] Write unit test for RMS level extraction: feed known float32 arrays (silence, quiet speech, loud input) and verify 5 normalized output values in range 0.0–1.0, in WispTests/AudioLevelExtractionTests.swift
- [x] T003 [P] Write unit test for logarithmic normalization: verify -50 dB maps to 0.0, -6 dB maps to 1.0, values outside range are clamped, in WispTests/AudioLevelExtractionTests.swift

### Implementation

- [x] T004 Add a static function to compute per-segment RMS levels from a float32 buffer pointer and frame count, returning [Float] of 5 normalized values (log-scaled, clamped 0.0–1.0), in Wisp/Services/AudioCaptureService.swift
- [x] T005 Add `onAudioLevels: (@Sendable ([Float]) -> Void)?` callback property to AudioCaptureService following the existing `onAudioChunk` pattern (capture handler inside lock, call outside lock), in Wisp/Services/AudioCaptureService.swift
- [x] T006 Call the RMS extraction function in the existing tap callback (after format conversion) and invoke `onAudioLevels` with the result — use pointer arithmetic on `floatChannelData[0]` with zero heap allocations, in Wisp/Services/AudioCaptureService.swift

**Checkpoint**: Audio level data flows via callback. Unit tests pass. No UI changes yet.

---

## Phase 3: User Story 1 — Live Audio Waveform During Recording (Priority: P1) 🎯 MVP

**Goal**: Display 5 animated vertical bars on the recording indicator that respond to real-time microphone input

**Independent Test**: Activate recording, speak — bars animate in proportion to voice; stop speaking — bars settle to a low baseline

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T007 [P] [US1] Write unit test verifying WaveformBarsView creates 5 CALayer sublayers with correct initial dimensions and minimum height (~0.15 ratio), in WispTests/StatusIndicatorViewTests.swift
- [x] T008 [P] [US1] Write unit test verifying StatusIndicatorView shows waveform bars and hides label when state is .recording, and hides bars when state is .transcribing/.cancelling/.error/.hidden, in WispTests/StatusIndicatorViewTests.swift

### Implementation for User Story 1

- [x] T009 [US1] Create WaveformBarsView as an NSView subclass with 5 CALayer bar sublayers (each 3pt wide, 2pt spacing, systemRed color, rounded top corners), positioned within a fixed-width container, in Wisp/UI/StatusIndicatorView.swift
- [x] T010 [US1] Add `updateAudioLevels(_ levels: [Float])` method to WaveformBarsView that animates each bar's height using CABasicAnimation (200ms duration, easeOut timing), enforcing minimum height of ~0.15 for silence baseline (FR-008) and maximum of 1.0 for loud input capping (FR-007), in Wisp/UI/StatusIndicatorView.swift
- [x] T011 [US1] Integrate WaveformBarsView into StatusIndicatorView: add as subview with Auto Layout constraints (centered vertically, positioned to the right of the recording dot), show in .recording case of update() and hide the text label, hide in all other states, in Wisp/UI/StatusIndicatorView.swift
- [x] T012 [US1] Add `updateAudioLevels(_ levels: [Float])` passthrough method on StatusOverlayWindow that forwards to the indicator view's waveform bars, in Wisp/UI/StatusOverlayWindow.swift
- [x] T013 [US1] In AppDelegate.startRecording(), set `audioCaptureService.onAudioLevels` to dispatch level updates to `overlayWindow.updateAudioLevels()` on the main thread using DispatchQueue.main.async, in Wisp/App/AppDelegate.swift
- [x] T014 [US1] In AppDelegate.stopRecordingAndTranscribe() and cancelRecording(), set `audioCaptureService.onAudioLevels = nil` to stop level updates when recording ends, in Wisp/App/AppDelegate.swift

**Checkpoint**: Waveform bars visible during recording, responding to voice input. Bars hidden in all other states. MVP complete.

---

## Phase 4: User Story 2 — Waveform Fits the Existing Indicator Style (Priority: P2)

**Goal**: Ensure the waveform integrates seamlessly with the compact HUD design — red dot + bars look cohesive, indicator stays small, transitions are smooth

**Independent Test**: Observe the indicator through a full recording cycle (idle → recording → transcribing → idle) and confirm visual coherence and smooth transitions

### Implementation for User Story 2

- [x] T015 [US2] Adjust StatusOverlayWindow width to accommodate the red dot + 5 bars layout (measure and set appropriate width so bars are not clipped), in Wisp/UI/StatusOverlayWindow.swift
- [x] T016 [US2] Update positionAtBottomCenter() to account for the new window width during recording state, ensuring the indicator remains centered on screen, in Wisp/UI/StatusOverlayWindow.swift
- [x] T017 [US2] Add smooth fade-out animation for WaveformBarsView when transitioning from .recording to any other state, coordinating with the existing 0.2s state transition animation (FR-009), in Wisp/UI/StatusIndicatorView.swift
- [x] T018 [US2] Restore the text label and original window width when transitioning from .recording to .transcribing/.cancelling/.error states, so non-recording states display as before, in Wisp/UI/StatusIndicatorView.swift

**Checkpoint**: Indicator looks cohesive across all state transitions. No visual glitches, no oversized footprint.

---

## Phase 5: User Story 3 — Waveform Responds Correctly Across Microphone Types (Priority: P3)

**Goal**: Verify the waveform accurately reflects input from whichever microphone the user has selected in preferences

**Independent Test**: Select different microphones in preferences, activate recording, confirm waveform reflects each microphone's input

### Implementation for User Story 3

- [x] T019 [US3] Verify that the RMS extraction in the tap callback operates on the same `inputNode` audio data that feeds `onAudioChunk` — both callbacks must share the same audio source so the waveform always matches the recording, in Wisp/Services/AudioCaptureService.swift
- [ ] T020 [US3] Manual test: select built-in microphone in preferences, record, verify bars respond; switch to external microphone, record, verify bars respond from the new source — document results

**Checkpoint**: Waveform correctly reflects the user's selected microphone input.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge case handling and final quality checks

- [x] T021 Fine-tune bar animation parameters (duration, timing curve, minimum height constant) through manual testing for best perceived responsiveness, in Wisp/UI/StatusIndicatorView.swift
- [x] T022 Verify waveform appearance on both Retina and non-Retina displays — ensure bar layers use correct contentsScale, in Wisp/UI/StatusIndicatorView.swift
- [ ] T023 Run full quickstart.md validation: build, activate recording with speech, verify bars animate; stop speaking, verify baseline; transition through all states, verify clean transitions
- [x] T024 Run all unit tests and confirm they pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 — core MVP
- **User Story 2 (Phase 4)**: Depends on Phase 3 (needs bars to exist before polishing layout)
- **User Story 3 (Phase 5)**: Depends on Phase 2 only (verification, no new code likely needed)
- **Polish (Phase 6)**: Depends on Phases 3 and 4

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational (Phase 2) — no dependencies on other stories
- **User Story 2 (P2)**: Depends on User Story 1 (needs waveform bars in place to adjust layout/transitions)
- **User Story 3 (P3)**: Depends on Foundational (Phase 2) only — can run in parallel with US1/US2

### Within Each User Story

- Tests MUST be written and FAIL before implementation (constitution principle III)
- Foundation (level extraction) before UI (bar rendering)
- UI component before wiring (AppDelegate integration)
- Core implementation before polish

### Parallel Opportunities

- T002, T003 can run in parallel (different test functions, same file)
- T007, T008 can run in parallel (different test functions)
- T009, T012 can run in parallel (different files: StatusIndicatorView vs StatusOverlayWindow)
- Phase 5 (US3) can run in parallel with Phase 4 (US2) after Phase 3 completes
- T021, T022 can run in parallel (different concerns)

---

## Parallel Example: User Story 1

```
# Launch tests in parallel:
Task T007: "Unit test for WaveformBarsView layer creation in WispTests/StatusIndicatorViewTests.swift"
Task T008: "Unit test for bar visibility per indicator state in WispTests/StatusIndicatorViewTests.swift"

# After tests written, launch independent implementation tasks:
Task T009: "Create WaveformBarsView in Wisp/UI/StatusIndicatorView.swift"
Task T012: "Add updateAudioLevels passthrough in Wisp/UI/StatusOverlayWindow.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify build)
2. Complete Phase 2: Foundational (audio level extraction + tests)
3. Complete Phase 3: User Story 1 (waveform bars + wiring)
4. **STOP and VALIDATE**: Activate recording, speak, confirm bars respond
5. This is a functional, shippable increment

### Incremental Delivery

1. Setup + Foundational → Audio level pipeline ready
2. Add User Story 1 → Bars visible and responsive → MVP!
3. Add User Story 2 → Visual polish, smooth transitions → Release quality
4. Add User Story 3 → Microphone verification → Full confidence
5. Polish → Edge cases, display testing → Ship

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution principle III requires TDD — tests precede implementation in each phase
- Zero-allocation constraint in audio tap is critical — see research.md R1 and plan.md constraints
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
