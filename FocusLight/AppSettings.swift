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

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }
    @Published var highlightStyle: HighlightStyle {
        didSet { UserDefaults.standard.set(highlightStyle.rawValue, forKey: Keys.highlightStyle) }
    }
    @Published var borderWidth: Double {
        didSet { UserDefaults.standard.set(borderWidth, forKey: Keys.borderWidth) }
    }
    @Published var padding: Double {
        didSet { UserDefaults.standard.set(padding, forKey: Keys.padding) }
    }
    @Published var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: Keys.cornerRadius) }
    }
    @Published var dotCorner: DotCorner {
        didSet { UserDefaults.standard.set(dotCorner.rawValue, forKey: Keys.dotCorner) }
    }
    @Published var borderColor: Color {
        didSet { UserDefaults.standard.set(borderColor.hexString, forKey: Keys.borderColorHex) }
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

    private init() {
        let d = UserDefaults.standard
        isEnabled = (d.object(forKey: Keys.isEnabled) as? Bool) ?? true
        highlightStyle = HighlightStyle(rawValue: d.string(forKey: Keys.highlightStyle) ?? "") ?? .border
        borderWidth = (d.object(forKey: Keys.borderWidth) as? Double) ?? 4.0
        padding = (d.object(forKey: Keys.padding) as? Double) ?? 0.0
        cornerRadius = (d.object(forKey: Keys.cornerRadius) as? Double) ?? 8.0
        dotCorner = DotCorner(rawValue: d.string(forKey: Keys.dotCorner) ?? "") ?? .topRight

        if let hex = d.string(forKey: Keys.borderColorHex), let color = Color(hexString: hex) {
            borderColor = color
        } else if d.object(forKey: Keys.legacyRed) != nil {
            // Migrate from old per-component storage to hex
            let color = Color(
                red: d.double(forKey: Keys.legacyRed),
                green: d.double(forKey: Keys.legacyGreen),
                blue: d.double(forKey: Keys.legacyBlue),
                opacity: d.double(forKey: Keys.legacyAlpha)
            )
            borderColor = color
            d.set(color.hexString, forKey: Keys.borderColorHex)
            [Keys.legacyRed, Keys.legacyGreen, Keys.legacyBlue, Keys.legacyAlpha]
                .forEach { d.removeObject(forKey: $0) }
        } else {
            borderColor = Color(red: 0.0, green: 0.478, blue: 1.0)
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
