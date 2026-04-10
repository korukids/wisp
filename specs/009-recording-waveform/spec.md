# Feature Specification: Recording Waveform Indicator

**Feature Branch**: `009-recording-waveform`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "Show a waveform on the recording indicator so it's clear to users it's actually recording"

## Clarifications

### Session 2026-04-10

- Q: What visual style should the waveform use? → A: Bar columns — vertical bars at varying heights, like a mini equalizer.
- Q: Should the waveform replace or coexist with the red dot and "Recording..." text? → A: Keep the red dot as a color anchor; bar columns replace the "Recording..." text.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Live Audio Waveform During Recording (Priority: P1)

As a user, when I activate recording, I see a real-time waveform visualization on the recording indicator that moves in response to my voice. This gives me immediate, continuous confidence that the microphone is picking up my speech.

**Why this priority**: This is the core feature. Without the waveform responding to actual audio input, the indicator provides no more feedback than the existing pulsing red dot. The waveform must reflect real audio levels to fulfill the feature's purpose.

**Independent Test**: Can be fully tested by activating recording and speaking — the waveform should visibly respond to voice input, and go quiet when the user stops speaking.

**Acceptance Scenarios**:

1. **Given** the user activates recording, **When** they speak into the microphone, **Then** the waveform animates in proportion to the volume and cadence of their speech.
2. **Given** the user is recording, **When** they stop speaking (silence), **Then** the waveform settles to a flat or near-flat baseline, indicating the mic is still active but no audio is detected.
3. **Given** the user activates recording, **When** the recording indicator appears, **Then** the waveform is visible immediately without any noticeable delay.

---

### User Story 2 - Waveform Fits the Existing Indicator Style (Priority: P2)

As a user, the waveform visualization feels like a natural part of the existing recording indicator. It does not make the indicator distractingly large, visually cluttered, or inconsistent with the app's minimal aesthetic.

**Why this priority**: The recording indicator is a small, non-intrusive HUD. The waveform must integrate seamlessly — if it breaks the visual design or becomes distracting, it undermines the user experience rather than improving it.

**Independent Test**: Can be tested by observing the recording indicator with the waveform active and confirming it looks cohesive, remains compact, and does not obscure other screen content.

**Acceptance Scenarios**:

1. **Given** the recording indicator is displayed with the waveform, **When** the user glances at it, **Then** the red dot and bar column waveform are clearly visible together without enlarging the indicator beyond a comfortable size.
2. **Given** the recording indicator transitions between states (recording, transcribing, cancelling), **When** the state changes away from recording, **Then** the waveform is no longer shown and the indicator displays the appropriate state content.

---

### User Story 3 - Waveform Responds Correctly Across Microphone Types (Priority: P3)

As a user who may switch between different microphones (built-in, external, headset), the waveform accurately reflects the audio input regardless of which microphone is selected.

**Why this priority**: Users may have configured a non-default microphone in preferences. The waveform must use the same audio source as the recording engine to avoid confusion (e.g., waveform showing silence while actually recording audio).

**Independent Test**: Can be tested by selecting different microphones in preferences, activating recording, and confirming the waveform reflects the input from the selected microphone.

**Acceptance Scenarios**:

1. **Given** the user has selected a specific microphone in preferences, **When** they activate recording, **Then** the waveform reflects audio levels from that selected microphone.
2. **Given** the user switches microphones between recordings, **When** they start a new recording, **Then** the waveform uses the newly selected microphone's input.

---

### Edge Cases

- What happens when the microphone input is extremely loud (clipping)? The waveform should cap at its maximum visual amplitude without visual glitches or overflow.
- What happens when the microphone input is very quiet? The waveform should still show subtle movement so the user knows recording is active, distinguishable from a completely flat line.
- What happens if the selected microphone is disconnected during recording? The waveform should reflect the loss of input (go flat), consistent with whatever error handling the app already provides.
- What happens during the transition from the recording state to the transcribing state? The waveform should smoothly disappear and be replaced by the transcribing indicator.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The recording indicator MUST display a real-time audio waveform when in the recording state.
- **FR-002**: The waveform MUST reflect actual microphone input levels — it must not be a static or purely decorative animation.
- **FR-003**: The waveform MUST update smoothly and frequently enough that it feels responsive to speech (no perceptible lag between speaking and waveform movement).
- **FR-004**: The waveform MUST use audio data from the same microphone source that the recording engine uses.
- **FR-005**: The waveform MUST be contained within the recording indicator without significantly enlarging its footprint on screen.
- **FR-006**: The waveform MUST only appear during the recording state — it must not be shown during transcribing, cancelling, or error states.
- **FR-007**: The waveform amplitude MUST be visually capped so that extremely loud input does not cause visual overflow or artifacts.
- **FR-008**: The waveform MUST show subtle baseline activity during silence to differentiate "recording but quiet" from "not recording."
- **FR-009**: The waveform MUST transition smoothly when the recording state ends (fade out or animate to the next state indicator).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of users can visually confirm that recording is actively capturing audio by looking at the indicator (waveform moves in sync with speech).
- **SC-002**: The waveform responds to voice input within 100 milliseconds of the sound being produced — perceived as instantaneous.
- **SC-003**: The waveform does not increase the recording indicator's screen footprint by more than 50% compared to the current design.
- **SC-004**: State transitions (recording to transcribing, recording to cancelling) complete their visual transition within 300 milliseconds with no visual glitches.
- **SC-005**: Users can distinguish between "recording with silence" and "not recording" by observing the waveform baseline activity.

## Assumptions

- The existing recording indicator (floating HUD panel at bottom-center of screen) will be the host for the waveform — no new windows or overlays are needed.
- Audio level data is already accessible from the microphone input pipeline used for recording; no new audio capture mechanism is required.
- The pulsing red dot is retained as a color anchor during recording. The bar column waveform replaces the "Recording..." text, sitting alongside the dot.
- The waveform style is vertical bar columns (mini equalizer), not a continuous wave line or full spectrogram.
- Performance impact of rendering the waveform is negligible — the visualization should not degrade recording quality or system responsiveness.
