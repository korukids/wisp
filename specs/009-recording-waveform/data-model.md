# Data Model: Recording Waveform Indicator

**Branch**: `009-recording-waveform` | **Date**: 2026-04-10

## Overview

This feature introduces no persistent data. All data is ephemeral — audio levels flow from the capture pipeline to the UI and are discarded after rendering. The "data model" describes the transient values exchanged between components.

## Entities

### AudioLevelSample

Represents a single set of bar levels extracted from one audio buffer.

| Attribute | Type     | Description                                                        |
| --------- | -------- | ------------------------------------------------------------------ |
| levels    | [Float]  | Array of 5 normalized values (0.0–1.0), one per bar               |
| timestamp | implicit | Not stored — arrives in real-time via callback, rendered, discarded |

**Derivation**: Each level value is computed by:
1. Splitting the incoming PCM float32 buffer into 5 equal segments
2. Calculating RMS amplitude for each segment
3. Converting to decibel scale (20 * log10(rms))
4. Normalizing to 0.0–1.0 range using floor (-50 dB) and ceiling (-6 dB) thresholds
5. Clamping to [0.0, 1.0]

**Lifecycle**: Created in audio tap callback → passed via `onAudioLevels` callback → dispatched to main thread → consumed by waveform view → discarded. No persistence, no history, no accumulation.

### WaveformBarState

Represents the visual state of a single bar in the waveform display.

| Attribute   | Type  | Description                                                  |
| ----------- | ----- | ------------------------------------------------------------ |
| targetHeight | Float | Target height ratio (0.0–1.0) from latest AudioLevelSample  |
| currentHeight | Float | Current animated height (interpolated by Core Animation)    |
| minHeight   | Float | Minimum visible height (constant, ~0.15) for silence baseline |

**Constraints**:
- `currentHeight` is always >= `minHeight` (ensures FR-008: visible baseline during silence)
- `targetHeight` is always <= 1.0 (ensures FR-007: visual capping for loud input)
- Height transitions animate over ~200ms with easeOut timing

## State Transitions

No new state machine. The waveform rendering is gated on the existing `IndicatorState.recording` case:

```
IndicatorState == .recording  →  waveform bars visible, receiving level updates
IndicatorState != .recording  →  waveform bars hidden, no level processing
```

The transition from `.recording` to any other state triggers a smooth fade-out of the bars (FR-009), coordinated with the existing 0.2s state transition animation in `StatusOverlayWindow.show()`.

## Relationships

```
AudioCaptureService (tap callback)
    ──onAudioLevels([Float])──►
AppDelegate (main thread dispatch)
    ──updateAudioLevels([Float])──►
StatusOverlayWindow
    ──updateAudioLevels([Float])──►
StatusIndicatorView (WaveformBarsView)
    ──animates bar heights──►
Core Animation (CALayer)
```

No database, no file storage, no network transmission.
