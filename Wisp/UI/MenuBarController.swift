import AppKit

@MainActor
final class MenuBarController: NSObject {

    private let statusItem: NSStatusItem

    // Beep-timing state
    private var activeStartSound: NSSound?
    private var startSoundCompletion: (() -> Void)?
    private var startSoundFallbackTask: Task<Void, Never>?

    // Ghost icon drawn programmatically as a template image (original design, not Nintendo's Wisp)
    private static let ghostIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            let path = NSBezierPath()
            path.windingRule = .evenOdd
            // Ghost head (top semicircle) — center (9,11), radius 6
            path.move(to: NSPoint(x: 3, y: 11))
            path.appendArc(
                withCenter: NSPoint(x: 9, y: 11), radius: 6, startAngle: 180, endAngle: 0,
                clockwise: true)
            // Straight sides down to scalloped skirt
            path.line(to: NSPoint(x: 15, y: 2))
            // Three downward scallops, right → left
            path.appendArc(
                withCenter: NSPoint(x: 13, y: 2), radius: 2, startAngle: 0, endAngle: 180,
                clockwise: true)
            path.appendArc(
                withCenter: NSPoint(x: 9, y: 2), radius: 2, startAngle: 0, endAngle: 180,
                clockwise: true)
            path.appendArc(
                withCenter: NSPoint(x: 5, y: 2), radius: 2, startAngle: 0, endAngle: 180,
                clockwise: true)
            path.close()
            path.appendOval(in: NSRect(x: 5.3, y: 11.8, width: 2.4, height: 2.4))
            path.appendOval(in: NSRect(x: 10.3, y: 11.8, width: 2.4, height: 2.4))
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        super.init()
        updateState(.idle)
    }

    func updateState(_ state: AppState) {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle, .cancelling:
            button.image = Self.ghostIcon
        case .recording:
            button.image = NSImage(
                systemSymbolName: "mic.fill",
                accessibilityDescription: "Wisp — Recording"
            )
        case .processing:
            button.image = NSImage(
                systemSymbolName: "ellipsis.circle",
                accessibilityDescription: "Wisp — Processing"
            )
        }
    }

    /// Plays the start beep and calls `completion` only after the sound finishes.
    /// Falls back to calling `completion` immediately if the sound asset is unavailable,
    /// and after 1 second if the delegate callback never fires.
    func playStartSound(completion: @escaping @MainActor () -> Void) {
        guard let url = Bundle.module.url(forResource: "record-start", withExtension: "wav"),
            let sound = NSSound(contentsOf: url, byReference: true)
        else {
            completion()
            return
        }

        startSoundCompletion = completion
        activeStartSound = sound

        startSoundFallbackTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return  // Cancelled when delegate fired normally
            }
            self?.fireSoundCompletion()
        }

        sound.delegate = self
        sound.play()
    }

    func playStopSound() {
        guard let url = Bundle.module.url(forResource: "record-stop", withExtension: "wav") else {
            print("[Wisp] Sound not found: record-stop.wav")
            return
        }
        let sound = NSSound(contentsOf: url, byReference: true)
        sound?.play()
    }

    private func fireSoundCompletion() {
        startSoundFallbackTask?.cancel()
        startSoundFallbackTask = nil
        activeStartSound = nil
        let completion = startSoundCompletion
        startSoundCompletion = nil
        completion?()
    }
}

extension MenuBarController: NSSoundDelegate {
    nonisolated func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        Task { @MainActor [weak self] in
            self?.fireSoundCompletion()
        }
    }
}
