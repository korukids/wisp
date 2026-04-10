import AppKit

@MainActor
final class StatusOverlayWindow: NSPanel {

    private static let defaultWidth: CGFloat = 150
    private static let recordingWidth: CGFloat = 70
    private static let overlayHeight: CGFloat = 28

    private let indicatorView: StatusIndicatorView

    init() {
        indicatorView = StatusIndicatorView(
            frame: NSRect(
                x: 0, y: 0,
                width: StatusOverlayWindow.defaultWidth,
                height: StatusOverlayWindow.overlayHeight
            )
        )

        super.init(
            contentRect: NSRect(
                x: 0, y: 0,
                width: StatusOverlayWindow.defaultWidth,
                height: StatusOverlayWindow.overlayHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        contentView = indicatorView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func updateAudioLevels(_ levels: [Float]) {
        indicatorView.updateAudioLevels(levels)
    }

    func show(state: IndicatorState) {
        let wasVisible = isVisible
        indicatorView.update(state)
        updateWindowSize(for: state)
        updateWindowLevel(for: state)
        positionAtBottomCenter()

        if wasVisible {
            // Fade transition between states
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.animator().alphaValue = 1.0
            }
        } else {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.animator().alphaValue = 1.0
            }
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.indicatorView.update(.hidden)
                self?.orderOut(nil)
                self?.alphaValue = 1.0
            }
        })
    }

    // MARK: - Private

    private func updateWindowSize(for state: IndicatorState) {
        let targetWidth: CGFloat
        switch state {
        case .recording:
            targetWidth = Self.recordingWidth
        default:
            targetWidth = Self.defaultWidth
        }
        if abs(frame.width - targetWidth) > 1 {
            let newFrame = NSRect(
                x: frame.origin.x, y: frame.origin.y,
                width: targetWidth, height: Self.overlayHeight
            )
            setFrame(newFrame, display: true)
            indicatorView.frame = NSRect(
                x: 0, y: 0, width: targetWidth, height: Self.overlayHeight
            )
            indicatorView.subviews.first?.frame = indicatorView.bounds  // background
        }
    }

    private func updateWindowLevel(for state: IndicatorState) {
        switch state {
        case .recording, .transcribing:
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        default:
            level = .floating
        }
    }

    func positionAtBottomCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - frame.width) / 2
        let y = screenFrame.origin.y + 40
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func screenParametersChanged() {
        if isVisible {
            positionAtBottomCenter()
        }
    }
}
