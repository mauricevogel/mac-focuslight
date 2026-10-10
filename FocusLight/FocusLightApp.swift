import AppKit

@main
enum FocusLightApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // AppKit owns the lifecycle so removing the status item never ends highlighting.
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
