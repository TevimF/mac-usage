import AppKit
import Combine

/// A single fixed status item — a cup that fills in and picks up the accent
/// color when active. Clicking it toggles the assertion directly; it's a
/// standing on/off switch, not a metric, so it doesn't open the panel.
final class KeepAwakeStatusItemController: NSObject {
    private let controller = KeepAwakeController.shared
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
        }
        statusItem = item
        redraw()

        cancellable = controller.$isActive
            .sink { [weak self] _ in self?.redraw() }
    }

    @objc private func clicked() {
        controller.toggle()
    }

    /// Draws into a fixed canvas rather than handing AppKit the raw SF
    /// Symbol image directly — belt and suspenders so the glyph is always
    /// pixel-identically centered between the outline and filled variants,
    /// same as every metric icon already does. The button itself sits in a
    /// `.squareLength` item, so its own frame was never going to move
    /// either way; this just keeps the drawing consistent with the rest of
    /// the app.
    private func redraw() {
        guard let button = statusItem?.button else { return }
        let name = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        let canvasSize = CGSize(width: 22, height: StatusItemContentRenderer.contentHeight)
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let tintColor: NSColor = controller.isActive ? .controlAccentColor : (isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1))
        let image = NSImage(size: canvasSize, flipped: false) { rect in
            guard let symbol else { return true }
            let tinted = symbol.tinted(with: tintColor)
            let origin = CGPoint(x: (rect.width - tinted.size.width) / 2, y: (rect.height - tinted.size.height) / 2)
            tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        button.image = image
        button.toolTip = controller.isActive
            ? "Tela não vai escurecer — clique para desativar"
            : "Manter tela acesa"
    }
}
