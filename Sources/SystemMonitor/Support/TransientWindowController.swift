import AppKit
import SwiftUI

/// Window shell shared by Ajustes and Sobre. LSUIElement apps don't get a
/// Dock icon or automatic focus — showing one of these has to explicitly
/// activate the app first, or it opens behind whatever's frontmost. And
/// since the app has no Dock presence to bring a lost window back with,
/// the window closes itself as soon as it stops being the key window
/// (click elsewhere, switch apps) instead of lingering behind other apps.
final class TransientWindowController: NSWindowController, NSWindowDelegate {
    // A closure, not a fixed string: the title follows the app language,
    // which can change between two openings of the same window.
    private var makeTitle: () -> String = { "" }

    convenience init(title: @escaping () -> String, rootView: some View) {
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        makeTitle = title
        window.title = makeTitle()
        window.delegate = self
    }

    func show() {
        window?.title = makeTitle()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.close()
    }
}
