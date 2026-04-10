import AppKit
@preconcurrency import AVFoundation
@preconcurrency import ApplicationServices
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private var state: AppState = .idle
    private var currentSession: DictationSession?

    private var preferencesStore: PreferencesStore?
    private var wordDictionary = WordDictionaryStore()
    private var microphoneList: MicrophoneList?
    private var hotkeyService: HotkeyService?
    private var audioCaptureService: AudioCaptureService?
    private var transcriptionService: TranscriptionService?
    private var textCleanupService: TextCleanupService?
    private var pasteService: PasteService?
    private var menuBarController: MenuBarController?
    private var notificationService: NotificationService?
    private var overlayWindow: StatusOverlayWindow?
    private var logStore = TranscriptionLogStore()
    private var logWindow: LogWindow?
    private var escapeMonitor: Any?
    private var launchOnStartupItem: NSMenuItem?

    // Cancel-countdown state
    private var shouldPasteAfterProcessing = false
    private var cancelCountdownTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let store = PreferencesStore()
        // Reconcile stored preference with actual system state (handles manual System Settings changes)
        store.syncLaunchOnStartup(SMAppService.mainApp.status == .enabled)
        preferencesStore = store
        microphoneList = MicrophoneList()
        setupMenuBar()
        setupOverlay()
        requestPermissions()
        setupServices(preferences: store)
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        menuBarController = MenuBarController(statusItem: statusItem!)
        menuBarController?.updateState(.idle)

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(
            NSMenuItem(
                title: "Preferences\u{2026}",
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Show Log",
                action: #selector(showLog),
                keyEquivalent: ""
            )
        )

        let startupItem = NSMenuItem(
            title: "Launch on Startup",
            action: #selector(toggleLaunchOnStartup),
            keyEquivalent: ""
        )
        startupItem.state = (preferencesStore?.launchOnStartup ?? false) ? .on : .off
        launchOnStartupItem = startupItem
        menu.addItem(startupItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Wisp",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: ""
            )
        )
        statusItem?.menu = menu
    }

    @objc private func showLog() {
        if logWindow == nil {
            logWindow = LogWindow()
        }
        logWindow?.show(logStore: logStore, wordDictionary: wordDictionary)
    }

    @objc private func openPreferences() {
        guard let store = preferencesStore, let mics = microphoneList else { return }
        PreferencesWindow.show(preferences: store, microphoneList: mics, wordDictionary: wordDictionary)
    }

    @objc private func toggleLaunchOnStartup() {
        guard let store = preferencesStore else { return }
        do {
            try store.setLaunchOnStartup(!store.launchOnStartup)
            launchOnStartupItem?.state = store.launchOnStartup ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could Not Update Login Item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        let isEnabled = SMAppService.mainApp.status == .enabled
        preferencesStore?.syncLaunchOnStartup(isEnabled)
        launchOnStartupItem?.state = isEnabled ? .on : .off
    }

    private func setupOverlay() {
        overlayWindow = StatusOverlayWindow()
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async { [weak self] in
                    self?.notificationService?.show(
                        title: "Microphone Access Required",
                        message: "Wisp needs microphone access to record dictation. "
                            + "Enable it in System Settings > Privacy & Security > Microphone."
                    )
                }
            }
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            notificationService?.show(
                title: "Accessibility Access Required",
                message: "Wisp needs Accessibility access to paste text into other apps. "
                    + "Enable it in System Settings > Privacy & Security > Accessibility."
            )
        }
    }

    private func setupServices(preferences: PreferencesStore) {
        notificationService = NotificationService()
        pasteService = PasteService()

        let capture = AudioCaptureService()
        capture.preferredDeviceUID = preferences.selectedMicrophoneUID
        audioCaptureService = capture

        textCleanupService = TextCleanupService(preferences: preferences)
        transcriptionService = TranscriptionService()

        // Migrate .env API key to Keychain if not already stored
        if preferences.apiKey == nil {
            let env = EnvLoader.load()
            if let key = env["ELEVENLABS_API_KEY"], !key.isEmpty {
                preferences.setApiKey(key)
                print("[Wisp] API key migrated from .env to Keychain")
            }
        }
        if preferences.apiKey != nil {
            print("[Wisp] API key loaded — ready to dictate")
        } else {
            print("[Wisp] WARNING: No API key configured")
            overlayWindow?.show(state: .error("API key missing — set it in Preferences"))
        }

        hotkeyService = HotkeyService { [weak self] in
            self?.handleHotkeyToggle()
        }
        hotkeyService?.register()

        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // 53 = Escape
            Task { @MainActor [weak self] in
                self?.handleEscapeKey()
            }
        }
    }

    // MARK: - Dictation Flow

    private func handleEscapeKey() {
        if state == .recording {
            beginCancelCountdown()
        } else if state == .cancelling {
            restoreFromCancelling()
        }
    }

    private func beginCancelCountdown() {
        currentSession?.stop()
        guard let session = currentSession else {
            print("[Wisp] No active session to cancel")
            return
        }

        menuBarController?.playStopSound()

        if session.audioDuration < 0.5 {
            print("[Wisp] Recording too short, discarding without countdown")
            _ = audioCaptureService?.stopRecording()
            audioCaptureService?.onAudioChunk = nil
            transcriptionService?.cancel()
            handleResult(.discarded(reason: .tooShort))
            return
        }

        _ = audioCaptureService?.stopRecording()
        audioCaptureService?.onAudioChunk = nil

        guard case .success(let newState) = state.transition(to: .cancelling) else {
            print("[Wisp] State transition to cancelling failed")
            return
        }

        print("[Wisp] Starting cancel countdown")
        state = newState
        menuBarController?.updateState(state)
        overlayWindow?.show(state: .cancelling)

        shouldPasteAfterProcessing = false

        cancelCountdownTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            await MainActor.run { [weak self] in
                self?.commitCancelledTranscription()
            }
        }
    }

    private func commitCancelledTranscription() {
        guard state == .cancelling else { return }
        guard case .success(let newState) = state.transition(to: .processing) else { return }

        print("[Wisp] Cancel countdown expired — transcribing silently without paste")
        overlayWindow?.hide()
        state = newState

        cancelCountdownTask = nil

        Task {
            await commitAndSave()
        }
    }

    private func restoreFromCancelling() {
        cancelCountdownTask?.cancel()
        cancelCountdownTask = nil

        guard case .success(let newState) = state.transition(to: .processing) else {
            print("[Wisp] State transition from cancelling to processing failed")
            return
        }

        print("[Wisp] Cancel reversed via second Escape — will transcribe and paste")
        shouldPasteAfterProcessing = true
        state = newState
        menuBarController?.updateState(state)
        overlayWindow?.show(state: .transcribing)

        Task {
            await commitAndPaste()
        }
    }

    private func handleHotkeyToggle() {
        print("[Wisp] handleHotkeyToggle, state: \(state)")
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecordingAndTranscribe()
        case .cancelling:
            print("[Wisp] Ignoring hotkey during cancel countdown")
        case .processing:
            print("[Wisp] Ignoring hotkey during processing")
        }
    }

    private func startRecording() {
        guard let apiKey = preferencesStore?.apiKey, !apiKey.isEmpty else {
            overlayWindow?.show(state: .error("API key missing — set it in Preferences"))
            return
        }

        guard case .success(let newState) = state.transition(to: .recording) else {
            print("[Wisp] State transition to recording failed")
            return
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("[Wisp] Mic authorization status: \(micStatus.rawValue)")
        guard micStatus == .authorized else {
            print("[Wisp] Mic not authorized")
            notificationService?.show(
                title: "Microphone Unavailable",
                message: "Wisp cannot access the microphone. Check System Settings."
            )
            return
        }

        audioCaptureService?.preferredDeviceUID = preferencesStore?.selectedMicrophoneUID

        state = newState
        print("[Wisp] Recording started")
        menuBarController?.updateState(state)
        overlayWindow?.show(state: .recording)
        currentSession = DictationSession()

        let hints = wordDictionary.words
        let service = transcriptionService

        // Start audio capture and WebSocket connection immediately;
        // play the beep in parallel so we don't lose the start of speech.
        menuBarController?.playStartSound(completion: {})

        self.audioCaptureService?.onAudioChunk = { data in
            service?.sendAudioChunk(data)
        }
        self.audioCaptureService?.startRecording { [weak self] result in
            DispatchQueue.main.async {
                self?.handleAutoStop(result: result)
            }
        }

        Task { @MainActor [weak self] in
            guard let self, self.state == .recording else { return }
            do {
                print("[Wisp] Connecting WebSocket...")
                try await service?.startSession(apiKey: apiKey, wordHints: hints)
                print("[Wisp] WebSocket connected")
            } catch {
                print("[Wisp] WebSocket connection failed: \(error)")
                _ = self.audioCaptureService?.stopRecording()
                self.overlayWindow?.show(
                    state: .error("Transcription unavailable — check internet connection"))
                self.currentSession = nil
                self.state = .idle
                self.menuBarController?.updateState(.idle)
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard case .success(let newState) = state.transition(to: .processing) else {
            print("[Wisp] State transition to processing failed")
            return
        }

        print("[Wisp] Stopping recording...")
        menuBarController?.playStopSound()
        state = newState
        menuBarController?.updateState(state)
        overlayWindow?.show(state: .transcribing)

        currentSession?.stop()
        guard let session = currentSession else {
            print("[Wisp] No active session")
            return
        }

        print("[Wisp] Session duration: \(session.audioDuration)s")

        if session.audioDuration < 0.5 {
            print("[Wisp] Recording too short, discarding")
            _ = audioCaptureService?.stopRecording()
            audioCaptureService?.onAudioChunk = nil
            transcriptionService?.cancel()
            handleResult(.discarded(reason: .tooShort))
            return
        }

        _ = audioCaptureService?.stopRecording()
        audioCaptureService?.onAudioChunk = nil

        Task {
            await commitAndPaste()
        }
    }

    private func handleAutoStop(result: AudioCaptureService.AutoStopResult) {
        guard state == .recording else { return }
        switch result {
        case .maxDurationReached:
            guard case .success(let newState) = state.transition(to: .processing) else {
                return
            }
            menuBarController?.playStopSound()
            state = newState
            menuBarController?.updateState(state)
            overlayWindow?.show(state: .transcribing)
            currentSession?.stop()
            audioCaptureService?.onAudioChunk = nil
            notificationService?.show(
                title: "Maximum Duration Reached",
                message: "Recording stopped after 5 minutes."
            )
            Task {
                await commitAndPaste()
            }
        }
    }

    private func commitAndPaste() async {
        do {
            print("[Wisp] Committing transcript...")
            let rawText = try await transcriptionService?.commitAndGetTranscript()
            print("[Wisp] Raw transcription: \(rawText ?? "<nil>")")
            guard let rawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                print("[Wisp] No speech detected, discarding")
                await MainActor.run { handleResult(.discarded(reason: .noSpeechDetected)) }
                return
            }
            print("[Wisp] Cleaning up text...")
            let hints = await MainActor.run { wordDictionary.words }
            let cleanedText: String
            if let service = textCleanupService {
                cleanedText = (try? await service.cleanup(rawText, wordHints: hints)) ?? rawText
            } else {
                cleanedText = rawText
            }
            print("[Wisp] Cleaned text: \(cleanedText)")

            await MainActor.run {
                shouldPasteAfterProcessing = true
                pasteService?.paste(text: cleanedText) { [weak self] fallbackToClipboard in
                    if fallbackToClipboard {
                        self?.notificationService?.show(
                            title: "Text Copied to Clipboard",
                            message: "No text field detected. Use Cmd+V to paste."
                        )
                    }
                }
                handleResult(.completed(text: cleanedText))
            }
        } catch let error as ElevenLabsError {
            await MainActor.run {
                handleResult(.failed(error: .processingFailed(message: error.userMessage)))
            }
        } catch {
            await MainActor.run {
                handleResult(.failed(error: .processingFailed(message: error.localizedDescription)))
            }
        }
    }

    private func commitAndSave() async {
        do {
            let rawText = try await transcriptionService?.commitAndGetTranscript()
            guard let rawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run { silentlyResetToIdle() }
                return
            }
            let hints = await MainActor.run { wordDictionary.words }
            let cleanedText: String
            if let service = textCleanupService {
                cleanedText = (try? await service.cleanup(rawText, wordHints: hints)) ?? rawText
            } else {
                cleanedText = rawText
            }
            await MainActor.run {
                handleResult(.completed(text: cleanedText))
            }
        } catch {
            await MainActor.run { silentlyResetToIdle() }
        }
    }

    private func silentlyResetToIdle() {
        currentSession = nil
        if case .success(let newState) = state.transition(to: .idle) {
            state = newState
        } else {
            state = .idle
        }
        menuBarController?.updateState(.idle)
    }

    private func handleResult(_ result: TranscriptionResult) {
        currentSession?.complete(with: result)
        currentSession = nil

        switch result {
        case .completed(let text):
            logStore.append(text: text, wasPasted: shouldPasteAfterProcessing)
            shouldPasteAfterProcessing = false
        case .discarded(let reason):
            switch reason {
            case .tooShort:
                notificationService?.show(
                    title: "Recording Too Short",
                    message: "Speak for at least half a second."
                )
            case .noSpeechDetected:
                notificationService?.show(
                    title: "No Speech Detected",
                    message: "No recognizable speech was found in the recording."
                )
            }
        case .failed(let error):
            overlayWindow?.show(state: .error(describeError(error)))
            notificationService?.show(
                title: "Transcription Failed",
                message: describeError(error)
            )
        }

        state = .idle
        menuBarController?.updateState(.idle)
        overlayWindow?.hide()
    }

    private func describeError(_ error: TranscriptionError) -> String {
        switch error {
        case .processingFailed(let message):
            return message
        case .microphoneUnavailable:
            return "Microphone is not accessible."
        case .permissionDenied:
            return "Microphone permission was denied."
        }
    }
}
