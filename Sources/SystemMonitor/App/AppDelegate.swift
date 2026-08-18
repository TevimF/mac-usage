import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var menuBarController: MenuBarController?
    private let popoverController = PopoverController()
    private let settingsWindowController = SettingsWindowController()
    private let keepAwakeStatusItemController = KeepAwakeStatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popoverController.attach(settingsWindowController: settingsWindowController)
        menuBarController = MenuBarController(popoverController: popoverController)
    }
}
