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

    private func redraw() {
        guard let button = statusItem?.button else { return }
        let name = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = controller.isActive ? .controlAccentColor : nil
        button.toolTip = controller.isActive
            ? "Tela não vai escurecer — clique para desativar"
            : "Manter tela acesa"
    }
}
