import AppKit
import ApplicationServices
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings.shared
    private var highlighter: WindowHighlighter?
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicit policy keeps the app out of the Dock and App Switcher.
        // Info.plist's LSUIElement=true does the same, but being explicit here
        // documents intent and guards against accidental policy changes.
        NSApp.setActivationPolicy(.accessory)
        setupApplicationMenu()
        setupMenuBar()
        setupHighlighter()
        promptAccessibilityIfNeeded()

        // A manual launch with the icon hidden must still provide access to controls.
        // Login-item launches should continue quietly in the background.
        if !settings.showMenuBarIcon && !launchedAtLogin {
            showSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView().environmentObject(settings)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "FocusLight Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }
        settingsWindow?.deminiaturize(nil)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private func setupMenuBar() {
        menuBar = MenuBarController(settings: settings) { [weak self] in
            self?.showSettings()
        }
        settings.$showMenuBarIcon
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.menuBar?.setVisible(visible) }
            .store(in: &cancellables)
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FocusLight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
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
