import AppKit
import ApplicationServices
import Combine

final class WindowHighlighter {
    private let settings: AppSettings
    private let overlay: OverlayWindow
    private var cancellables = Set<AnyCancellable>()

    // AX observation state
    private var axObserver: AXObserver?
    private var observedApp: AXUIElement?
    private var observedWindow: AXUIElement?
    private var observedPID: pid_t = 0

    init(settings: AppSettings) {
        self.settings = settings
        self.overlay = OverlayWindow()
        refreshAppearance()

        // Keep overlay visuals and frame in sync with all settings changes.
        // objectWillChange fires before the update, so delay one cycle to read new values.
        settings.objectWillChange
            .delay(for: 0, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
                self?.updateOverlayPosition()
            }
            .store(in: &cancellables)
    }

    deinit {
        teardownAXObserver()
    }

    // MARK: - Lifecycle

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        trackFrontmostApp()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        teardownAXObserver()
        overlay.orderOut(nil)
    }

    // MARK: - App Tracking

    @objc private func activeAppChanged() {
        trackFrontmostApp()
    }

    private func trackFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            teardownAXObserver()
            overlay.orderOut(nil)
            return
        }

        let pid = app.processIdentifier
        if pid != observedPID {
            teardownAXObserver()
            setupAXObserver(pid: pid)
        }

        updateOverlayPosition()
    }

    // MARK: - AX Observer

    private func setupAXObserver(pid: pid_t) {
        var obs: AXObserver?
        guard AXObserverCreate(pid, axEventCallback, &obs) == .success, let obs else { return }

        let axApp = AXUIElementCreateApplication(pid)
        let ctx = Unmanaged.passUnretained(self).toOpaque()

        // App-level: track when the focused window changes
        AXObserverAddNotification(obs, axApp, kAXFocusedWindowChangedNotification as CFString, ctx)

        // Window-level: track move and resize for the initially focused window
        if let window = focusedWindow(of: axApp) {
            AXObserverAddNotification(obs, window, kAXWindowMovedNotification as CFString, ctx)
            AXObserverAddNotification(obs, window, kAXWindowResizedNotification as CFString, ctx)
            observedWindow = window
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        axObserver = obs
        observedApp = axApp
        observedPID = pid
    }

    private func teardownAXObserver() {
        if let obs = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        axObserver = nil
        observedApp = nil
        observedWindow = nil
        observedPID = 0
    }

    // Called by the C callback on the main run loop.
    fileprivate func handleAXEvent(notification: CFString) {
        // When the focused window changes within the same app, re-register move/resize
        // notifications on the new window so we keep tracking it accurately.
        if notification as String == kAXFocusedWindowChangedNotification,
           let obs = axObserver, let app = observedApp {
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            if let old = observedWindow {
                AXObserverRemoveNotification(obs, old, kAXWindowMovedNotification as CFString)
                AXObserverRemoveNotification(obs, old, kAXWindowResizedNotification as CFString)
            }
            if let newWindow = focusedWindow(of: app) {
                AXObserverAddNotification(obs, newWindow, kAXWindowMovedNotification as CFString, ctx)
                AXObserverAddNotification(obs, newWindow, kAXWindowResizedNotification as CFString, ctx)
                observedWindow = newWindow
            } else {
                observedWindow = nil
            }
        }
        updateOverlayPosition()
    }

    // MARK: - Overlay

    private func refreshAppearance() {
        overlay.update(
            color: settings.nsColor,
            width: CGFloat(settings.borderWidth),
            cornerRadius: CGFloat(settings.cornerRadius),
            style: settings.highlightStyle,
            dotCorner: settings.dotCorner
        )
    }

    private func updateOverlayPosition() {
        // Use the stored window reference when available; fall back to querying the app element
        // (e.g., immediately after setup before the first focused-window-changed event).
        let window = observedWindow ?? observedApp.flatMap { focusedWindow(of: $0) }
        guard let window, let frame = axWindowFrame(window) else {
            overlay.orderOut(nil)
            return
        }

        let strokeExpand = settings.highlightStyle == .border ? CGFloat(settings.borderWidth) / 2 : 0
        let expand = CGFloat(settings.padding) + strokeExpand
        let overlayFrame = frame.insetBy(dx: -expand, dy: -expand)

        if overlay.frame != overlayFrame {
            overlay.setFrame(overlayFrame, display: false)
        }
        overlay.orderFrontRegardless()
    }

    // MARK: - Accessibility

    private func focusedWindow(of axApp: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
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
        guard let mainHeight = NSScreen.main?.frame.height else { return nil }
        return CGRect(x: position.x,
                      y: mainHeight - position.y - size.height,
                      width: size.width,
                      height: size.height)
    }
}

// MARK: - AX C Callback

// Free function required by AXObserverCreate. Runs on the main run loop.
private func axEventCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ userData: UnsafeMutableRawPointer?
) {
    guard let userData else { return }
    Unmanaged<WindowHighlighter>.fromOpaque(userData)
        .takeUnretainedValue()
        .handleAXEvent(notification: notification)
}
