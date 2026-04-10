# Research: Recording Waveform Indicator

**Branch**: `009-recording-waveform` | **Date**: 2026-04-10

## R1: Audio Level Extraction from AVAudioEngine Tap

**Decision**: Calculate RMS (root mean square) amplitude from the float32 PCM samples already available in the tap callback, segmented into N slices per buffer to provide per-bar level values.

**Rationale**: The existing tap callback at `AudioCaptureService.swift:66` receives `AVAudioPCMBuffer` with `floatChannelData` — raw float32 samples at 16kHz mono. RMS is the standard measure for perceived loudness. By splitting the buffer into segments (one per bar), each bar gets a naturally varying level from a single audio chunk, creating the multi-bar equalizer look without artificial randomization.

**Alternatives considered**:
- **Peak amplitude**: Simpler but spiky — poor visual result for smooth bars
- **vDSP/Accelerate framework vectorized RMS**: Optimal for performance but adds framework dependency for a small buffer (~4096 samples). Manual pointer-based RMS is sufficient at this scale and avoids the import.
- **FFT frequency bands**: Would give true frequency-based bars but is excessive for a 7×28pt indicator. Rejected per constitution principle V (YAGNI).

## R2: Waveform Update Rate and Animation Strategy

**Decision**: Use the existing tap callback cadence (~4 updates/second at 4096 frames / 16kHz) as the data source, with Core Animation interpolation to smooth bar height transitions between updates.

**Rationale**: The tap fires approximately every 256ms. At 4 updates/second, directly setting bar heights would look jerky. By using `CABasicAnimation` with ~200ms duration on each bar's height property, transitions appear smooth (effectively 30+ fps perceived) without increasing tap frequency or adding a separate display link timer.

**Alternatives considered**:
- **CADisplayLink / timer-based rendering**: Smooth but adds complexity and CPU cost for a tiny UI element. The audio tap cadence + animation interpolation achieves the same perceived smoothness.
- **Smaller buffer size (1024 frames)**: Would increase update rate to ~16/sec but changes the audio pipeline behavior for all consumers (transcription service). Too invasive.
- **SwiftUI + Combine**: Would require rewriting the indicator in SwiftUI. The existing view is AppKit with Core Animation — stay consistent.

## R3: Bar Count and Layout Integration

**Decision**: 5 vertical bars positioned to the right of the red dot, replacing the "Recording..." text label. Bars are evenly spaced within a fixed-width container.

**Rationale**: 5 bars fit comfortably in the space currently occupied by the "Recording..." text (~80pt wide). Each bar is narrow (3-4pt wide) with 2-3pt spacing. The red dot (7×7) remains as the leftmost element, providing the color anchor. This matches the clarified spec: "keep red dot, drop text, bars replace text."

**Alternatives considered**:
- **3 bars**: Too few — looks like a static icon rather than a live visualization
- **7+ bars**: Too dense for the 28pt-tall indicator at this scale
- **Bars to the left of the dot**: Breaks the existing visual hierarchy (dot is the leading element)

## R4: Level Normalization and Visual Mapping

**Decision**: Apply logarithmic scaling (decibel conversion) to RMS values before mapping to bar heights. Clamp output to 0.0–1.0 range representing minimum to maximum bar height.

**Rationale**: Raw RMS values have a wide dynamic range where quiet speech barely registers. Logarithmic scaling (20 * log10(rms)) compresses this range to match human loudness perception. A floor threshold (e.g., -50 dB) maps to minimum bar height; values above -6 dB map to maximum. This ensures quiet speech produces visible bar movement (FR-008) while loud input is capped (FR-007).

**Alternatives considered**:
- **Linear scaling**: Quiet speech would be nearly invisible; loud input would dominate. Poor user experience.
- **Automatic gain control (AGC)**: Normalizes levels over time but adds latency and complexity. The waveform should reflect actual input levels, not normalized ones.

## R5: Thread Safety for Level Data

**Decision**: Follow the existing `onAudioChunk` pattern — add an `onAudioLevels: (@Sendable ([Float]) -> Void)?` callback on `AudioCaptureService`. Capture the handler reference inside the lock, call it outside the lock. Marshal to main thread in the caller (AppDelegate).

**Rationale**: This is the exact pattern used for `onAudioChunk` at lines 101-103 of `AudioCaptureService.swift`. Consistency reduces cognitive load and bug risk. The `@Sendable` annotation satisfies Swift strict concurrency checking. Main thread dispatch happens in AppDelegate, keeping the service layer thread-agnostic.

**Alternatives considered**:
- **Dispatch to main thread inside AudioCaptureService**: Violates single responsibility — the service shouldn't know about UI threading.
- **Shared atomic/lock-protected level buffer**: More complex and unnecessary when a callback pattern already exists.
