import XCTest
@testable import Wisp

final class AudioLevelExtractionTests: XCTestCase {

    // MARK: - T002: RMS Level Extraction

    func testSilenceProducesMinimumLevels() {
        // All-zero samples should produce 5 values all at 0.0
        let samples = [Float](repeating: 0.0, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        XCTAssertEqual(levels.count, 5)
        for level in levels {
            XCTAssertEqual(level, 0.0, accuracy: 0.001, "Silence should map to 0.0")
        }
    }

    func testLoudInputProducesHighLevels() {
        // Full-scale samples (amplitude 1.0) should produce values near 1.0
        let samples = [Float](repeating: 1.0, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        XCTAssertEqual(levels.count, 5)
        for level in levels {
            XCTAssertGreaterThan(level, 0.9, "Full-scale input should map near 1.0")
            XCTAssertLessThanOrEqual(level, 1.0, "Levels must be clamped to 1.0")
        }
    }

    func testQuietSpeechProducesMidRangeLevels() {
        // Low-amplitude samples (simulating quiet speech ~0.01 amplitude)
        let samples = [Float](repeating: 0.01, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        XCTAssertEqual(levels.count, 5)
        for level in levels {
            XCTAssertGreaterThan(level, 0.0, "Quiet speech should be above silence")
            XCTAssertLessThan(level, 0.8, "Quiet speech should not be near maximum")
        }
    }

    func testOutputAlwaysHasFiveBars() {
        // Various buffer sizes should always produce exactly 5 values
        for frameCount in [5, 100, 4096, 8000] {
            let samples = [Float](repeating: 0.5, count: frameCount)
            let levels = samples.withUnsafeBufferPointer { buf in
                AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: frameCount)
            }
            XCTAssertEqual(levels.count, 5, "Should always produce 5 bars for frameCount \(frameCount)")
        }
    }

    func testOutputValuesAreInUnitRange() {
        // Mixed signal — all output values must be in [0.0, 1.0]
        var samples = [Float](repeating: 0.0, count: 500)
        for i in stride(from: 0, to: 500, by: 2) {
            samples[i] = 0.8
        }
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        for level in levels {
            XCTAssertGreaterThanOrEqual(level, 0.0, "Level must not be negative")
            XCTAssertLessThanOrEqual(level, 1.0, "Level must not exceed 1.0")
        }
    }

    func testVaryingSegmentsProduceDifferentLevels() {
        // Construct a buffer where segments have different amplitudes
        var samples = [Float](repeating: 0.0, count: 500)
        // Segment 0 (0-99): silence
        // Segment 1 (100-199): quiet
        for i in 100..<200 { samples[i] = 0.01 }
        // Segment 2 (200-299): medium
        for i in 200..<300 { samples[i] = 0.1 }
        // Segment 3 (300-399): loud
        for i in 300..<400 { samples[i] = 0.5 }
        // Segment 4 (400-499): very loud
        for i in 400..<500 { samples[i] = 1.0 }

        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }

        // Each successive segment should be louder
        XCTAssertLessThan(levels[0], levels[1], "Silence < quiet")
        XCTAssertLessThan(levels[1], levels[2], "Quiet < medium")
        XCTAssertLessThan(levels[2], levels[3], "Medium < loud")
        XCTAssertLessThan(levels[3], levels[4], "Loud < very loud")
    }

    // MARK: - T003: Logarithmic Normalization

    func testDecibelFloorMapsToZero() {
        // Very quiet signal (close to silence) should map to 0.0
        // At -50 dB, RMS amplitude is ~0.00316
        let amplitude: Float = 0.000001  // well below -50 dB
        let samples = [Float](repeating: amplitude, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        for level in levels {
            XCTAssertEqual(level, 0.0, accuracy: 0.001, "Below dB floor should clamp to 0.0")
        }
    }

    func testDecibelCeilingMapsToOne() {
        // Full-scale signal should map to 1.0
        // At -6 dB, RMS amplitude is ~0.5; at 0 dB, amplitude is 1.0
        let samples = [Float](repeating: 1.0, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        for level in levels {
            XCTAssertEqual(level, 1.0, accuracy: 0.001, "Full-scale should clamp to 1.0")
        }
    }

    func testClampingBelowFloor() {
        // Pure silence (exactly 0.0 RMS) must produce 0.0, not negative infinity
        let samples = [Float](repeating: 0.0, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        for level in levels {
            XCTAssertGreaterThanOrEqual(level, 0.0, "Must not produce negative values from silence")
        }
    }

    func testClampingAboveCeiling() {
        // Values that would exceed 1.0 after normalization must be clamped
        // Using amplitude > 0.5 (which is above -6 dB ceiling)
        let samples = [Float](repeating: 2.0, count: 500)
        let levels = samples.withUnsafeBufferPointer { buf in
            AudioCaptureService.computeAudioLevels(from: buf.baseAddress!, frameCount: 500)
        }
        for level in levels {
            XCTAssertLessThanOrEqual(level, 1.0, "Must clamp to 1.0 for signals above ceiling")
        }
    }
}
