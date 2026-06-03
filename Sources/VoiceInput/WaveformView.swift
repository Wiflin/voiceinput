import AppKit
import QuartzCore

final class WaveformView: NSView {
    private let weights: [CGFloat] = [0.62, 0.86, 1.0, 0.82, 0.66]
    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.10, green: 0.55, blue: 1.00, alpha: 0.82),
        NSColor(calibratedRed: 0.02, green: 0.45, blue: 0.92, alpha: 0.92),
        NSColor(calibratedRed: 0.00, green: 0.32, blue: 0.84, alpha: 1.00),
        NSColor(calibratedRed: 0.02, green: 0.45, blue: 0.92, alpha: 0.92),
        NSColor(calibratedRed: 0.10, green: 0.55, blue: 1.00, alpha: 0.82)
    ]
    private var bars: [CALayer] = []
    private var barLevels: [CGFloat] = Array(repeating: 0, count: 5)
    private var envelope: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    func updateLevel(_ level: Double) {
        let boosted = min(max(level * 1.55, 0), 1)
        let target = CGFloat(pow(boosted, 0.65))
        let coefficient: CGFloat = target > envelope ? 0.68 : 0.30
        envelope += (target - envelope) * coefficient

        for index in weights.indices {
            let jitter = CGFloat.random(in: -0.05...0.05)
            barLevels[index] = max(0, min(1, envelope * weights[index] * (1 + jitter)))
        }
        layoutBars()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        bars = weights.indices.map { index in
            let bar = CALayer()
            bar.backgroundColor = colors[index % colors.count].withAlphaComponent(0.95).cgColor
            bar.cornerRadius = 3
            layer?.addSublayer(bar)
            return bar
        }
    }

    private func layoutBars() {
        guard bounds.width > 0, bounds.height > 0, bars.count == weights.count else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let barCount = weights.count
        let barWidth: CGFloat = 6
        let gap: CGFloat = 4
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * gap
        let startX = max(0, (bounds.width - totalWidth) / 2)
        let minHeight: CGFloat = 9
        let maxHeight = bounds.height

        for index in 0..<barCount {
            let height = minHeight + (maxHeight - minHeight) * barLevels[index]
            let x = startX + CGFloat(index) * (barWidth + gap)
            let y = (bounds.height - height) / 2
            bars[index].frame = CGRect(x: x, y: y, width: barWidth, height: height)
        }
        CATransaction.commit()
    }
}
