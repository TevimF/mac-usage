import AppKit

/// Composes the full drawing for one NSStatusItem's button.image — icon(s)
/// and value text, all in one bitmap, all in a single flat row.
///
/// There used to be a taller two-line block for dual-value metrics (network
/// down/up, disk read/write), and a mode that stacked that block under a row
/// of single-value metrics. Both got removed: the menu bar's content height
/// is fixed, and an image taller than that doesn't grow the row — it just
/// gets vertically centered/clipped against whatever's next to it, which is
/// what made items look like they were drawn on top of each other once a
/// slot held more than two metrics. Every metric now contributes to the same
/// single row instead: one icon+value chip for a single-value metric, two
/// adjacent chips (no divider between them) for a dual-value one, with a
/// divider between different metrics.
///
/// Images are non-template (explicit colors) rather than auto-tinted:
/// the design calls for real accent/critical color in the bar, not just
/// system monochrome, so we track the menu bar's own light/dark appearance
/// ourselves and pick matching text/icon colors — the one place we
/// deliberately diverge from the "mark as template image" note, which only
/// covers the plain single-color case.
enum StatusItemContentRenderer {
    static let contentHeight: CGFloat = 18
    private static let iconPointSize: CGFloat = 12
    private static let smallIconPointSize: CGFloat = 9
    private static let sparklineSize = CGSize(width: 22, height: 12)
    /// Kept at zero: macOS already pads each status item (and on macOS 26
    /// wraps it in its own glass capsule). Any padding baked into the image
    /// stacks on top of the system's, and between two adjacent items it
    /// doubles — which is what made the four metrics look split into two
    /// far-apart clusters.
    private static let sidePadding: CGFloat = 0
    private static let gap: CGFloat = 4
    private static let chipGap: CGFloat = 3

    static func render(slot: StatusItemSlot, sample: MetricSample, style: IconStyle, accent: NSColor, isDark: Bool) -> NSImage {
        let metrics = slot.metrics.filter { $0.isAvailable }
        guard let first = metrics.first else { return blank() }

        if metrics.count == 1, !first.isDualValue {
            return renderSingle(metric: first, sample: sample, style: style, accent: accent, isDark: isDark)
        }
        return renderRow(metrics: metrics, sample: sample, isDark: isDark)
    }

    // MARK: - Lone single-value metric (styles A/B/C)

    private static func renderSingle(metric: MetricKind, sample: MetricSample, style: IconStyle, accent: NSColor, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let valueText = valueString(for: metric, sample: sample)
        let icon = MetricIconLibrary.image(for: metric, pointSize: iconPointSize, sample: sample)
        let showSparkline = style != .numeric && metric == .cpu && sample.cpuHistory.count >= 2
        let showIcon = style != .sparkline || !showSparkline
        let showText = style != .sparkline && !valueText.isEmpty

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let textSize = showText ? valueText.size(withAttributes: textAttrs) : .zero

        var width: CGFloat = sidePadding
        if showIcon { width += iconPointSize }
        if showIcon && showSparkline { width += gap }
        if showSparkline { width += sparklineSize.width }
        if (showIcon || showSparkline) && showText { width += gap }
        width += showText ? textSize.width : 0
        width += sidePadding
        width = max(width, 20)

        let size = CGSize(width: width.rounded(.up) + 1, height: contentHeight)
        return NSImage(size: size, flipped: false) { rect in
            var x = sidePadding
            if showIcon {
                let iconColor = iconTintColor(metric: metric, sample: sample, base: textColor)
                let tinted = icon.tinted(with: iconColor)
                let y = (rect.height - icon.size.height) / 2
                tinted.draw(at: CGPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1)
                x += iconPointSize
                if showSparkline { x += gap }
            }
            if showSparkline, let ctx = NSGraphicsContext.current?.cgContext {
                let sparkRect = CGRect(x: x, y: (rect.height - sparklineSize.height) / 2, width: sparklineSize.width, height: sparklineSize.height)
                SparklineRenderer.draw(history: sample.cpuHistory, in: sparkRect, context: ctx, strokeColor: accent, fillColor: accent)
                x += sparklineSize.width
            }
            if showText {
                if showIcon || showSparkline { x += gap }
                let y = (rect.height - textSize.height) / 2
                valueText.draw(at: CGPoint(x: x, y: y), withAttributes: textAttrs)
            }
            return true
        }
    }

    // MARK: - Everything else: one flat row, e.g. CPU | RAM | Swap | ↓↑Disk

    private struct Chip {
        let icon: NSImage
        let text: String
    }

