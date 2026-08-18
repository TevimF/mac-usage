import AppKit
import Combine

/// Owns every NSStatusItem the app shows. Rebuilding the array only happens
/// when the user edits Settings (cheap, infrequent); on every metrics tick
/// we just redraw each item's existing button image.
final class MenuBarController: NSObject {
    private let settings = AppSettings.shared
    private let engine = SystemMetricsEngine.shared
    private let popoverController: PopoverController

    private var statusItems: [NSStatusItem] = []
    private var cancellables: Set<AnyCancellable> = []
    private var appearanceObservation: NSKeyValueObservation?
    // AppKit caches a plain `button.toolTip` string the moment the tooltip
    // first appears and won't refresh it while the mouse stays put, so a
    // hover held across a tick showed stale numbers. NSViewToolTipOwner is
    // asked for the string fresh each time the tooltip is (re)displayed.
    private var toolTipSlots: [NSView.ToolTipTag: StatusItemSlot] = [:]

    init(popoverController: PopoverController) {
        self.popoverController = popoverController
        super.init()

        // Editing status items in Settings (each "+"/"x" tap, each add/remove
        // slot) reassigns the whole array, and each reassignment on its own
        // tears down and recreates every NSStatusItem. Composing a new
        // layout is several edits in a row, and firing a full remove+recreate
        // cycle for each one back-to-back is what left the old item's pixels
        // ghosted on screen — AppKit doesn't always get a clean repaint
        // between such rapid-fire menu bar churn. Debouncing collapses a
        // burst of edits into the one rebuild that reflects where they land.
        settings.$statusItemSlots
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildStatusItems() }
            .store(in: &cancellables)

        settings.$iconStyle
            .dropFirst()
            .sink { [weak self] _ in self?.redrawAll() }
            .store(in: &cancellables)

        settings.$accent
            .dropFirst()
            .sink { [weak self] _ in self?.redrawAll() }
            .store(in: &cancellables)

        engine.$sample
            .sink { [weak self] _ in self?.redrawAll() }
            .store(in: &cancellables)
    }

    private func rebuildStatusItems() {
        for item in statusItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
        toolTipSlots.removeAll()

        let slots = settings.statusItemSlots.isEmpty
            ? [StatusItemSlot(metrics: [.cpu])]
            : settings.statusItemSlots

        for slot in slots {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.imagePosition = .imageOnly
                button.target = self
                button.action = #selector(statusItemClicked(_:))
                // Wider than any real status item so it still covers the
                // button after redrawAll resizes the image.
                let tag = button.addToolTip(NSRect(x: 0, y: 0, width: 400, height: 30), owner: self, userData: nil)
                toolTipSlots[tag] = slot
            }
            statusItems.append(item)
        }
        redrawAll()
    }

    private func redrawAll() {
        let sample = engine.sample
        let accent = NSColor(hex: settings.accent.rawValue) ?? .systemCyan
        let slots = settings.statusItemSlots.isEmpty
            ? [StatusItemSlot(metrics: [.cpu])]
            : settings.statusItemSlots

        for (index, item) in statusItems.enumerated() {
            guard index < slots.count, let button = item.button else { continue }
            let slot = slots[index]
            let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            button.image = StatusItemContentRenderer.render(
                slot: slot,
                sample: sample,
                style: settings.iconStyle,
                accent: accent,
                isDark: isDark
            )
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        popoverController.toggle(relativeTo: sender)
    }
}

extension MenuBarController: NSViewToolTipOwner {
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard let slot = toolTipSlots[tag] else { return "" }
        return StatusItemTooltip.text(for: slot, sample: engine.sample)
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        guard hexString.count == 6, let value = UInt32(hexString, radix: 16) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
