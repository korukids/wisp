# wisp Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-10

## Active Technologies
- Swift 6.2 with strict concurrency checking + AppKit (NSPanel, Core Animation), WhisperKit (existing) (002-status-indicator-gui)
- Swift 6.2 with strict concurrency checking enabled + WhisperKit (existing), KeyboardShortcuts 2.x (Sindre Sorhus — re-add to Package.swift), AVFoundation (existing), CoreAudio (system framework), Apple FoundationModels (existing), AppKit + SwiftUI (003-config-screen)
- UserDefaults — two explicit keys (`selectedMicrophoneUID`, `cleanupPrompt`); hotkey managed automatically by KeyboardShortcuts library (003-config-screen)
- Swift 6.1+ with strict concurrency checking enabled + AppKit (NSWindow, NSMenu), SwiftUI (List, Button), Foundation (Codable, JSONEncoder/Decoder, FileManager) (004-transcription-log)
- JSON file — `~/Library/Application Support/Wisp/transcription-log.json` (004-transcription-log)
- Swift 6.1+ with strict concurrency checking enabled + AppKit (NSPanel, Core Animation), WhisperKit (existing), AVFoundation (existing) (005-escape-cancel-countdown)
- JSON file at `~/Library/Application Support/Wisp/transcription-log.json` (existing) (005-escape-cancel-countdown)
- Swift 6.1+ with strict concurrency checking enabled + AppKit (NSSound, NSStatusItem, NSMenu), ServiceManagement (SMAppService), AVFoundation (existing) (006-polish-and-cleanup)
- UserDefaults (startup preference, keyed on existing PreferencesStore) (006-polish-and-cleanup)
- Swift 6.1+ with strict concurrency checking enabled + WhisperKit (existing), FoundationModels (existing), AppKit + SwiftUI (existing), KeyboardShortcuts (existing) (007-custom-word-dictionary)
- UserDefaults (`com.wisp.wordDictionary` → `[String]`) (007-custom-word-dictionary)
- Swift 6.2 with strict concurrency checking + KeyboardShortcuts 2.x (existing), URLSessionWebSocketTask (system framework), AVFoundation (existing) (008-elevenlabs-speech-to-text)
- UserDefaults (existing preferences, word dictionary), `.env` file (API key) (008-elevenlabs-speech-to-text)
- Swift 6.1+ with strict concurrency checking enabled + AVFoundation (existing audio capture), AppKit (existing indicator UI), Core Animation (bar rendering) (009-recording-waveform)
- N/A — waveform is ephemeral visual state only (009-recording-waveform)

- Swift 5.9+ with strict concurrency checking + WhisperKit (Argmax), KeyboardShortcuts (Sindre Sorhus), AppKi (001-core-dictation-flow)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 5.9+ with strict concurrency checking

## Code Style

Swift 5.9+ with strict concurrency checking: Follow standard conventions

## Recent Changes
- 009-recording-waveform: Added Swift 6.1+ with strict concurrency checking enabled + AVFoundation (existing audio capture), AppKit (existing indicator UI), Core Animation (bar rendering)
- 008-elevenlabs-speech-to-text: Added Swift 6.2 with strict concurrency checking + KeyboardShortcuts 2.x (existing), URLSessionWebSocketTask (system framework), AVFoundation (existing)
- 007-custom-word-dictionary: Added Swift 6.1+ with strict concurrency checking enabled + WhisperKit (existing), FoundationModels (existing), AppKit + SwiftUI (existing), KeyboardShortcuts (existing)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
