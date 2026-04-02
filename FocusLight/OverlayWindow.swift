import AppKit

// A transparent, non-interactive floating window that draws the active highlight style.
final class OverlayWindow: NSWindow {
    private let borderView = BorderView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        contentView = borderView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(
        color: NSColor,
        width: CGFloat,
        cornerRadius: CGFloat,
        style: HighlightStyle,
        dotCorner: DotCorner
    ) {
        borderView.borderColor = color
        borderView.borderWidth = width
        borderView.cornerRadius = cornerRadius
        borderView.style = style
        borderView.dotCorner = dotCorner
    }
}

// MARK: - BorderView

private final class BorderView: NSView {
    var style: HighlightStyle = .border   { didSet { refresh() } }
    var borderColor: NSColor = .systemBlue { didSet { refresh() } }
    var borderWidth: CGFloat = 4.0         { didSet { refresh() } }
    var cornerRadius: CGFloat = 8.0        { didSet { refresh() } }
    var dotCorner: DotCorner = .topRight   { didSet { refresh() } }

    private let shapeLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
    }

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        shapeLayer.removeAllAnimations()

        switch style {
        case .border:
            drawBorder()
        case .top, .bottom, .left, .right:
            drawBar()
        case .dot:
            drawDot()
        }
    }

    private func drawBorder() {
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = borderColor.cgColor
        shapeLayer.lineWidth = borderWidth
        let inset = borderWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        shapeLayer.path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }

    private func drawBar() {
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = borderColor.cgColor
        shapeLayer.lineWidth = borderWidth

        let half = borderWidth / 2
        let w = bounds.width
        let h = bounds.height
        let path = CGMutablePath()

        switch style {
        case .top:
            path.move(to: CGPoint(x: 0, y: h - half))
            path.addLine(to: CGPoint(x: w, y: h - half))
        case .bottom:
            path.move(to: CGPoint(x: 0, y: half))
            path.addLine(to: CGPoint(x: w, y: half))
        case .left:
            path.move(to: CGPoint(x: half, y: 0))
            path.addLine(to: CGPoint(x: half, y: h))
        case .right:
            path.move(to: CGPoint(x: w - half, y: 0))
            path.addLine(to: CGPoint(x: w - half, y: h))
        default: break
        }

        shapeLayer.path = path
    }

    private func drawDot() {
        let diameter = max(borderWidth * 3, 10)
        let pad: CGFloat = 10
        let w = bounds.width
        let h = bounds.height

        // NSView without isFlipped: origin is bottom-left, Y increases upward.
        let origin: CGPoint
        switch dotCorner {
        case .topLeft:     origin = CGPoint(x: pad, y: h - pad - diameter)
        case .topRight:    origin = CGPoint(x: w - pad - diameter, y: h - pad - diameter)
        case .bottomLeft:  origin = CGPoint(x: pad, y: pad)
        case .bottomRight: origin = CGPoint(x: w - pad - diameter, y: pad)
        }

        shapeLayer.fillColor = borderColor.cgColor
        shapeLayer.strokeColor = nil
        shapeLayer.lineWidth = 0
        shapeLayer.path = CGPath(
            ellipseIn: CGRect(origin: origin, size: CGSize(width: diameter, height: diameter)),
            transform: nil
        )

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.15
        pulse.duration = 0.75
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shapeLayer.add(pulse, forKey: "pulse")
    }
}
