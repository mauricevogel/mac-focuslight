import AppKit
import ApplicationServices
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings.shared
    private var highlighter: WindowHighlighter?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHighlighter()
        promptAccessibilityIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupHighlighter() {
        highlighter = WindowHighlighter(settings: settings)

        settings.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                enabled ? self?.highlighter?.start() : self?.highlighter?.stop()
            }
            .store(in: &cancellables)

        if settings.isEnabled { highlighter?.start() }
    }

    private func promptAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
