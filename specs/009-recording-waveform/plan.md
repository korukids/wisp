# Implementation Plan: Recording Waveform Indicator

**Branch**: `009-recording-waveform` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-recording-waveform/spec.md`

## Summary

Add a real-time bar column waveform to the recording indicator HUD that visualizes live microphone input levels. The waveform replaces the "Recording..." text while retaining the pulsing red dot as a color anchor. Audio amplitude data is extracted from the existing AVAudioEngine tap callback and rendered as animated vertical bars in the StatusIndicatorView.

## Technical Context

**Language/Version**: Swift 6.1+ with strict concurrency checking enabled  
**Primary Dependencies**: AVFoundation (existing audio capture), AppKit (existing indicator UI), Core Animation (bar rendering)  
**Storage**: N/A — waveform is ephemeral visual state only  
**Testing**: XCTest — mock audio buffers for level extraction, snapshot/behavioral tests for view states  
**Target Platform**: macOS 26+, Apple Silicon and Intel  
**Project Type**: Desktop app (background utility)  
**Performance Goals**: Waveform updates at 30+ fps perceived smoothness; audio level extraction adds zero allocations in the audio tap hot path  
**Constraints**: Audio tap callback runs on a high-priority audio thread — no heap allocations, no main-thread blocking. UI updates dispatched to main thread. Indicator footprint stays within 50% of current 150×28pt size.  
**Scale/Scope**: Single-user desktop app, single indicator view

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle                        | Status        | Notes                                                                                                                                                                            |
| -------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. User-Controlled Processing    | **Pass**      | Waveform is local-only visual feedback. No audio data leaves the device for this feature.                                                                                        |
| II. Type Safety & Correctness    | **Pass**      | Audio level values use explicit `Float` types. No force-unwraps needed. Callback closures use `@Sendable` annotations consistent with existing `onAudioChunk`.                   |
| III. Test-First Development      | **Pass**      | Audio level extraction testable with mock `AVAudioPCMBuffer` data. View state transitions testable via existing `IndicatorState` enum.                                           |
| IV. Performance-Conscious Design | **Attention** | RMS calculation in the audio tap callback must use pointer-based math with zero allocations. Level values passed to main thread via a lightweight callback — no buffer copying.   |
| V. Simplicity & YAGNI           | **Pass**      | Single-purpose: extract level, render bars. No frequency analysis, no spectrogram, no configurable bar count. Fixed design.                                                      |

**Gate result**: Pass — no violations. Performance principle requires care during implementation (documented in constraints).

## Project Structure

### Documentation (this feature)

```text
specs/009-recording-waveform/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Wisp/
├── Services/
│   └── AudioCaptureService.swift     # Add: RMS level extraction in tap callback, onAudioLevel callback
├── UI/
│   ├── StatusIndicatorView.swift     # Add: WaveformBarsView, integrate into recording state layout
│   └── StatusOverlayWindow.swift     # Modify: resize window for waveform, pass audio levels through
├── Models/
│   └── IndicatorState.swift          # No changes needed — .recording state already exists
└── App/
    └── AppDelegate.swift             # Add: wire onAudioLevel callback to indicator view during recording

WispTests/
├── AudioLevelExtractionTests.swift   # New: test RMS calculation from mock PCM buffers
└── StatusIndicatorViewTests.swift    # New/extend: test waveform visibility per indicator state
```

**Structure Decision**: All changes fit within the existing single-project structure. No new directories needed. Two new test files for the two new behaviors (level extraction and waveform rendering).

## Complexity Tracking

> No constitution violations — table not needed.
