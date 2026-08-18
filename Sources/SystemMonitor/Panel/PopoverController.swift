import AppKit
import SwiftUI

/// Hosts the single shared panel in one NSPopover. Every status item opens
/// the same widget; clicking a different item just re-anchors it under that
/// icon rather than spawning a second panel.
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let engine = SystemMetricsEngine.shared
    private var settingsWindowController: SettingsWindowController?
    private weak var anchorButton: NSStatusBarButton?

    func attach(settingsWindowController: SettingsWindowController) {
        self.settingsWindowController = settingsWindowController
    }

    override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    /// The SwiftUI content (and its pulsing-dot animation) only exists while
    /// the popover is shown, and is torn down on close. Building it once at
    /// launch kept a `repeatForever` animation ticking on the main thread
    /// forever, even off-screen — measured as sustained double-digit idle
    /// CPU with `sample`(1), the opposite of what this app is supposed to do.
    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            let wasSameButton = anchorButton === button
            popover.performClose(nil)
            if wasSameButton { return }
        }

        let hosting = NSHostingController(rootView: PanelView(
            onOpenActivityMonitor: { Self.openActivityMonitor() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        ))
        // Without this, NSHostingController only reports its content size
        // once, before SwiftUI has measured the panel (whose height varies
        // with battery presence, critical state and the process list).
        // NSPopover would then anchor using that wrong size and the real
        // content would grow past the screen edge — that's what pushed the
        // panel off-screen before.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        anchorButton = button
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverWillShow(_ notification: Notification) {
        engine.isPanelOpen = true
    }

    func popoverDidClose(_ notification: Notification) {
        // NSPopover's close animation is asynchronous: switching to a
        // different status item calls performClose() and then immediately
        // shows a new popover on the same instance, so this delegate call
        // for the OLD close can arrive after the NEW one is already on
        // screen. If that already happened, popover.isShown is true again
        // by the time we get here — ignore the stale notification instead
        // of wiping the panel that's currently visible.
        guard !popover.isShown else { return }
        engine.isPanelOpen = false
        popover.contentViewController = nil
        anchorButton = nil
    }

    private func openSettings() {
        popover.performClose(nil)
        settingsWindowController?.show()
    }

    private static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }
}
