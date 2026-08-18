import AppKit

/// Composes the full drawing for one NSStatusItem's button.image — icon(s),
/// optional sparkline, and value text, all in one bitmap so we have full
/// control over the layout: a single capsule, several single-value metrics
/// side by side with dividers, a two-line read/write or down/up block for
/// dual-value metrics, or — when a slot mixes both kinds — those stacked
/// into one item.
///
/// Images are non-template (explicit colors) rather than auto-tinted:
/// the design calls for real accent/critical color in the bar, not just
/// system monochrome, so we track the menu bar's own light/dark appearance
/// ourselves and pick matching text/icon colors — the one place we
/// deliberately diverge from the "mark as template image" note, which only
/// covers the plain single-color case.
enum StatusItemContentRenderer {
    static let contentHeight: CGFloat = 18
    static let twoLineHeight: CGFloat = 28
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

    /// A slot can hold up to 4 metrics. A lone single-value metric keeps its
    /// full icon-style treatment (numeric/sparkline/capsule); anything wider
    /// than that splits into rows and stacks them — every single-value
    /// metric shares one icon+value row, and each dual-value metric (network,
    /// disk) gets its own two-line block, so e.g. CPU+RAM+Swap+Disk renders
    /// as one item: a row of three percentages over a read/write block.
    static func render(slot: StatusItemSlot, sample: MetricSample, style: IconStyle, accent: NSColor, isDark: Bool) -> NSImage {
        let metrics = slot.metrics.filter { $0.isAvailable }
        guard let first = metrics.first else { return blank() }

        if metrics.count == 1 {
            if first.isDualValue {
                return renderTwoLineRow(metric: first, sample: sample, isDark: isDark)
            }
            return renderSingle(metric: first, sample: sample, style: style, accent: accent, isDark: isDark)
        }

        let singleMetrics = metrics.filter { !$0.isDualValue }
        let dualMetrics = metrics.filter(\.isDualValue)

        var rows: [NSImage] = []
        if !singleMetrics.isEmpty {
            rows.append(renderSideBySideRow(metrics: singleMetrics, sample: sample, isDark: isDark))
        }
        for metric in dualMetrics {
            rows.append(renderTwoLineRow(metric: metric, sample: sample, isDark: isDark))
        }
        return stack(rows)
    }

    // MARK: - Single metric (styles A/B/C)

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

    // MARK: - Single-value metrics side by side, e.g. CPU | RAM | Swap

    private static func renderSideBySideRow(metrics: [MetricKind], sample: MetricSample, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        let items = metrics.map { metric -> (NSImage, String, CGFloat) in
            let icon = MetricIconLibrary.image(for: metric, pointSize: smallIconPointSize, sample: sample)
            let text = valueString(for: metric, sample: sample)
            let textWidth = text.size(withAttributes: textAttrs).width
            return (icon, text, textWidth)
        }

        let dividerWidth: CGFloat = 1
        var width: CGFloat = sidePadding
        for (index, item) in items.enumerated() {
            width += smallIconPointSize + 3 + item.2
            if index < items.count - 1 { width += gap + dividerWidth + gap }
        }
        width += sidePadding

        let size = CGSize(width: width.rounded(.up) + 1, height: contentHeight)
        return NSImage(size: size, flipped: false) { rect in
            var x = sidePadding
            for (index, item) in items.enumerated() {
                let tinted = item.0.tinted(with: textColor)
                let iconY = (rect.height - tinted.size.height) / 2
                tinted.draw(at: CGPoint(x: x, y: iconY), from: .zero, operation: .sourceOver, fraction: 1)
                x += smallIconPointSize + 3
                let textY = (rect.height - item.1.size(withAttributes: textAttrs).height) / 2
                item.1.draw(at: CGPoint(x: x, y: textY), withAttributes: textAttrs)
                x += item.2
                if index < items.count - 1 {
                    x += gap
                    textColor.withAlphaComponent(0.3).setFill()
                    NSRect(x: x, y: 3, width: dividerWidth, height: rect.height - 6).fill()
                    x += dividerWidth + gap
                }
            }
            return true
        }
    }

    // MARK: - Dual-value metrics: two stacked lines (network down/up, disk read/write)

    private static func renderTwoLineRow(metric: MetricKind, sample: MetricSample, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        let (downRate, upRate) = dualValues(for: metric, sample: sample)
        let downText = "\(Formatting.mbps(downRate)) MB/s"
        let upText = "\(Formatting.mbps(upRate)) MB/s"
        let downWidth = downText.size(withAttributes: textAttrs).width
        let upWidth = upText.size(withAttributes: textAttrs).width
        let maxTextWidth = max(downWidth, upWidth)

        let width = sidePadding + smallIconPointSize + 3 + maxTextWidth + sidePadding
        let size = CGSize(width: width.rounded(.up) + 1, height: twoLineHeight)

        return NSImage(size: size, flipped: false) { rect in
            let rowHeight = rect.height / 2
            let downIcon = MetricIconLibrary.image(named: "arrow.down", pointSize: smallIconPointSize).tinted(with: textColor)
            let upIcon = MetricIconLibrary.image(named: "arrow.up", pointSize: smallIconPointSize).tinted(with: textColor)

            let iconX = sidePadding
            let textX = sidePadding + smallIconPointSize + 3

            downIcon.draw(at: CGPoint(x: iconX, y: rowHeight + (rowHeight - downIcon.size.height) / 2), from: .zero, operation: .sourceOver, fraction: 1)
            downText.draw(at: CGPoint(x: textX, y: rowHeight + (rowHeight - downText.size(withAttributes: textAttrs).height) / 2), withAttributes: textAttrs)

            upIcon.draw(at: CGPoint(x: iconX, y: (rowHeight - upIcon.size.height) / 2), from: .zero, operation: .sourceOver, fraction: 1)
            upText.draw(at: CGPoint(x: textX, y: (rowHeight - upText.size(withAttributes: textAttrs).height) / 2), withAttributes: textAttrs)
            return true
        }
    }

    // MARK: - Helpers

    private static func blank() -> NSImage {
        NSImage(size: CGSize(width: 1, height: contentHeight))
    }

    /// Stacks rows top to bottom into one image, centering narrower rows —
    /// e.g. a 3-metric percentage row over a disk read/write block.
    private static func stack(_ images: [NSImage]) -> NSImage {
        guard !images.isEmpty else { return blank() }
        guard images.count > 1 else { return images[0] }

        let width = images.map(\.size.width).max() ?? 1
        let totalHeight = images.reduce(0) { $0 + $1.size.height }
        let size = CGSize(width: width, height: totalHeight)

        return NSImage(size: size, flipped: false) { rect in
            var y = rect.height
            for image in images {
                y -= image.size.height
                image.draw(at: CGPoint(x: (rect.width - image.size.width) / 2, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
    }

    /// Down-arrow / up-arrow pair for whichever dual-value metric is being
    /// rendered — network's incoming/outgoing throughput, or disk's
    /// read/write throughput. Both read as "MB/s in this direction", so the
    /// same two-line layout and the same arrow icons work for either.
    private static func dualValues(for metric: MetricKind, sample: MetricSample) -> (down: Double, up: Double) {
        switch metric {
        case .disk: return (sample.diskReadRate, sample.diskWriteRate)
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
        case .network: return ""
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

private extension NSImage {
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
