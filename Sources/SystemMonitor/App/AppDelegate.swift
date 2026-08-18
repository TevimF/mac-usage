import Cocoa
import SwiftUI

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
    private let settingsWindowController = TransientWindowController(
        title: { L10n.t("Ajustes — Mac usage", "Settings — Mac usage") },
        rootView: SettingsView()
    )
    private let aboutWindowController = TransientWindowController(
        title: { L10n.t("Sobre o Mac usage", "About Mac usage") },
        rootView: AboutView()
    )
    private let keepAwakeStatusItemController = KeepAwakeStatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popoverController.attach(settingsWindowController: settingsWindowController, aboutWindowController: aboutWindowController)
        menuBarController = MenuBarController(popoverController: popoverController)
    }
}
