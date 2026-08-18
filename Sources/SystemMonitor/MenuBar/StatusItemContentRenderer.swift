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

    /// Everything `render` would draw, flattened into a string. Equal keys
    /// mean an identical bitmap, so the caller can skip the redraw — most
    /// ticks don't move a single displayed digit (the values are rounded to
    /// whole percents and one decimal), and rebuilding the NSImage anyway
    /// meant CoreGraphics work every interval for a picture nobody could
    /// tell apart.
    ///
    /// Derived from the same helpers the drawing uses — resolved symbol
    /// names, formatted strings and final tint colors — so a change in any
    /// of them shows up here without a second copy of the rules to keep in
    /// sync. The sparkline is the one case that legitimately changes every
    /// tick: its whole history is part of the picture.
    static func renderKey(metrics: [MetricKind], sample: MetricSample, style: IconStyle, accent: NSColor, colorMode: IconColorMode, isDark: Bool) -> String {
        let available = metrics.filter { $0.isAvailable }
        guard let first = available.first else { return "blank" }

        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        var parts: [String] = [style.rawValue, colorMode.rawValue, colorKey(textColor)]

        for metric in available {
            let tint = iconTintColor(metric: metric, sample: sample, accent: accent, base: textColor, colorMode: colorMode)
            parts.append(metric.rawValue)
            parts.append(MetricIconLibrary.symbolName(for: metric, sample: sample))
            parts.append(colorKey(tint))
            if metric.isDualValue {
                let (down, up) = dualValues(for: metric, sample: sample)
                parts.append(Formatting.mbps(down))
                parts.append(Formatting.mbps(up))
            } else {
                parts.append(valueString(for: metric, sample: sample))
            }
        }

        if available.count == 1, !first.isDualValue, style != .numeric, first == .cpu, sample.cpuHistory.count >= 2 {
            parts.append(colorKey(accent))
            parts.append(sample.cpuHistory.map { String(format: "%.1f", $0) }.joined(separator: ","))
        }

        return parts.joined(separator: "|")
    }

    /// sRGB components rounded to three decimals — enough to tell the
    /// palette's colors and every blend step of `valueTint` apart, without
    /// letting float noise invent differences.
    private static func colorKey(_ color: NSColor) -> String {
        guard let srgb = color.usingColorSpace(.sRGB) else { return color.description }
        return String(format: "%.3f,%.3f,%.3f,%.3f", srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent)
    }

    /// `metrics` is the top slice of `AppSettings.metricOrder` that fits in
    /// the bar (today, the first two) — this renders whatever it's given as
    /// one combined status item, it doesn't decide how many that should be.
    static func render(metrics: [MetricKind], sample: MetricSample, style: IconStyle, accent: NSColor, colorMode: IconColorMode, isDark: Bool) -> NSImage {
        let available = metrics.filter { $0.isAvailable }
        guard let first = available.first else { return blank() }

        if available.count == 1, !first.isDualValue {
            return renderSingle(metric: first, sample: sample, style: style, accent: accent, colorMode: colorMode, isDark: isDark)
        }
        return renderRow(metrics: available, sample: sample, accent: accent, colorMode: colorMode, isDark: isDark)
    }

    // MARK: - Lone single-value metric (styles A/B/C)

    private static func renderSingle(metric: MetricKind, sample: MetricSample, style: IconStyle, accent: NSColor, colorMode: IconColorMode, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let valueText = valueString(for: metric, sample: sample)
        let icon = MetricIconLibrary.image(for: metric, pointSize: iconPointSize, sample: sample)
        let showSparkline = style != .numeric && metric == .cpu && sample.cpuHistory.count >= 2
        let showIcon = style != .sparkline || !showSparkline
        let showText = style != .sparkline && !valueText.isEmpty

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let textSize = showText ? valueText.size(withAttributes: textAttrs) : .zero
        let textSlotWidth = showText ? textSlotWidth(for: metric, actual: textSize.width, attributes: textAttrs) : 0

        var width: CGFloat = sidePadding
        if showIcon { width += iconPointSize }
        if showIcon && showSparkline { width += gap }
        if showSparkline { width += sparklineSize.width }
        if (showIcon || showSparkline) && showText { width += gap }
        width += textSlotWidth
        width += sidePadding
        width = max(width, 20)

        let size = CGSize(width: width.rounded(.up) + 1, height: contentHeight)
        return NSImage(size: size, flipped: false) { rect in
            var x = sidePadding
            if showIcon {
                let iconColor = iconTintColor(metric: metric, sample: sample, accent: accent, base: textColor, colorMode: colorMode)
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
                // Right-aligned inside the reserved slot, so the digits
                // grow leftward into the slack instead of widening the item.
                valueText.draw(at: CGPoint(x: x + textSlotWidth - textSize.width, y: y), withAttributes: textAttrs)
            }
            return true
        }
    }

    // MARK: - Everything else: one flat row, e.g. CPU | RAM | Swap | ↓↑Disk

    private struct Chip {
        let icon: NSImage
        let text: String
        let tint: NSColor
        /// Reserved width for the value text — sized to the metric's widest
        /// plausible reading, not to today's digits, so the item's total
        /// width holds still between ticks (see `reservedValueTemplate`).
        let textSlotWidth: CGFloat
    }

    private static func renderRow(metrics: [MetricKind], sample: MetricSample, accent: NSColor, colorMode: IconColorMode, isDark: Bool) -> NSImage {
        let textColor = foregroundColor(isDark: isDark, isCritical: sample.isCritical)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        // Dual-value metrics contribute two chips (down, up) with no divider
        // between them, so they stay visually grouped as one reading; a
        // divider only separates different metrics.
        func chip(icon: NSImage, text: String, tint: NSColor, metric: MetricKind) -> Chip {
            let slot = text.isEmpty ? 0 : textSlotWidth(for: metric, actual: text.size(withAttributes: textAttrs).width, attributes: textAttrs)
            return Chip(icon: icon, text: text, tint: tint, textSlotWidth: slot)
        }

        let groups: [[Chip]] = metrics.map { metric in
            let tint = iconTintColor(metric: metric, sample: sample, accent: accent, base: textColor, colorMode: colorMode)
            if metric.isDualValue {
                let (down, up) = dualValues(for: metric, sample: sample)
                return [
                    chip(icon: MetricIconLibrary.image(named: "arrow.down", pointSize: smallIconPointSize), text: Formatting.mbps(down), tint: tint, metric: metric),
                    chip(icon: MetricIconLibrary.image(named: "arrow.up", pointSize: smallIconPointSize), text: Formatting.mbps(up), tint: tint, metric: metric)
                ]
            }
            return [chip(
                icon: MetricIconLibrary.image(for: metric, pointSize: smallIconPointSize, sample: sample),
                text: valueString(for: metric, sample: sample),
                tint: tint,
                metric: metric
            )]
        }

        func chipWidth(_ chip: Chip) -> CGFloat {
            smallIconPointSize + chipGap + chip.textSlotWidth
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
                    let tinted = chip.icon.tinted(with: chip.tint)
                    let iconY = (rect.height - tinted.size.height) / 2
                    tinted.draw(at: CGPoint(x: x, y: iconY), from: .zero, operation: .sourceOver, fraction: 1)
                    x += smallIconPointSize + chipGap

                    let textSize = chip.text.size(withAttributes: textAttrs)
                    let textY = (rect.height - textSize.height) / 2
                    chip.text.draw(at: CGPoint(x: x + chip.textSlotWidth - textSize.width, y: textY), withAttributes: textAttrs)
                    x += chip.textSlotWidth
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

    /// The widest value this metric normally shows. The value text is drawn
    /// right-aligned inside a slot this wide, so the item's width doesn't
    /// wobble as digits come and go — the panel is an NSPopover anchored to
    /// this button, and a width change mid-view slides it around on screen.
    private static func reservedValueTemplate(for metric: MetricKind) -> String {
        switch metric {
        case .cpu, .ram, .swap, .disk, .battery: return "100%"
        // Throughput has no ceiling; "88,8" covers the everyday range and a
        // rare >100 MB/s burst just widens the item until it passes.
        case .network, .diskIO: return "88,8"
        case .thermal, .gpu: return ""
        }
    }

    private static func textSlotWidth(for metric: MetricKind, actual: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        max(actual, reservedValueTemplate(for: metric).size(withAttributes: attributes).width)
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
        if isCritical { return criticalColor }
        return isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1)
    }

    private static let criticalColor = NSColor(red: 1, green: 0.29, blue: 0.23, alpha: 1) // #FF453A
    private static let warnColor = NSColor(red: 1, green: 0.62, blue: 0.04, alpha: 1) // #FF9F0A

    /// Critical state (CPU stuck above 90%) overrides every mode with red —
    /// an alert should be unmissable, not just the one metric that tripped
    /// it. Below that, the three color modes diverge.
    static func iconTintColor(metric: MetricKind, sample: MetricSample, accent: NSColor, base: NSColor, colorMode: IconColorMode) -> NSColor {
        guard !sample.isCritical else { return criticalColor }

        switch colorMode {
        case .neutral:
            return base

        case .perMetric:
            // Same palette the panel uses (see DesignColor): CPU takes the
            // user's chosen accent, disk and thermal share the warn orange
            // (DesignColor.diskThermalWarn on the panel side), everything
            // else has a fixed color.
            switch metric {
            case .cpu: return accent
            case .ram, .swap: return NSColor(red: 0.369, green: 0.361, blue: 0.902, alpha: 1) // #5E5CE6
            case .disk, .diskIO, .thermal: return warnColor
            case .network: return NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1) // #30D158
            case .battery, .gpu: return base
            }

        case .byValue:
            // Thermal has no 0–100 "load" to slide a gradient across, so it
            // keeps its own state-based reading here instead: nominal/fair
            // reads as neutral, serious as warn, critical as red — the one
            // metric where "changes with usage" means thermal state, not a
            // fraction.
            if metric == .thermal {
                switch sample.thermalState {
                case .nominal, .fair: return base
                case .serious: return warnColor
                case .critical: return criticalColor
                }
            }
            guard let fraction = loadFraction(for: metric, sample: sample) else { return base }
            return valueTint(fraction: fraction, base: base)
        }
    }

    /// How "full" a metric is, 0–1, for `.byValue` coloring. Network and
    /// disk throughput have no natural ceiling to measure against, so they
    /// opt out (nil) and stay neutral. Battery is inverted — low charge is
    /// the state worth flagging, not high.
    private static func loadFraction(for metric: MetricKind, sample: MetricSample) -> Double? {
        switch metric {
        case .cpu: return sample.cpuPercent / 100
        case .ram: return sample.memoryFraction
        case .swap: return sample.swapTotalGB > 0 ? sample.swapUsedGB / sample.swapTotalGB : 0
        case .disk: return sample.diskFraction
        case .battery:
            guard let percent = sample.batteryPercent, !sample.isCharging else { return nil }
            return (100 - Double(percent)) / 100
        case .network, .diskIO, .thermal, .gpu: return nil
        }
    }

    /// Neutral below 70%, sliding into orange from 70–90%, then orange into
    /// red from 90–100% — a gradient instead of a hard flip so the color
    /// actually reads as "climbing" rather than snapping on at one number.
    private static func valueTint(fraction: Double, base: NSColor) -> NSColor {
        let warnStart = 0.7
        let criticalStart = 0.9
        if fraction < warnStart { return base }
        if fraction < criticalStart {
            let t = CGFloat((fraction - warnStart) / (criticalStart - warnStart))
            return base.blended(withFraction: t, of: warnColor) ?? base
        }
        let t = CGFloat(min(1, (fraction - criticalStart) / (1 - criticalStart)))
        return warnColor.blended(withFraction: t, of: criticalColor) ?? warnColor
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
