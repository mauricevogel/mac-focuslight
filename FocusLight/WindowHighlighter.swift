import AppKit
import ApplicationServices
import Combine

final class WindowHighlighter {
    private let settings: AppSettings
    private let overlay: OverlayWindow
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        self.overlay = OverlayWindow()
        refreshAppearance()

        // Keep overlay visuals in sync with all settings changes.
        // objectWillChange fires before the update, so delay one cycle to read new values.
        settings.objectWillChange
            .delay(for: 0, scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAppearance() }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        overlay.orderOut(nil)
    }

    // MARK: - Private

    private func refreshAppearance() {
        overlay.update(
            color: settings.nsColor,
            width: CGFloat(settings.borderWidth),
            cornerRadius: CGFloat(settings.cornerRadius),
            style: settings.highlightStyle,
            dotCorner: settings.dotCorner
        )
    }

    private func tick() {
        guard let frame = focusedWindowFrame() else {
            overlay.orderOut(nil)
            return
        }

        // For a full border the stroke is centred on the overlay edge, so expand by half
        // the stroke width to keep it just outside the window. Bars and dots sit inside.
        let strokeExpand = settings.highlightStyle == .border ? CGFloat(settings.borderWidth) / 2 : 0
        let expand = CGFloat(settings.padding) + strokeExpand
        let overlayFrame = frame.insetBy(dx: -expand, dy: -expand)

        if overlay.frame != overlayFrame {
            overlay.setFrame(overlayFrame, display: false)
        }
        overlay.orderFrontRegardless()
    }

    // MARK: - Accessibility

    private func focusedWindowFrame() -> CGRect? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }

        return axWindowFrame(windowRef as! AXUIElement)
    }

    private func axWindowFrame(_ window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        // AX uses top-left origin (Y down). NSScreen uses bottom-left origin (Y up).
        // The main screen height is the reference for the Y flip.
        guard let mainHeight = NSScreen.main?.frame.height else { return nil }
        let flippedY = mainHeight - position.y - size.height

        return CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)
    }
}
