import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Toggle("Enable Highlighting", isOn: $settings.isEnabled)
        Divider()
        SettingsLink()
        Divider()
        Button("Quit FocusLight") {
            NSApplication.shared.terminate(nil)
        }
    }
}
