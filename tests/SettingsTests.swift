import Foundation
import SwiftUI

@main
struct SettingsTests {
    static func expect(_ condition: Bool, _ message: String) {
        precondition(condition, message)
    }

    static func defaults(_ values: [String: Any] = [:]) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "com.focuslight.tests.\(UUID().uuidString)")!
        defaults.setVolatileDomain(values, forName: UserDefaults.argumentDomain)
        return defaults
    }

    static func read(_ url: URL) throws -> SettingsConfiguration {
        try SettingsConfiguration(toml: String(contentsOf: url, encoding: .utf8))
    }

    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FocusLightTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        expect(AppSettings.defaultConfigurationURL == FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/FocusLight/config.toml"), "Config must use the requested path")

        let standard = SettingsConfiguration()
        expect(standard.showMenuBarIcon, "Show the menu bar icon by default")
        expect(try readRoundTrip(standard) == standard, "Default settings must round-trip")
        let parsed = try SettingsConfiguration(toml: """
        # A hand-written config with CRLF, literal strings, inline comments and numeric syntax.
        is_enabled = false
        show_menu_bar_icon = false
        highlight_style = 'dot'
        border_width = +1_0.5 # dot size
        padding = 2e0
        corner_radius = 12
        dot_corner = "bottomLeft"
        border_color = "#ff008080" # The # inside quotes is part of the color.
        """.replacingOccurrences(of: "\n", with: "\r\n"))
        expect(!parsed.isEnabled && parsed.highlightStyle == .dot && parsed.borderWidth == 10.5,
               "Parse booleans, styles, and decimal digit separators")
        expect(!parsed.showMenuBarIcon, "Parse hidden menu bar icon")
        expect(parsed.padding == 2 && parsed.cornerRadius == 12 && parsed.dotCorner == .bottomLeft,
               "Parse exponents, integers, and corners")
        expect(parsed.borderColorHex == "#ff008080", "Preserve color alpha and quoted hash characters")
        expect(try readRoundTrip(parsed) == parsed, "Customized settings must round-trip")
        let partial = try SettingsConfiguration(toml: "highlight_style = \"left\"\n border_color = '#abcdef'")
        expect(partial.highlightStyle == .left && partial.borderWidth == standard.borderWidth,
               "Missing keys must use built-in defaults")
        expect(partial.showMenuBarIcon, "Older config files must keep the icon visible")

        for invalid in [
            "is_enabled = yes", "is_enabled = \"false\"", "highlight_style = \"unknown\"",
            "show_menu_bar_icon = yes", "show_menu_bar_icon = \"false\"",
            "show_menu_bar_icon = true\nshow_menu_bar_icon = false",
            "dot_corner = \"bottom\"", "border_color = \"#XYZXYZ\"", "border_color = \"#12345\"",
            "border_width = 0", "border_width = 21", "border_width = nan", "border_width = 1e999",
            "padding = -1", "padding = 25", "corner_radius = 41", "corner_radius = 01",
            "padding = 2__0", "padding = \"2\"", "padding = 1\npadding = 2",
            "typo = true", "[appearance]", "is_enabled", "highlight_style = \"dot",
            "highlight_style = \"dot\" trailing", "highlight_style = \"dot\" # comment\nis_enabled =",
        ] {
            do {
                _ = try SettingsConfiguration(toml: invalid)
                preconditionFailure("Accepted invalid config: \(invalid)")
            } catch {
                expect(error.localizedDescription.contains("Line "), "Errors must identify their line")
            }
        }

        // First launch creates the directory and migrates every existing preference.
        let url = directory.appendingPathComponent(".config/FocusLight/config.toml")
        let oldDefaults = defaults([
            "isEnabled": false, "highlightStyle": "bottom", "borderWidth": 7.5,
            "padding": 3.5, "cornerRadius": 16.0, "dotCorner": "bottomRight", "borderColorHex": "#11223380",
        ])
        let settings = AppSettings(configurationURL: url, defaults: oldDefaults)
        let migrated = try read(url)
        expect(settings.configurationError == nil, "Creating a config must succeed")
        expect(settings.showMenuBarIcon && migrated.showMenuBarIcon, "Existing users keep the menu bar icon")
        expect(!migrated.isEnabled && migrated.highlightStyle == .bottom && migrated.borderWidth == 7.5,
               "Migrate existing toggle, style, and width")
        expect(migrated.padding == 3.5 && migrated.cornerRadius == 16 && migrated.dotCorner == .bottomRight
               && migrated.borderColorHex == "#11223380", "Migrate remaining preferences and alpha")

        // Each mutation must be written immediately, including the menu bar toggle.
        settings.isEnabled = true
        expect(try read(url).isEnabled, "Persist enabled state")
        settings.showMenuBarIcon = false
        expect(!(try read(url).showMenuBarIcon), "Persist hidden icon independently of highlighting")
        expect(settings.isEnabled, "Hiding the icon must leave highlighting enabled")
        settings.highlightStyle = .dot
        expect(try read(url).highlightStyle == .dot, "Persist style")
        settings.borderWidth = 9
        expect(try read(url).borderWidth == 9, "Persist width")
        settings.padding = 4
        expect(try read(url).padding == 4, "Persist padding")
        settings.cornerRadius = 10
        expect(try read(url).cornerRadius == 10, "Persist corner radius")
        settings.dotCorner = .topLeft
        expect(try read(url).dotCorner == .topLeft, "Persist corner")
        settings.borderColor = Color(red: 1, green: 0, blue: 0, opacity: 0.5)
        expect(try read(url).borderColorHex == "#FF000080", "Persist color and opacity")
        let reloaded = AppSettings(configurationURL: url, defaults: oldDefaults)
        expect(!reloaded.showMenuBarIcon, "Keep the icon hidden after restart")
        expect(reloaded.isEnabled && reloaded.highlightStyle == .dot && reloaded.borderWidth == 9
               && reloaded.padding == 4 && reloaded.cornerRadius == 10 && reloaded.dotCorner == .topLeft,
               "File must take precedence over old preferences on restart")
        expect(reloaded.nsColor.alphaComponent > 0.5 && reloaded.nsColor.alphaComponent < 0.51,
               "Reload color opacity")
        reloaded.showMenuBarIcon = true
        expect(try read(url).showMenuBarIcon, "Persist restoring the menu bar icon")

        // Hand edits load at startup without rewriting the user's file.
        let handwritten = "# Keep this comment\nhighlight_style = 'right'\n"
        try handwritten.write(to: url, atomically: true, encoding: .utf8)
        let edited = AppSettings(configurationURL: url, defaults: oldDefaults)
        expect(edited.highlightStyle == .right && edited.isEnabled && edited.borderWidth == 4,
               "Partial config must use built-in defaults rather than old preferences")
        expect(edited.showMenuBarIcon, "An omitted visibility setting restores the default")
        expect(try String(contentsOf: url, encoding: .utf8) == handwritten, "Do not rewrite an existing config on launch")

        // Invalid files must survive startup and UI changes for the user to repair.
        let invalidFile = "border_width = 0\n"
        try invalidFile.write(to: url, atomically: true, encoding: .utf8)
        let invalidSettings = AppSettings(configurationURL: url, defaults: defaults())
        expect(invalidSettings.configurationError != nil, "Surface load errors")
        invalidSettings.padding = 5
        expect(try String(contentsOf: url, encoding: .utf8) == invalidFile, "Preserve an invalid config")

        // A path through a regular file exercises write failure and recovery without relying on permissions.
        let blockedParent = directory.appendingPathComponent("blocked")
        try "file".write(to: blockedParent, atomically: true, encoding: .utf8)
        let failed = AppSettings(configurationURL: blockedParent.appendingPathComponent("config.toml"), defaults: defaults())
        expect(failed.configurationError != nil, "Surface write errors")
        try FileManager.default.removeItem(at: blockedParent)
        failed.padding = 6
        let recovered = try read(failed.configurationURL)
        expect(failed.configurationError == nil && recovered.padding == 6,
               "Retry saving and clear errors when the path becomes writable")

        let legacyURL = directory.appendingPathComponent("legacy/config.toml")
        _ = AppSettings(configurationURL: legacyURL, defaults: defaults([
            "colorRed": 1.0, "colorGreen": 0.0, "colorBlue": 0.0, "colorAlpha": 0.5,
        ]))
        expect(try read(legacyURL).borderColorHex == "#FF000080", "Migrate legacy color components")

        print("Settings tests passed (parsing, validation, migration, immediate writes, reload, and error recovery).")
    }

    static func readRoundTrip(_ configuration: SettingsConfiguration) throws -> SettingsConfiguration {
        try SettingsConfiguration(toml: configuration.toml)
    }
}