    private static func renderRow(metrics: [MetricKind], sample: MetricSample, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        // Dual-value metrics contribute two chips (down, up) with no divider
        // between them, so they stay visually grouped as one reading; a
        // divider only separates different metrics.
        let groups: [[Chip]] = metrics.map { metric in
            if metric.isDualValue {
                let (down, up) = dualValues(for: metric, sample: sample)
                return [
                    Chip(icon: MetricIconLibrary.image(named: "arrow.down", pointSize: smallIconPointSize), text: Formatting.mbps(down)),
                    Chip(icon: MetricIconLibrary.image(named: "arrow.up", pointSize: smallIconPointSize), text: Formatting.mbps(up))
                ]
            }
            return [Chip(
                icon: MetricIconLibrary.image(for: metric, pointSize: smallIconPointSize, sample: sample),
                text: valueString(for: metric, sample: sample)
            )]
        }

        func chipWidth(_ chip: Chip) -> CGFloat {
            smallIconPointSize + chipGap + chip.text.size(withAttributes: textAttrs).width
        }

        let dividerWidth: CGFloat = 1
        var width: CGFloat = sidePadding
        for (groupIndex, group) in groups.enumerated() {
            for (chipIndex, chip) in group.enumerated() {
                width += chipWidth(chip)
                if chipIndex < group.count - 1 { width += chipGap }
            }
            if groupIndex < groups.count - 1 { width += gap + dividerWidth + gap }
        }
        width += sidePadding

        let size = CGSize(width: width.rounded(.up) + 1, height: contentHeight)
        return NSImage(size: size, flipped: false) { rect in
            var x = sidePadding
            for (groupIndex, group) in groups.enumerated() {
                for (chipIndex, chip) in group.enumerated() {
                    let tinted = chip.icon.tinted(with: textColor)
                    let iconY = (rect.height - tinted.size.height) / 2
                    tinted.draw(at: CGPoint(x: x, y: iconY), from: .zero, operation: .sourceOver, fraction: 1)
                    x += smallIconPointSize + chipGap

                    let textSize = chip.text.size(withAttributes: textAttrs)
                    let textY = (rect.height - textSize.height) / 2
                    chip.text.draw(at: CGPoint(x: x, y: textY), withAttributes: textAttrs)
                    x += textSize.width
                    if chipIndex < group.count - 1 { x += chipGap }
                }
                if groupIndex < groups.count - 1 {
                    x += gap
                    textColor.withAlphaComponent(0.3).setFill()
                    NSRect(x: x, y: 3, width: dividerWidth, height: rect.height - 6).fill()
                    x += dividerWidth + gap
                }
            }
            return true
        }
    }

    // MARK: - Helpers

    private static func blank() -> NSImage {
        NSImage(size: CGSize(width: 1, height: contentHeight))
    }

    /// Down-value / up-value pair for whichever dual-value metric is being
    /// rendered — network's incoming/outgoing throughput, or disk's
    /// read/write throughput.
    private static func dualValues(for metric: MetricKind, sample: MetricSample) -> (down: Double, up: Double) {
        switch metric {
        case .diskIO: return (sample.diskReadRate, sample.diskWriteRate)
        default: return (sample.networkDownRate, sample.networkUpRate)
        }
    }

    private static func valueString(for metric: MetricKind, sample: MetricSample) -> String {
        switch metric {
        case .cpu: return "\(Formatting.percent(sample.cpuPercent))%"
        case .ram: return "\(Formatting.percent(sample.memoryFraction * 100))%"
        case .swap:
            guard sample.swapTotalGB > 0 else { return "0%" }
            return "\(Formatting.percent(sample.swapUsedGB / sample.swapTotalGB * 100))%"
        case .disk: return "\(Formatting.percent(sample.diskFraction * 100))%"
        case .thermal: return ""
        case .battery: return sample.batteryPercent.map { "\($0)%" } ?? "—"
        case .network, .diskIO: return ""
        case .gpu: return ""
        }
    }

    private static func foregroundColor(isDark: Bool, isCritical: Bool) -> NSColor {
        if isCritical { return NSColor(red: 1, green: 0.29, blue: 0.23, alpha: 1) } // #FF453A
        return isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1)
    }

    private static func iconTintColor(metric: MetricKind, sample: MetricSample, base: NSColor) -> NSColor {
        if metric == .thermal {
            switch sample.thermalState {
            case .nominal, .fair: return base
            case .serious: return NSColor(red: 1, green: 0.62, blue: 0.04, alpha: 1) // #FF9F0A
            case .critical: return NSColor(red: 1, green: 0.29, blue: 0.23, alpha: 1) // #FF453A
            }
        }
        return base
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            color.set()
            rect.fill()
            self.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        image.isTemplate = false
        return image
    }
}
