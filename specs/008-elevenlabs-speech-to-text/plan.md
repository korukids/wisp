# Implementation Plan: ElevenLabs Speech-to-Text

**Branch**: `008-elevenlabs-speech-to-text` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-elevenlabs-speech-to-text/spec.md`

## Summary

Replace the local WhisperKit transcription backend with ElevenLabs' Realtime Speech-to-Text WebSocket API. Audio is streamed to the cloud during recording so the transcript is available near-instantly when the user stops. The existing text cleanup pipeline, word dictionary, paste flow, and UI remain unchanged.

## Technical Context

**Language/Version**: Swift 6.2 with strict concurrency checking  
**Primary Dependencies**: KeyboardShortcuts 2.x (existing), URLSessionWebSocketTask (system framework), AVFoundation (existing)  
**Removed Dependencies**: WhisperKit (Argmax) — fully removed from Package.swift  
**Storage**: UserDefaults (existing preferences, word dictionary), `.env` file (API key)  
**Testing**: XCTest  
**Target Platform**: macOS 26+, Apple Silicon and Intel  
**Project Type**: Desktop app (menu bar utility)  
**Performance Goals**: Transcript available <1 second after user stops recording  
**Constraints**: Requires internet connection; API key must not be logged or displayed  
**Scale/Scope**: Single user, single concurrent session

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. User-Controlled Processing | Pass | Cloud transcription enabled by explicit API key configuration. No telemetry. Constitution amended v2.0.0. |
| II. Type Safety & Correctness | Pass | All WebSocket message types modeled as Codable structs. No force-unwraps. |
| III. Test-First Development | Pass | Tests planned for WebSocket message parsing, chunk encoding, error handling, and integration flow. |
| IV. Performance-Conscious Design | Pass | Audio capture remains on dedicated thread. Streaming eliminates post-stop transcription delay. <50MB idle memory (WhisperKit removal helps). |
| V. Simplicity & YAGNI | Pass | No fallback mechanism, no provider abstraction. Single backend replacement. |

**Post-Phase 1 Re-check**: All gates still pass. No new abstractions introduced beyond what the feature requires.

## Project Structure

### Documentation (this feature)

```text
specs/008-elevenlabs-speech-to-text/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
Wisp/
├── App/
│   ├── WispApp.swift                    # Entry point (unchanged)
│   └── AppDelegate.swift                # MODIFIED: rewire for streaming, remove model preload
├── Models/
│   ├── AppState.swift                   # MODIFIED: remove .loading state
│   ├── IndicatorState.swift             # MODIFIED: remove .modelLoading
│   ├── PreferencesStore.swift           # Unchanged
│   ├── WordDictionaryStore.swift        # Unchanged
│   ├── TranscriptionLogStore.swift      # Unchanged
│   └── TranscriptionLogEntry.swift      # Unchanged
├── Services/
│   ├── AudioCaptureService.swift        # MODIFIED: add onAudioChunk callback
│   ├── TranscriptionService.swift       # REWRITTEN: ElevenLabs WebSocket streaming
│   ├── EnvLoader.swift                  # NEW: read .env file
│   ├── TextCleanupService.swift         # Unchanged
│   ├── PasteService.swift               # Unchanged
│   ├── HotkeyService.swift              # Unchanged
│   └── NotificationService.swift        # Unchanged
├── UI/
│   ├── StatusIndicatorView.swift        # MODIFIED: remove model loading indicator
│   ├── StatusOverlayWindow.swift        # Unchanged
│   ├── MenuBarController.swift          # MODIFIED: remove model loading icon state
│   ├── PreferencesView.swift            # Unchanged
│   └── LogView.swift                    # Unchanged
└── Resources/
    └── (audio files, unchanged)

Package.swift                            # MODIFIED: remove WhisperKit dependency
.env                                     # Existing: ELEVENLABS_API_KEY
.gitignore                               # Verify .env is listed
```

**Structure Decision**: No new directories. New files are `EnvLoader.swift` (service) and the rewritten `TranscriptionService.swift`. All changes fit the existing single-project layout.

## File Change Summary

### New Files
| File | Purpose |
|------|---------|
| `Wisp/Services/EnvLoader.swift` | Parse `.env` file, return key-value pairs |

### Rewritten Files
| File | Purpose |
|------|---------|
| `Wisp/Services/TranscriptionService.swift` | ElevenLabs WebSocket streaming transcription (replaces WhisperKit wrapper) |

### Modified Files
| File | Change |
|------|--------|
| `Package.swift` | Remove WhisperKit dependency |
| `Wisp/Services/AudioCaptureService.swift` | Add `onAudioChunk: ((Data) -> Void)?` callback in tap handler |
| `Wisp/App/AppDelegate.swift` | Remove model preloading; wire streaming flow; open/close WebSocket per session; handle streaming errors |
| `Wisp/Models/AppState.swift` | Remove `.loading` state and its transitions |
| `Wisp/Models/IndicatorState.swift` | Remove `.modelLoading` case |
| `Wisp/UI/StatusIndicatorView.swift` | Remove model loading visual state |
| `Wisp/UI/MenuBarController.swift` | Remove hourglass icon for loading state |

### Unchanged Files
| File | Why Unchanged |
|------|---------------|
| `TextCleanupService.swift` | Receives plain text regardless of transcription backend |
| `PasteService.swift` | Receives cleaned text regardless of source |
| `WordDictionaryStore.swift` | Dictionary logic is backend-agnostic |
| `PreferencesStore.swift` | No new preferences needed (API key is in .env, not UserDefaults) |
| `HotkeyService.swift` | Hotkey behavior unchanged |
| `PreferencesView.swift` | No new UI settings needed |
| `LogView.swift` | Log entries unchanged |
| `TranscriptionLogStore.swift` | Storage format unchanged |

## Key Design Decisions

### 1. WebSocket Per Session (not persistent)
Open a new WebSocket when recording starts, close after committed transcript received. Avoids reconnection logic and session timeout management. ~100ms connection overhead masked by start beep.

### 2. Manual Commit Strategy
Use `commit_strategy: "manual"` so we control exactly when the final transcript is produced — when the user presses the stop hotkey. Send `commit: true` on the final audio chunk.

### 3. Chunk Callback on AudioCaptureService
Add `onAudioChunk: ((Data) -> Void)?` property. The existing tap callback calls this with each PCM buffer in addition to appending to the accumulated buffer. Minimal change, preserves existing cancel-flow buffer semantics.

### 4. No Provider Abstraction
`TranscriptionService` is rewritten directly for ElevenLabs — no protocol, no strategy pattern. YAGNI: there's one backend, and the previous one is being removed. If a second backend is needed later, extract a protocol then.

### 5. Word Dictionary as previous_text
Pass dictionary words as the `previous_text` field on the first audio chunk. This primes the transcription model with expected vocabulary. Combined with the existing TextCleanupService post-processing, this provides two layers of dictionary correction.

## Complexity Tracking

No constitution violations. No complexity justifications needed.
