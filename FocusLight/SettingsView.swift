import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enable highlighting", isOn: $settings.isEnabled)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Text("Open FocusLight from Spotlight or Finder to return to Settings when the icon is hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                ColorPicker("Color", selection: $settings.borderColor, supportsOpacity: true)

                Picker("Style", selection: $settings.highlightStyle) {
                    ForEach(HighlightStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                // Width / dot size
                LabeledContent(settings.highlightStyle == .dot ? "Dot size" : "Width") {
                    slider($settings.borderWidth, in: 1 ... 20, step: 0.5, unit: "pt")
                }

                // Corner radius — only relevant for full border
                if settings.highlightStyle == .border {
                    LabeledContent("Corner radius") {
                        slider($settings.cornerRadius, in: 0 ... 40, step: 1, unit: "pt", specifier: "%.0f")
                    }
                }

                LabeledContent("Padding") {
                    slider($settings.padding, in: 0 ... 24, step: 0.5, unit: "pt")
                }

                // Corner picker — only for dot style
                if settings.highlightStyle == .dot {
                    Picker("Corner", selection: $settings.dotCorner) {
                        ForEach(DotCorner.allCases) { corner in
                            Text(corner.label).tag(corner)
                        }
                    }
                }
            }

            Section("Configuration") {
                Text("~/.config/FocusLight/config.toml")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text("Settings are saved automatically. Restart FocusLight after editing the file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = settings.configurationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Permissions") {
                Link(destination: URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Accessibility access")
                            Spacer()
                            AccessibilityStatusBadge()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        Text("Required to read the active window position. Grant access in **System Settings › Privacy & Security › Accessibility**.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Accessibility settings")
                .accessibilityHint("Opens Accessibility permissions in System Settings")
            }

            Section {
                Button("Quit FocusLight") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.vertical, 8)
        .animation(.default, value: settings.highlightStyle)
    }

    @ViewBuilder
    private func slider(
        _ value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        unit: String,
        specifier: String = "%.1f"
    ) -> some View {
        HStack {
            Slider(value: value, in: range, step: step)
            Text("\(value.wrappedValue, specifier: specifier) \(unit)")
                .frame(width: 52, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct AccessibilityStatusBadge: View {
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(trusted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(trusted ? "Granted" : "Not granted")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = AXIsProcessTrusted()
        }
    }
}
