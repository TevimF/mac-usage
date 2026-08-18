import AppKit

/// Maps each metric to its SF Symbol — the design's own implementation
/// notes say the CPU chip icon doesn't need hand-drawing ("SF Symbol cpu —
/// não precisa desenhar"), and every icon in the "família de ícones"
/// catalog is annotated with an equivalent system symbol name. Using real
/// SF Symbols instead of hand-ported bezier paths gets pixel-perfect
/// rendering at 12px for free and stays visually consistent as one family.
enum MetricIconLibrary {
    static func symbolName(for metric: MetricKind) -> String {
        switch metric {
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .swap: return "arrow.left.arrow.right"
        case .disk: return "internaldrive"
        case .diskIO: return "gauge"
        case .network: return "arrow.up.arrow.down"
        case .thermal: return "thermometer.medium"
        case .battery: return batterySymbolName(percent: nil, isCharging: false)
        case .gpu: return "cpu"
        }
    }

    static func batterySymbolName(percent: Int?, isCharging: Bool) -> String {
        guard let percent else { return "battery.100" }
        if isCharging { return "battery.100.bolt" }
        switch percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    static func image(named name: String, pointSize: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: nil)!
        return base.withSymbolConfiguration(config) ?? base
    }

    static func image(for metric: MetricKind, pointSize: CGFloat, sample: MetricSample) -> NSImage {
        let name: String
        if metric == .battery {
            name = batterySymbolName(percent: sample.batteryPercent, isCharging: sample.isCharging)
        } else {
            name = symbolName(for: metric)
        }
        return image(named: name, pointSize: pointSize)
    }
}
