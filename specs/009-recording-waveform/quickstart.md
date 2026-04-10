# Quickstart: Recording Waveform Indicator

**Branch**: `009-recording-waveform` | **Date**: 2026-04-10

## What This Feature Does

Adds a real-time audio level visualizer (5 vertical bars, mini-equalizer style) to the recording indicator HUD. The bars replace the "Recording..." text while the pulsing red dot is retained. Bars animate in response to actual microphone input so the user can see that recording is working.

## Key Files to Modify

1. **`Wisp/Services/AudioCaptureService.swift`** — Add `onAudioLevels` callback. In the existing tap callback, compute per-segment RMS from the float32 buffer and invoke the new callback with 5 normalized level values.

2. **`Wisp/UI/StatusIndicatorView.swift`** — Add a `WaveformBarsView` (NSView subclass with 5 CALayer bars). In the `.recording` case of `update()`, show the bars view and hide the text label. Add `updateAudioLevels([Float])` method that animates bar heights.

3. **`Wisp/UI/StatusOverlayWindow.swift`** — Add passthrough `updateAudioLevels([Float])` method that forwards to the indicator view. May need to widen the window from 150pt to accommodate bars alongside the dot.

4. **`Wisp/App/AppDelegate.swift`** — In `startRecording()`, set `audioCaptureService.onAudioLevels` to dispatch level updates to `overlayWindow.updateAudioLevels()` on the main thread. Clear the callback in `stopRecordingAndTranscribe()`.

## Implementation Order

1. Audio level extraction (AudioCaptureService) — foundation, testable independently
2. Waveform bar view (StatusIndicatorView) — visual component, testable with mock data
3. Wiring (AppDelegate + StatusOverlayWindow) — integration
4. Polish — animation timing, sizing, state transitions

## Key Constraints

- **Zero allocations in audio tap**: RMS calculation uses pointer arithmetic on existing buffer data
- **Thread boundary**: Level callback fires on audio thread; UI update must be dispatched to main thread
- **Existing callback pattern**: Follow `onAudioChunk` pattern exactly — capture handler inside lock, call outside lock
- **Bar minimum height**: Always show a small baseline height during silence (FR-008)
- **State gating**: Bars only visible during `.recording` state; smoothly hidden on state change

## How to Test

- **Unit test**: Feed known float32 arrays to the RMS extraction function; verify output levels match expected values
- **Unit test**: Verify `StatusIndicatorView` shows bars when state is `.recording` and hides them for all other states
- **Manual test**: Activate recording, speak, verify bars respond; stop speaking, verify bars settle to baseline
