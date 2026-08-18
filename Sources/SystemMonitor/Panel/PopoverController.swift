import AppKit
import SwiftUI

/// Hosts the panel in one NSPopover, anchored under the metrics status
/// item (the keep-awake cup toggles directly and never opens this).
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let engine = SystemMetricsEngine.shared
    private var settingsWindowController: TransientWindowController?
    private var aboutWindowController: TransientWindowController?

    func attach(settingsWindowController: TransientWindowController, aboutWindowController: TransientWindowController) {
        self.settingsWindowController = settingsWindowController
        self.aboutWindowController = aboutWindowController
    }

    override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        // .transient closes on a click outside, but not when focus leaves
        // without one (switching apps by keyboard, another window taking
        // over). Closing on the popover window's own key-resign covers
        // those; menus opened from controls inside the panel don't take
        // key status, so this doesn't fire mid-interaction.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelWindowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    @objc private func panelWindowDidResignKey(_ notification: Notification) {
        guard popover.isShown,
              let window = notification.object as? NSWindow,
              window === popover.contentViewController?.view.window else { return }
        popover.performClose(nil)
    }

    /// The SwiftUI content (and its pulsing-dot animation) only exists while
    /// the popover is shown, and is torn down on close. Building it once at
    /// launch kept a `repeatForever` animation ticking on the main thread
    /// forever, even off-screen — measured as sustained double-digit idle
    /// CPU with `sample`(1), the opposite of what this app is supposed to do.
    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        let hosting = NSHostingController(rootView: PanelView(
            onOpenActivityMonitor: { Self.openActivityMonitor() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenAbout: { [weak self] in self?.openAbout() }
        ))
        // Without this, NSHostingController only reports its content size
        // once, before SwiftUI has measured the panel (whose height varies
        // with battery presence, critical state and the process list).
        // NSPopover would then anchor using that wrong size and the real
        // content would grow past the screen edge — that's what pushed the
        // panel off-screen before.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverWillShow(_ notification: Notification) {
        engine.isPanelOpen = true
    }

    func popoverDidClose(_ notification: Notification) {
        // NSPopover's close animation is asynchronous: a quick close+reopen
        // reuses the same instance, so this delegate call for the OLD close
        // can arrive after the NEW popover is already on screen. In that
        // case popover.isShown is true again by the time we get here —
        // ignore the stale notification instead of wiping the visible panel.
        guard !popover.isShown else { return }
        engine.isPanelOpen = false
        popover.contentViewController = nil
    }

    private func openSettings() {
        popover.performClose(nil)
        settingsWindowController?.show()
    }

    private func openAbout() {
        popover.performClose(nil)
        aboutWindowController?.show()
    }

    private static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }
}
