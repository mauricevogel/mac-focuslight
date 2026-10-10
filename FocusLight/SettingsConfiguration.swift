import Foundation

/// The flat TOML schema used by FocusLight. Only the scalar types needed by settings are supported.
struct SettingsConfiguration: Equatable {
    var isEnabled = true
    var highlightStyle = HighlightStyle.border
    var borderWidth = 4.0
    var padding = 0.0
    var cornerRadius = 8.0
    var dotCorner = DotCorner.topRight
    var borderColorHex = "#007AFFFF"

    var toml: String {
        """
        # FocusLight configuration. Restart the app after editing this file.
        # Changes in the app rewrite this file with the current settings.
        is_enabled = \(isEnabled)
        highlight_style = "\(highlightStyle.rawValue)" # border, top, bottom, left, right, dot
        border_width = \(borderWidth) # 1–20 pt; also controls dot size
        padding = \(padding) # 0–24 pt
        corner_radius = \(cornerRadius) # 0–40 pt
        dot_corner = "\(dotCorner.rawValue)" # topLeft, topRight, bottomLeft, bottomRight
        border_color = "\(borderColorHex)" # #RRGGBB or #RRGGBBAA

        """
    }

    init() {}

    init(toml: String) throws {
        self.init()
        var seen = Set<String>()

        for (index, rawLine) in toml.components(separatedBy: "\n").enumerated() {
            let lineNumber = index + 1
            let line = Self.removingComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let separator = line.firstIndex(of: "=") else {
                throw ConfigurationError(line: lineNumber, message: "Expected a key = value setting.")
            }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard seen.insert(key).inserted else {
                throw ConfigurationError(line: lineNumber, message: "Duplicate setting '\(key)'.")
            }

            func invalid(_ expected: String) -> ConfigurationError {
                ConfigurationError(line: lineNumber, message: "'\(key)' must be \(expected).")
            }

            switch key {
            case "is_enabled":
                guard value == "true" || value == "false" else { throw invalid("true or false") }
                isEnabled = value == "true"
            case "highlight_style":
                guard let string = Self.quotedString(value), let style = HighlightStyle(rawValue: string) else {
                    throw invalid("one of \"border\", \"top\", \"bottom\", \"left\", \"right\", or \"dot\"")
                }
                highlightStyle = style
            case "dot_corner":
                guard let string = Self.quotedString(value), let corner = DotCorner(rawValue: string) else {
                    throw invalid("one of \"topLeft\", \"topRight\", \"bottomLeft\", or \"bottomRight\"")
                }
                dotCorner = corner
            case "border_color":
                guard let string = Self.quotedString(value), Self.isValidColorHex(string) else {
                    throw invalid("a quoted hex color such as \"#007AFFFF\" (#RRGGBB or #RRGGBBAA)")
                }
                borderColorHex = string
            case "border_width", "padding", "corner_radius":
                let range: ClosedRange<Double>
                switch key {
                case "border_width": range = 1 ... 20
                case "padding": range = 0 ... 24
                default: range = 0 ... 40
                }
                // TOML decimal integers and floats, including exponents and digit separators.
                let pattern = #"^[+-]?(0|[1-9](?:_?[0-9])*)(?:\.[0-9](?:_?[0-9])*)?(?:[eE][+-]?[0-9](?:_?[0-9])*)?$"#
                guard value.range(of: pattern, options: .regularExpression) != nil,
                      let number = Double(value.replacingOccurrences(of: "_", with: "")),
                      number.isFinite, range.contains(number) else {
                    throw invalid("a number from \(range.lowerBound) to \(range.upperBound)")
                }
                switch key {
                case "border_width": borderWidth = number
                case "padding": padding = number
                default: cornerRadius = number
                }
            default:
                throw ConfigurationError(line: lineNumber, message: "Unknown setting '\(key)'. Use the documented top-level keys.")
            }
        }
    }

    static func isValidColorHex(_ value: String) -> Bool {
        value.range(of: #"^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$"#, options: .regularExpression) != nil
    }

    // Settings values are simple identifiers or hex colors; escaped/multiline strings are unnecessary.
    private static func quotedString(_ value: String) -> String? {
        guard value.count >= 2, let quote = value.first, quote == "\"" || quote == "'",
              value.last == quote else { return nil }
        let content = String(value.dropFirst().dropLast())
        guard !content.contains(quote), quote != "\"" || !content.contains("\\"),
              content.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else { return nil }
        return content
    }

    private static func removingComment(from line: String) -> String {
        var quote: Character?
        var escaped = false
        for index in line.indices {
            let character = line[index]
            if escaped {
                escaped = false
            } else if quote == "\"", character == "\\" {
                escaped = true
            } else if let currentQuote = quote {
                if character == currentQuote { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "#" {
                return String(line[..<index])
            }
        }
        return line
    }
}

private struct ConfigurationError: LocalizedError {
    let line: Int
    let message: String

    var errorDescription: String? { "Line \(line): \(message)" }
}
