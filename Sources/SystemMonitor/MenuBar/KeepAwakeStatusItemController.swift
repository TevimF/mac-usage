import AppKit
import Combine

/// A single fixed status item — an empty cup when off, a full one (with
/// rising vapor) when on. Left click toggles the assertion directly; right
/// click opens the duration menu — it's a standing on/off switch plus one
/// alternate action, not a metric, so it doesn't open the panel.
final class KeepAwakeStatusItemController: NSObject {
    private let controller = KeepAwakeController.shared
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?
    private var toolTipTag: NSView.ToolTipTag?
    private var vaporLayers: [CAShapeLayer] = []
    private var appearanceObservation: NSKeyValueObservation?

    override init() {
        super.init()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            toolTipTag = button.addToolTip(NSRect(x: 0, y: 0, width: 240, height: 30), owner: self, userData: nil)
            // Unlike the metrics item, nothing else ever redraws this one —
            // without this, flipping the system between light and dark left
            // the cup in the old appearance's color until the next toggle.
            appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.redraw(isActive: self.controller.isActive)
                }
            }
        }
        statusItem = item
        redraw(isActive: controller.isActive)

        // @Published fires from willSet, so the property still holds the old
        // value while this runs — the state has to come from the event, not
        // from a fresh read, or the cup draws the opposite of what the
        // assertion is actually doing.
        cancellable = controller.$isActive
            .sink { [weak self] isActive in self?.redraw(isActive: isActive) }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showDurationMenu()
        } else {
            controller.toggle()
        }
    }

    /// Section 07's "clique longo ou botão direito = duração" — right click
    /// is the one implemented here. A true press-and-hold gesture on an
    /// `NSStatusBarButton` needs its own mouse-down timer and local event
    /// monitor; right click already reaches the same menu through a
    /// standard, discoverable macOS affordance, so that extra plumbing was
    /// left out rather than duplicating it.
    private func showDurationMenu() {
        guard let statusItem, let button = statusItem.button else { return }
        let menu = NSMenu()
        let header = NSMenuItem(title: L10n.t("Manter ativa por", "Keep awake for"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        for duration in KeepAwakeDuration.allCases {
            let item = NSMenuItem(title: duration.label, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration
            item.state = AppSettings.shared.keepAwakeDuration == duration ? .on : .off
            menu.addItem(item)
        }
        // Attaching a menu directly makes every click open it, so it's set
        // just for this one presentation and cleared right after — the
        // same trick PopoverController-adjacent status items use to keep
        // left click on the plain target/action path.
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? KeepAwakeDuration else { return }
        AppSettings.shared.keepAwakeDuration = duration
    }

    private func redraw(isActive: Bool) {
        guard let button = statusItem?.button else { return }
        let canvasSize = CGSize(width: 21, height: StatusItemContentRenderer.contentHeight)
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        // Same neutral color whether it's on or off — state is the shape
        // (outline vs. filled), not a recolor.
        let cupColor = isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1)

        let image = NSImage(size: canvasSize, flipped: false) { rect in
            CoffeeCupIcon.draw(in: rect, filled: isActive, cupColor: cupColor)
            return true
        }
        button.image = image

        if vaporLayers.isEmpty {
            setUpVaporLayers(in: button, canvasSize: canvasSize)
        }
        // Same neutral as the cup, re-applied here because the menu bar's
        // light/dark appearance can change while the layers already exist —
        // a fixed white stroke was invisible against a light menu bar.
        vaporLayers.forEach { $0.strokeColor = cupColor.withAlphaComponent(0.85).cgColor }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard isActive, !reduceMotion else {
            vaporLayers.forEach {
                $0.removeAllAnimations()
                $0.opacity = 0
            }
            return
        }
        for (index, layer) in vaporLayers.enumerated() where layer.animation(forKey: "vaporOpacity") == nil {
            startVaporAnimation(on: layer, delay: index == 0 ? 0 : 0.9)
        }
    }

    /// Two small rising, fading wisps above the cup's rim — the app's one
    /// animated menu bar element. Built as `CAShapeLayer`s on the button's
    /// own layer (not redrawn into the bitmap) so the loop runs on the
    /// render server instead of costing a Swift-side redraw every frame.
    private func setUpVaporLayers(in button: NSStatusBarButton, canvasSize: CGSize) {
        button.wantsLayer = true
        guard let hostLayer = button.layer else { return }
        vaporLayers.forEach { $0.removeFromSuperlayer() }
        vaporLayers.removeAll()

        let scale = min(canvasSize.width, canvasSize.height) / CoffeeCupIcon.designSize
        let offsetX = (canvasSize.width - CoffeeCupIcon.designSize * scale) / 2
        let offsetY = (canvasSize.height - CoffeeCupIcon.designSize * scale) / 2

        // Design-space (24-unit, y-down) origins for the two wisps, just
        // above the cup's rim at y≈8.5 — matches CoffeeCupIcon's own space
        // so the vapor lines up with the cup regardless of button size.
        for originX: CGFloat in [8.9, 12.4] {
            let start = CGPoint(x: offsetX + originX * scale, y: offsetY + 5.8 * scale)
            let end = CGPoint(x: offsetX + (originX + 1.3) * scale, y: offsetY + 2 * scale)
            let path = CGMutablePath()
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x - 1.4 * scale, y: (start.y + end.y) / 2),
                control2: CGPoint(x: end.x + 1.2 * scale, y: (start.y + end.y) / 2)
            )
            let layer = CAShapeLayer()
            layer.path = path
            // Stroke color is applied by redraw(isActive:), which re-tints
            // on every appearance change.
            layer.fillColor = nil
            layer.lineWidth = max(1, 1.3 * scale)
            layer.lineCap = .round
            layer.opacity = 0
            hostLayer.addSublayer(layer)
            vaporLayers.append(layer)
        }
    }

    private func startVaporAnimation(on layer: CAShapeLayer, delay: CFTimeInterval) {
        let easeOut = CAMediaTimingFunction(name: .easeOut)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.95, 0]
        opacity.keyTimes = [0, 0.3, 1]
        opacity.duration = 2.6
        opacity.timingFunction = easeOut
        opacity.repeatCount = .infinity
        opacity.beginTime = CACurrentMediaTime() + delay

        let rise = CABasicAnimation(keyPath: "transform.translation.y")
        rise.fromValue = 2.5
        rise.toValue = -5
        rise.duration = 2.6
        rise.timingFunction = easeOut
        rise.repeatCount = .infinity
        rise.beginTime = CACurrentMediaTime() + delay

        layer.add(opacity, forKey: "vaporOpacity")
        layer.add(rise, forKey: "vaporRise")
    }
}

extension KeepAwakeStatusItemController: NSViewToolTipOwner {
    // Computed on demand (like MenuBarController's metric tooltips) rather
    // than cached in button.toolTip, since AppKit won't refresh an
    // already-visible tooltip string on its own — a hover held past a
    // minute-mark would otherwise show a remaining time that's stuck.
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard controller.isActive else {
            return L10n.t(
                "Manter tela acesa — botão direito para escolher a duração",
                "Keep the screen awake — right click to choose the duration"
            )
        }
        guard let remaining = controller.remainingSeconds else {
            return L10n.t(
                "Tela não vai escurecer — clique para desativar, botão direito para duração",
                "Screen will stay on — click to turn off, right click for duration"
            )
        }
        let time = Formatting.duration(minutes: max(1, Int(remaining / 60)))
        return L10n.t(
            "Tela não vai escurecer · \(time) restantes — clique para desativar",
            "Screen will stay on · \(time) remaining — click to turn off"
        )
    }
}
