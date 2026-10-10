import AppKit

/// Owns the optional status item without tying its visibility to the app's lifetime.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let settings: AppSettings
    private let openSettings: () -> Void
    private var statusItem: NSStatusItem?
    private let enabledItem = NSMenuItem(title: "Enable Highlighting", action: #selector(toggleHighlighting), keyEquivalent: "")

    init(settings: AppSettings, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()
        enabledItem.target = self
    }

    func setVisible(_ visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "FocusLight")
            item.button?.toolTip = "FocusLight"

            let menu = NSMenu()
            menu.delegate = self
            menu.addItem(enabledItem)
            menu.addItem(.separator())
            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit FocusLight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            statusItem = item
        } else if let item = statusItem {
            // Detach the reused menu item even if AppKit still retains the old menu.
            item.menu?.removeItem(enabledItem)
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        enabledItem.state = settings.isEnabled ? .on : .off
    }

    @objc private func toggleHighlighting() {
        settings.isEnabled.toggle()
    }

    @objc private func showSettings() {
        openSettings()
    }
}
