import SwiftUI

@main
struct FocusLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.settings)
        } label: {
            Image(systemName: "rectangle.dashed")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
    }
}
