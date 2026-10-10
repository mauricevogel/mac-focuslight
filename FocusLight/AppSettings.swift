import SwiftUI
import Combine

enum HighlightStyle: String, CaseIterable, Identifiable {
    case border, top, bottom, left, right, dot
    var id: String { rawValue }
    var label: String {
        switch self {
        case .border: return "Full border"
        case .top:    return "Top bar"
        case .bottom: return "Bottom bar"
        case .left:   return "Left bar"
        case .right:  return "Right bar"
        case .dot:    return "Corner dot"
        }
    }
}

enum DotCorner: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .topLeft:     return "Top left"
        case .topRight:    return "Top right"
        case .bottomLeft:  return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let defaultConfigurationURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/FocusLight/config.toml")

    let configurationURL: URL
    @Published private(set) var configurationError: String?
    private var canWriteConfiguration = true

    @Published var isEnabled: Bool {
        didSet { saveConfiguration() }
    }
    @Published var highlightStyle: HighlightStyle {
        didSet { saveConfiguration() }
    }
    @Published var borderWidth: Double {
        didSet { saveConfiguration() }
    }
    @Published var padding: Double {
        didSet { saveConfiguration() }
    }
    @Published var cornerRadius: Double {
        didSet { saveConfiguration() }
    }
    @Published var dotCorner: DotCorner {
        didSet { saveConfiguration() }
    }
    @Published var borderColor: Color {
        didSet { saveConfiguration() }
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let highlightStyle = "highlightStyle"
        static let borderWidth = "borderWidth"
        static let padding = "padding"
        static let cornerRadius = "cornerRadius"
        static let dotCorner = "dotCorner"
        static let borderColorHex = "borderColorHex"
        // Legacy keys kept for one-time migration only
        static let legacyRed = "colorRed"
        static let legacyGreen = "colorGreen"
        static let legacyBlue = "colorBlue"
        static let legacyAlpha = "colorAlpha"
    }

    init(configurationURL: URL = AppSettings.defaultConfigurationURL, defaults: UserDefaults = .standard) {
        self.configurationURL = configurationURL
        let fileExists = FileManager.default.fileExists(atPath: configurationURL.path)
        var configuration = SettingsConfiguration()
        var loadError: String?

        if fileExists {
            do {
                configuration = try SettingsConfiguration(toml: String(contentsOf: configurationURL, encoding: .utf8))
            } catch {
                canWriteConfiguration = false
                loadError = "Could not load config.toml: \(error.localizedDescription) Fix the file and restart FocusLight. Changes will not be saved until then."
            }
        } else {
            configuration = Self.migratedConfiguration(from: defaults)
        }

        isEnabled = configuration.isEnabled
        highlightStyle = configuration.highlightStyle
        borderWidth = configuration.borderWidth
        padding = configuration.padding
        cornerRadius = configuration.cornerRadius
        dotCorner = configuration.dotCorner
        borderColor = Color(hexString: configuration.borderColorHex) ?? Color(red: 0.0, green: 0.478, blue: 1.0)
        configurationError = loadError

        if !fileExists { saveConfiguration() }
    }

    private static func migratedConfiguration(from d: UserDefaults) -> SettingsConfiguration {
        var configuration = SettingsConfiguration()
        configuration.isEnabled = (d.object(forKey: Keys.isEnabled) as? Bool) ?? configuration.isEnabled
        configuration.highlightStyle = HighlightStyle(rawValue: d.string(forKey: Keys.highlightStyle) ?? "") ?? configuration.highlightStyle
        configuration.dotCorner = DotCorner(rawValue: d.string(forKey: Keys.dotCorner) ?? "") ?? configuration.dotCorner

        if let value = d.object(forKey: Keys.borderWidth) as? Double, value.isFinite, (1 ... 20).contains(value) {
            configuration.borderWidth = value
        }
        if let value = d.object(forKey: Keys.padding) as? Double, value.isFinite, (0 ... 24).contains(value) {
            configuration.padding = value
        }
        if let value = d.object(forKey: Keys.cornerRadius) as? Double, value.isFinite, (0 ... 40).contains(value) {
            configuration.cornerRadius = value
        }

        if let hex = d.string(forKey: Keys.borderColorHex), let color = Color(hexString: hex) {
            configuration.borderColorHex = color.hexString
        } else if d.object(forKey: Keys.legacyRed) != nil {
            let color = Color(
                red: d.double(forKey: Keys.legacyRed),
                green: d.double(forKey: Keys.legacyGreen),
                blue: d.double(forKey: Keys.legacyBlue),
                opacity: d.double(forKey: Keys.legacyAlpha)
            )
            configuration.borderColorHex = color.hexString
        }
        return configuration
    }

    private func saveConfiguration() {
        guard canWriteConfiguration else { return }
        var configuration = SettingsConfiguration()
        configuration.isEnabled = isEnabled
        configuration.highlightStyle = highlightStyle
        configuration.borderWidth = borderWidth
        configuration.padding = padding
        configuration.cornerRadius = cornerRadius
        configuration.dotCorner = dotCorner
        configuration.borderColorHex = borderColor.hexString

        do {
            try FileManager.default.createDirectory(at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try configuration.toml.write(to: configurationURL, atomically: true, encoding: .utf8)
            if configurationError != nil { configurationError = nil }
        } catch {
            configurationError = "Could not save config.toml: \(error.localizedDescription)"
        }
    }

    var nsColor: NSColor {
        NSColor(borderColor).usingColorSpace(.deviceRGB) ?? .systemBlue
    }
}

// MARK: - Color ↔ Hex String

private extension Color {
    /// Returns an 8-digit hex string "#RRGGBBAA".
    var hexString: String {
        guard let ns = NSColor(self).usingColorSpace(.deviceRGB) else { return "#0079FFFF" }
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    /// Parses a "#RRGGBBAA" or "#RRGGBB" hex string.
    init?(hexString: String) {
        var s = hexString
        if s.hasPrefix("#") { s.removeFirst() }
        switch s.count {
        case 6:
            guard let value = UInt32(s, radix: 16) else { return nil }
            self.init(
                red:   Double((value >> 16) & 0xFF) / 255,
                green: Double((value >>  8) & 0xFF) / 255,
                blue:  Double( value        & 0xFF) / 255
            )
        case 8:
            guard let value = UInt32(s, radix: 16) else { return nil }
            self.init(
                red:     Double((value >> 24) & 0xFF) / 255,
                green:   Double((value >> 16) & 0xFF) / 255,
                blue:    Double((value >>  8) & 0xFF) / 255,
                opacity: Double( value        & 0xFF) / 255
            )
        default:
            return nil
        }
    }
}
