@preconcurrency import AVFoundation
import CoreAudio
import Foundation

final class AudioCaptureService: @unchecked Sendable {

    enum AutoStopResult: Sendable {
        case maxDurationReached(buffer: Data)
    }

    static let targetSampleRate: Double = 16000
    static let maxDurationSeconds: TimeInterval = 300 // 5 minutes
    static let minimumDurationSeconds: TimeInterval = 0.5

    /// Optional CoreAudio device UID to use as the input device.
    /// When nil the system default input device is used.
    var preferredDeviceUID: String?

    /// Called with each audio chunk as it arrives from the tap, for real-time streaming.
    var onAudioChunk: (@Sendable (Data) -> Void)?

    private let lock = NSLock()
    private var audioEngine: AVAudioEngine?
    private var audioBuffer = Data()
    private var maxDurationTimer: Timer?
    private var autoStopHandler: (@Sendable (AutoStopResult) -> Void)?
    private var isRecording = false

    var currentBufferDuration: TimeInterval {
        lock.lock()
        let count = audioBuffer.count
        lock.unlock()
        return Double(count) / (AudioCaptureService.targetSampleRate * 4)
    }

    func startRecording(autoStopHandler: @Sendable @escaping (AutoStopResult) -> Void) {
        lock.lock()
        guard !isRecording else {
            lock.unlock()
            return
        }
        self.autoStopHandler = autoStopHandler
        audioBuffer = Data()
        isRecording = true
        lock.unlock()

        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Switch to the preferred input device if one is configured
        if let uid = preferredDeviceUID {
            Self.setInputDevice(uid: uid, on: engine)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioCaptureService.targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }

            self.lock.lock()
            guard self.isRecording else {
                self.lock.unlock()
                return
            }
            self.lock.unlock()

            if let converter {
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * AudioCaptureService.targetSampleRate
                        / inputFormat.sampleRate
                )
                guard frameCapacity > 0 else { return }
                guard
                    let convertedBuffer = AVAudioPCMBuffer(
                        pcmFormat: targetFormat, frameCapacity: frameCapacity)
                else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) {
                    _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                if status == .haveData, let channelData = convertedBuffer.floatChannelData {
                    let data = Data(
                        bytes: channelData[0],
                        count: Int(convertedBuffer.frameLength) * MemoryLayout<Float>.size
                    )
                    self.lock.lock()
                    self.audioBuffer.append(data)
                    let chunkHandler = self.onAudioChunk
                    self.lock.unlock()
                    chunkHandler?(data)
                }
            } else if let channelData = buffer.floatChannelData {
                let data = Data(
                    bytes: channelData[0],
                    count: Int(buffer.frameLength) * MemoryLayout<Float>.size
                )
                self.lock.lock()
                self.audioBuffer.append(data)
                let chunkHandler = self.onAudioChunk
                self.lock.unlock()
                chunkHandler?(data)
            }
        }

        do {
            try engine.start()
        } catch {
            lock.lock()
            isRecording = false
            lock.unlock()
            return
        }

        // 5-minute auto-stop timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.maxDurationTimer = Timer.scheduledTimer(
                withTimeInterval: AudioCaptureService.maxDurationSeconds, repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                let buffer = self.stopRecordingInternal()
                self.autoStopHandler?(.maxDurationReached(buffer: buffer))
            }
        }
    }

    func stopRecording() -> Data? {
        lock.lock()
        guard isRecording else {
            lock.unlock()
            return nil
        }
        lock.unlock()
        return stopRecordingInternal()
    }

    // MARK: - CoreAudio Device Selection

    private static func setInputDevice(uid: String, on engine: AVAudioEngine) {
        guard let deviceID = resolveDeviceID(forUID: uid) else {
            print("[Wisp] AudioCaptureService: device UID '\(uid)' not found, using system default")
            return
        }
        guard let audioUnit = engine.inputNode.audioUnit else {
            print("[Wisp] AudioCaptureService: inputNode has no AudioUnit")
            return
        }
        var id = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("[Wisp] AudioCaptureService: failed to set input device (status \(status))")
        }
    }

    private static func resolveDeviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let cfUID = uid as CFString
        let status = withUnsafePointer(to: cfUID) { qualifierPtr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                qualifierPtr,
                &size,
                &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func stopRecordingInternal() -> Data {
        DispatchQueue.main.async { [weak self] in
            self?.maxDurationTimer?.invalidate()
            self?.maxDurationTimer = nil
        }

        lock.lock()
        isRecording = false
        let captured = audioBuffer
        audioBuffer = Data()
        lock.unlock()

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        return captured
    }
}
