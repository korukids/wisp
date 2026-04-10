# Quickstart: ElevenLabs Speech-to-Text Integration

**Feature**: 008-elevenlabs-speech-to-text  
**Date**: 2026-04-10

## Prerequisites

1. ElevenLabs API key in `.env` file at project root:
   ```
   ELEVENLABS_API_KEY=sk_your_key_here
   ```
2. macOS 26+ with Xcode and Swift 6.2+
3. Working internet connection for cloud transcription

## Build & Run

```bash
swift build
swift run Wisp
```

No model download step required (WhisperKit removed).

## Key Changes from Previous Architecture

| Before (WhisperKit) | After (ElevenLabs) |
|---------------------|-------------------|
| Audio buffered entirely, then transcribed locally after stop | Audio streamed to cloud in real-time during recording |
| ~500MB model download on first run | No model download; API key required |
| Multi-second transcription delay after stop | <1 second delay after stop (audio already processed) |
| `.loading` state at startup for model preload | App starts directly in `.idle` |
| Fully offline | Requires internet connection |

## Testing the Flow

1. Launch the app (appears in menu bar as ghost icon)
2. Press Option+Space to start recording
3. Speak a sentence
4. Press Option+Space to stop
5. Transcribed text should be pasted within ~1 second

## Error Scenarios to Verify

- Remove `.env` file → app shows error about missing API key
- Disconnect network during recording → error notification, partial transcript preserved
- Record silence → no crash, appropriate handling
- Record < 0.5 seconds → "too short" notification (unchanged behavior)

## Architecture Overview

```
[Hotkey Press]
    ↓
[AudioCaptureService.startRecording()]  ←→  [onAudioChunk callback]
    ↓                                              ↓
[AVAudioEngine tap: 16kHz PCM chunks]    [ElevenLabsTranscriptionService]
    ↓                                              ↓
[Buffer accumulation (for cancel flow)]  [WebSocket: base64 chunks → API]
                                                   ↓
                                         [partial_transcript messages]
                                                   ↓
[Hotkey Press / Stop]  →  [commit: true on final chunk]
                                                   ↓
                                         [committed_transcript message]
                                                   ↓
                                         [TextCleanupService.cleanup()]
                                                   ↓
                                         [PasteService.paste()]
```
