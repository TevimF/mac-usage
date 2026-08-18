import AppKit
import Combine

/// Owns the app's one metrics `NSStatusItem` — the combined pill showing
/// the first two entries of `AppSettings.metricOrder` (design v2, section
/// 08: "as duas primeiras ficam visíveis; o resto vive no painel"). Unlike
/// the old per-slot model, the item count never changes, so there's no more
/// remove/recreate dance — reordering just redraws the same item's image.
final class MenuBarController: NSObject {
    private let settings = AppSettings.shared
    private let engine = SystemMetricsEngine.shared
    private let popoverController: PopoverController

    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private var appearanceObservation: NSKeyValueObservation?
    // AppKit caches a plain `button.toolTip` string the moment the tooltip
    // first appears and won't refresh it while the mouse stays put, so a
    // hover held across a tick showed stale numbers. NSViewToolTipOwner is
    // asked for the string fresh each time the tooltip is (re)displayed.
    private var toolTipTag: NSView.ToolTipTag?

    init(popoverController: PopoverController) {
        self.popoverController = popoverController
        super.init()

        buildStatusItem()

        settings.$metricOrder
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        settings.$barMetricCount
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        settings.$iconStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        settings.$accent
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        settings.$iconColorMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        engine.$sample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            // Wider than any real status item so it still covers the
            // button after redraw() resizes the image.
            toolTipTag = button.addToolTip(NSRect(x: 0, y: 0, width: 400, height: 30), owner: self, userData: nil)
            // The image bakes in light/dark-specific colors, so a system
            // appearance flip has to trigger a redraw now — waiting for the
            // next metrics tick left the old colors up for up to 5s.
            appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                DispatchQueue.main.async { self?.redraw() }
            }
        }
        statusItem = item
        redraw()
    }

    private var barMetrics: [MetricKind] {
        Array(settings.metricOrder.prefix(settings.barMetricCount))
    }

    private func redraw() {
        guard let button = statusItem?.button else { return }
        let accent = NSColor(hex: settings.accent.rawValue) ?? .systemCyan
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        button.image = StatusItemContentRenderer.render(
            metrics: barMetrics,
            sample: engine.sample,
            style: settings.iconStyle,
            accent: accent,
            colorMode: settings.iconColorMode,
            isDark: isDark
        )
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        popoverController.toggle(relativeTo: sender)
    }
}

extension MenuBarController: NSViewToolTipOwner {
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard tag == toolTipTag else { return "" }
        return StatusItemTooltip.text(for: barMetrics, sample: engine.sample)
    }
}
