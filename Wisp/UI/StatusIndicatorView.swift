import AppKit

// MARK: - WaveformBarsView

@MainActor
final class WaveformBarsView: NSView {

    private static let barCount = 5
    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2
    private static let minHeightRatio: CGFloat = 0.15
    static let totalWidth: CGFloat = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBars() {
        guard let rootLayer = layer else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        for i in 0..<Self.barCount {
            let bar = CALayer()
            bar.name = "bar"
            bar.contentsScale = scale
            bar.backgroundColor = NSColor.systemRed.cgColor
            bar.cornerRadius = Self.barWidth / 2
            bar.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            let x = CGFloat(i) * (Self.barWidth + Self.barSpacing)
            let minH = bounds.height * Self.minHeightRatio
            bar.frame = CGRect(
                x: x,
                y: (bounds.height - minH) / 2,
                width: Self.barWidth,
                height: max(minH, 1)
            )
            rootLayer.addSublayer(bar)
        }
    }

    func updateAudioLevels(_ levels: [Float]) {
        guard let bars = layer?.sublayers?.filter({ $0.name == "bar" }),
              bars.count == Self.barCount else { return }

        let viewHeight = bounds.height
        for (i, bar) in bars.enumerated() {
            let rawLevel = i < levels.count ? CGFloat(levels[i]) : 0
            let level = max(rawLevel, Self.minHeightRatio)
            let targetHeight = max(viewHeight * level, 1)

            let anim = CABasicAnimation(keyPath: "bounds.size.height")
            anim.fromValue = bar.bounds.height
            anim.toValue = targetHeight
            anim.duration = 0.2
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false

            let posAnim = CABasicAnimation(keyPath: "position.y")
            posAnim.fromValue = bar.position.y
            posAnim.toValue = (viewHeight - targetHeight) / 2 + targetHeight / 2
            posAnim.duration = 0.2
            posAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            posAnim.fillMode = .forwards
            posAnim.isRemovedOnCompletion = false

            bar.add(anim, forKey: "heightAnim")
            bar.add(posAnim, forKey: "posAnim")
            bar.bounds.size.height = targetHeight
            bar.position.y = (viewHeight - targetHeight) / 2 + targetHeight / 2
        }
    }
}

// MARK: - StatusIndicatorView

@MainActor
final class StatusIndicatorView: NSView {

    private let backgroundView: NSVisualEffectView
    private let label: NSTextField
    private let spinner: NSProgressIndicator
    private let recordingDot: NSView
    private let waveformBars: WaveformBarsView
    // Container view for the cancel progress bar; the orange fill is a CALayer sublayer
    // so Auto Layout does not interfere with the width animation.
    private let cancelProgressBarContainer: NSView

    private var errorDismissWork: DispatchWorkItem?
    var onErrorDismissed: (() -> Void)?

    override init(frame frameRect: NSRect) {
        backgroundView = NSVisualEffectView(frame: frameRect)
        label = NSTextField(labelWithString: "")
        spinner = NSProgressIndicator()
        recordingDot = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
        waveformBars = WaveformBarsView(
            frame: NSRect(x: 0, y: 0, width: WaveformBarsView.totalWidth, height: frameRect.height)
        )
        cancelProgressBarContainer = NSView()

        super.init(frame: frameRect)

        setupBackground(frameRect)
        // Add all subviews before activating constraints so cross-view anchors are valid
        addSubview(spinner)
        addSubview(recordingDot)
        addSubview(label)
        addSubview(waveformBars)
        addSubview(cancelProgressBarContainer)
        setupSpinner()
        setupRecordingDot()
        setupLabel()
        setupWaveformBars()
        setupCancelProgressBarContainer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ state: IndicatorState) {
        errorDismissWork?.cancel()
        errorDismissWork = nil

        switch state {
        case .recording:
            label.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            recordingDot.isHidden = false
            waveformBars.isHidden = false
            addPulseAnimation()
            stopCancelProgressAnimation()
            isHidden = false

        case .cancelling:
            label.stringValue = "Cancelling..."
            label.textColor = NSColor.systemOrange
            label.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            recordingDot.isHidden = true
            recordingDot.layer?.removeAllAnimations()
            hideWaveformBars()
            startCancelProgressAnimation()
            isHidden = false

        case .transcribing:
            label.stringValue = "Transcribing..."
            label.textColor = NSColor.systemBlue
            label.isHidden = false
            spinner.isHidden = false
            spinner.startAnimation(nil)
            recordingDot.isHidden = true
            recordingDot.layer?.removeAllAnimations()
            hideWaveformBars()
            stopCancelProgressAnimation()
            isHidden = false

        case .error(let message):
            label.stringValue = message
            label.textColor = NSColor.systemOrange
            label.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            recordingDot.isHidden = true
            recordingDot.layer?.removeAllAnimations()
            hideWaveformBars()
            stopCancelProgressAnimation()
            isHidden = false
            scheduleErrorDismiss()

        case .hidden:
            spinner.stopAnimation(nil)
            recordingDot.layer?.removeAllAnimations()
            recordingDot.isHidden = true
            waveformBars.isHidden = true
            stopCancelProgressAnimation()
            isHidden = true
        }
    }

