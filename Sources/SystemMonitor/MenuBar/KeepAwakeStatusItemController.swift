import AppKit
import Combine

/// A single fixed status item — a cup, empty when off, with coffee and
/// steam when on. Clicking it toggles the assertion directly; it's a
/// standing on/off switch, not a metric, so it doesn't open the panel.
final class KeepAwakeStatusItemController: NSObject {
    private let controller = KeepAwakeController.shared
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?
    private var toolTipTag: NSView.ToolTipTag?

    override init() {
        super.init()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            toolTipTag = button.addToolTip(NSRect(x: 0, y: 0, width: 200, height: 30), owner: self, userData: nil)
        }
        statusItem = item
        redraw()

        cancellable = controller.$isActive
            .sink { [weak self] _ in self?.redraw() }
    }

    @objc private func clicked() {
        controller.toggle()
    }

    private func redraw() {
        guard let button = statusItem?.button else { return }
        let canvasSize = CGSize(width: 22, height: StatusItemContentRenderer.contentHeight)
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        // The outline stays the same neutral color whether it's on or off —
        // state is shown by what's drawn inside the cup, not by recoloring
        // the cup itself.
        let cupColor = isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1)
        let coffeeColor = NSColor(red: 0.62, green: 0.40, blue: 0.20, alpha: 1)
        let steamColor = cupColor.withAlphaComponent(0.55)
        let isActive = controller.isActive

        let image = NSImage(size: canvasSize, flipped: false) { rect in
            CoffeeCupIcon.draw(in: rect, steaming: isActive, cupColor: cupColor, coffeeColor: coffeeColor, steamColor: steamColor)
            return true
        }
        button.image = image
    }
}

extension KeepAwakeStatusItemController: NSViewToolTipOwner {
    // Computed on demand (like MenuBarController's metric tooltips) rather
    // than cached in button.toolTip, since AppKit won't refresh an
    // already-visible tooltip string on its own — a hover held past a
    // minute-mark would otherwise show a remaining time that's stuck.
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard controller.isActive else { return "Manter tela acesa" }
        guard let remaining = controller.remainingSeconds else {
            return "Tela não vai escurecer — clique para desativar"
        }
        let minutes = max(1, Int(remaining / 60))
        return "Tela não vai escurecer · \(Formatting.duration(minutes: minutes)) restantes — clique para desativar"
    }
}
