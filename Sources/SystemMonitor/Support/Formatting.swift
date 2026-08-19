import Foundation

/// Number formatting used throughout the panel and status items. The
/// decimal separator follows the app language — comma for pt-BR (the
/// design spec's "8,2 / 16 GB" style), point for English.
enum Formatting {
    private static func makeOneDecimal(locale: String) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: locale)
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }

    private static let oneDecimalPT = makeOneDecimal(locale: "pt_BR")
    private static let oneDecimalEN = makeOneDecimal(locale: "en_US")

    static func oneDecimalString(_ value: Double) -> String {
        let formatter = AppSettings.shared.language == .english ? oneDecimalEN : oneDecimalPT
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    static func gb(_ value: Double) -> String {
        oneDecimalString(value)
    }

    static func mbps(_ value: Double) -> String {
        oneDecimalString(value)
    }

    /// Throughput with its unit: KB/s under 1 MB/s (no decimals — "512
    /// KB/s" doesn't need one), MB/s at or above it. `value` is in MB/s.
    /// For contexts with room to spell out the unit (panel, tooltip,
    /// settings preview) — the fixed-width menu bar chip stays on `mbps`
    /// alone, since its slot width is reserved for a decimal MB reading.
    static func throughput(_ value: Double) -> String {
        if value < 1 {
            return "\(Int((value * 1000).rounded())) KB/s"
        }
        return "\(oneDecimalString(value)) MB/s"
    }

    /// Resident memory: MB below a gigabyte, GB above, so a process list
    /// doesn't turn into a column of "0,4 GB".
    static func memory(mb: Double) -> String {
        if mb >= 1024 {
            return oneDecimalString(mb / 1024) + " GB"
        }
        return "\(Int(mb.rounded())) MB"
    }

    /// "5 h 20 min" / "45 min" style duration.
    static func duration(minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return String(format: "%d h %02d min", hours, mins)
        }
        return "\(mins) min"
    }
}