    // MARK: - Setup

    private func setupBackground(_ frameRect: NSRect) {
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = frameRect.height / 2
        backgroundView.layer?.masksToBounds = true
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)
    }

    private func setupSpinner() {
        spinner.style = .spinning
        spinner.controlSize = .mini
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true

        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -5),
            spinner.widthAnchor.constraint(equalToConstant: 12),
            spinner.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    private func setupRecordingDot() {
        recordingDot.wantsLayer = true
        recordingDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordingDot.layer?.cornerRadius = 3.5
        recordingDot.translatesAutoresizingMaskIntoConstraints = false
        recordingDot.isHidden = true

        NSLayoutConstraint.activate([
            recordingDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            recordingDot.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -14),
            recordingDot.widthAnchor.constraint(equalToConstant: 7),
            recordingDot.heightAnchor.constraint(equalToConstant: 7),
        ])
    }

    private func setupLabel() {
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 8),
        ])
    }

    private func setupWaveformBars() {
        waveformBars.translatesAutoresizingMaskIntoConstraints = false
        waveformBars.isHidden = true

        NSLayoutConstraint.activate([
            waveformBars.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveformBars.leadingAnchor.constraint(equalTo: recordingDot.trailingAnchor, constant: 6),
            waveformBars.widthAnchor.constraint(equalToConstant: WaveformBarsView.totalWidth),
            waveformBars.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.6),
        ])
    }

    func updateAudioLevels(_ levels: [Float]) {
        waveformBars.updateAudioLevels(levels)
    }

    private func hideWaveformBars() {
        guard !waveformBars.isHidden else { return }
        // Fade out bar layers before hiding the view
        if let bars = waveformBars.layer?.sublayers?.filter({ $0.name == "bar" }) {
            for bar in bars {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = bar.opacity
                fade.toValue = 0.0
                fade.duration = 0.15
                fade.fillMode = .forwards
                fade.isRemovedOnCompletion = false
                bar.add(fade, forKey: "fadeOut")
            }
        }
        // Hide immediately (the fade animation is visual-only via Core Animation)
        waveformBars.isHidden = true
        // Reset bar opacity for next recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.waveformBars.layer?.sublayers?
                .filter { $0.name == "bar" }
                .forEach { $0.removeAnimation(forKey: "fadeOut"); $0.opacity = 1.0 }
        }
    }

    private func setupCancelProgressBarContainer() {
        // The container defines the track area via Auto Layout.
        // The actual orange fill is a CALayer sublayer added/removed by the animation methods.
        cancelProgressBarContainer.wantsLayer = true
        cancelProgressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        cancelProgressBarContainer.isHidden = true

        NSLayoutConstraint.activate([
            cancelProgressBarContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            cancelProgressBarContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            cancelProgressBarContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            cancelProgressBarContainer.heightAnchor.constraint(equalToConstant: 3),
        ])
    }

    // MARK: - Animations

    private func addPulseAnimation() {
        guard let dotLayer = recordingDot.layer else { return }
        dotLayer.removeAllAnimations()

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(pulse, forKey: "pulse")
    }

    private func startCancelProgressAnimation() {
        cancelProgressBarContainer.isHidden = false
        guard let containerLayer = cancelProgressBarContainer.layer else { return }

        // Remove any previous fill sublayer and animations
        containerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        containerLayer.removeAllAnimations()

        // Determine the bar width. frame.width is set by Auto Layout once the view is
        // on screen. If layout has not yet run, fall back to the parent width minus padding.
        let barWidth = cancelProgressBarContainer.frame.width > 0
            ? cancelProgressBarContainer.frame.width
            : max(frame.width - 20, 1)
        let barHeight: CGFloat = 3

        // Create a fill sublayer independent of Auto Layout so the animation is
        // not overwritten by layout passes.
        let fillLayer = CALayer()
        fillLayer.backgroundColor = NSColor.systemOrange.cgColor
        fillLayer.cornerRadius = 1.5
        // Anchor at the leading (left) edge so shrinking width drains right → left.
        fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.bounds = CGRect(x: 0, y: 0, width: barWidth, height: barHeight)
        fillLayer.position = CGPoint(x: 0, y: barHeight / 2)
        containerLayer.addSublayer(fillLayer)

        let drain = CABasicAnimation(keyPath: "bounds.size.width")
        drain.fromValue = barWidth
        drain.toValue = 0
        drain.duration = 3.0
        drain.fillMode = .forwards
        drain.isRemovedOnCompletion = false
        drain.timingFunction = CAMediaTimingFunction(name: .linear)
        fillLayer.add(drain, forKey: "drain")
    }

    private func stopCancelProgressAnimation() {
        cancelProgressBarContainer.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        cancelProgressBarContainer.layer?.removeAllAnimations()
        cancelProgressBarContainer.isHidden = true
    }

    private func scheduleErrorDismiss() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.update(.hidden)
            self.onErrorDismissed?()
        }
        errorDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
