import AppKit
import QuartzCore

@MainActor
final class FloatingTranscriptPanel {
    private let panel: NSPanel
    private let rootView = NSView()
    private let visualEffectView = NSVisualEffectView()
    private let waveformView = WaveformView()
    private let label = NSTextField(labelWithString: "")
    private var labelWidthConstraint: NSLayoutConstraint!
    private var containerWidthConstraint: NSLayoutConstraint!
    private let minLabelWidth: CGFloat = 190
    private let maxLabelWidth: CGFloat = 560
    private let waveformWidth: CGFloat = 72
    private let height: CGFloat = 64
    private let horizontalPadding: CGFloat = 20
    private let contentGap: CGFloat = 14
    private var displayedText = ""
    private var currentLabelWidth: CGFloat = 190
    private var currentContainerWidth: CGFloat = 316

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false

        setupContent()
    }

    func showListening() {
        updateTranscript("Listening...")
        show()
    }

    func showStatus(_ status: String) {
        updateTranscript(status)
        show()
    }

    func updateTranscript(_ text: String) {
        let displayText = text.isEmpty ? "Listening..." : text
        guard displayText != displayedText else { return }
        displayedText = displayText
        label.stringValue = displayText

        let targetWidth = widthForText(displayText)
        let totalWidth = containerWidth(forLabelWidth: targetWidth)
        let shouldResize = abs(targetWidth - currentLabelWidth) > 3 || abs(currentContainerWidth - totalWidth) > 3
        guard shouldResize else { return }

        currentLabelWidth = targetWidth
        currentContainerWidth = totalWidth

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                labelWidthConstraint.animator().constant = targetWidth
                containerWidthConstraint.animator().constant = totalWidth
                rootView.animator().layoutSubtreeIfNeeded()
            }
        } else {
            labelWidthConstraint.constant = targetWidth
            containerWidthConstraint.constant = totalWidth
            rootView.layoutSubtreeIfNeeded()
        }
    }

    func updateLevel(_ level: Double) {
        waveformView.updateLevel(level)
    }

    func hide() {
        guard panel.isVisible else { return }
        guard let contentLayer = visualEffectView.layer else {
            panel.orderOut(nil)
            return
        }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 0.92
        scale.duration = 0.22
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentLayer.add(scale, forKey: "exitScale")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        } completionHandler: { [panel] in
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    private func show() {
        panel.setFrame(frameFor(width: panel.frame.width), display: false)
        guard !panel.isVisible else { return }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        visualEffectView.layer?.transform = CATransform3DMakeScale(0.88, 0.88, 1)

        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.88
        spring.toValue = 1.0
        spring.mass = 0.8
        spring.stiffness = 180
        spring.damping = 18
        spring.initialVelocity = 0
        spring.duration = 0.35
        visualEffectView.layer?.add(spring, forKey: "entrySpring")
        visualEffectView.layer?.transform = CATransform3DIdentity

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    private func setupContent() {
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = rootView

        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = height / 2
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        visualEffectView.addSubview(waveformView)
        visualEffectView.addSubview(label)
        rootView.addSubview(visualEffectView)

        labelWidthConstraint = label.widthAnchor.constraint(equalToConstant: minLabelWidth)
        containerWidthConstraint = visualEffectView.widthAnchor.constraint(equalToConstant: currentContainerWidth)
        NSLayoutConstraint.activate([
            visualEffectView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            visualEffectView.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            visualEffectView.heightAnchor.constraint(equalToConstant: height),
            containerWidthConstraint,

            waveformView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: horizontalPadding),
            waveformView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: waveformWidth),
            waveformView.heightAnchor.constraint(equalToConstant: 42),

            label.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: contentGap),
            label.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            labelWidthConstraint,
            label.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -horizontalPadding)
        ])
    }

    private func widthForText(_ text: String) -> CGFloat {
        let font = label.font ?? .systemFont(ofSize: 15, weight: .medium)
        let rawWidth = (text as NSString).boundingRect(
            with: NSSize(width: maxLabelWidth, height: 24),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        ).width + 8
        return min(max(rawWidth, minLabelWidth), maxLabelWidth)
    }

    private func containerWidth(forLabelWidth labelWidth: CGFloat) -> CGFloat {
        horizontalPadding * 2 + waveformWidth + contentGap + labelWidth
    }

    private func frameFor(width: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let fixedWidth = containerWidth(forLabelWidth: maxLabelWidth) + 24
        let x = visibleFrame.midX - fixedWidth / 2
        let y = visibleFrame.minY + 72
        return NSRect(x: x, y: y, width: fixedWidth, height: height)
    }
}
