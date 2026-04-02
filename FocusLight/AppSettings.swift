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
        didSet { persistColor(borderColor) }
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let highlightStyle = "highlightStyle"
        static let borderWidth = "borderWidth"
        static let padding = "padding"
        static let cornerRadius = "cornerRadius"
        static let dotCorner = "dotCorner"
        static let red = "colorRed"
        static let green = "colorGreen"
        static let blue = "colorBlue"
        static let alpha = "colorAlpha"
    }

    private init() {
        let d = UserDefaults.standard
        isEnabled = (d.object(forKey: Keys.isEnabled) as? Bool) ?? true
        highlightStyle = HighlightStyle(rawValue: d.string(forKey: Keys.highlightStyle) ?? "") ?? .border
        borderWidth = (d.object(forKey: Keys.borderWidth) as? Double) ?? 4.0
        padding = (d.object(forKey: Keys.padding) as? Double) ?? 0.0
        cornerRadius = (d.object(forKey: Keys.cornerRadius) as? Double) ?? 8.0
        dotCorner = DotCorner(rawValue: d.string(forKey: Keys.dotCorner) ?? "") ?? .topRight

        if d.object(forKey: Keys.red) != nil {
            borderColor = Color(
                red: d.double(forKey: Keys.red),
                green: d.double(forKey: Keys.green),
                blue: d.double(forKey: Keys.blue),
                opacity: d.double(forKey: Keys.alpha)
            )
        } else {
            borderColor = Color(red: 0.0, green: 0.478, blue: 1.0)
        }
    }

    private func persistColor(_ color: Color) {
        guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return }
        UserDefaults.standard.set(Double(ns.redComponent), forKey: Keys.red)
        UserDefaults.standard.set(Double(ns.greenComponent), forKey: Keys.green)
        UserDefaults.standard.set(Double(ns.blueComponent), forKey: Keys.blue)
        UserDefaults.standard.set(Double(ns.alphaComponent), forKey: Keys.alpha)
    }

    var nsColor: NSColor {
        NSColor(borderColor).usingColorSpace(.deviceRGB) ?? .systemBlue
    }
}
