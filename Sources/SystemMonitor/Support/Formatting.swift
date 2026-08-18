import Foundation

/// pt-BR number formatting (comma decimal separator) used throughout the
/// panel and status items — matches the design spec's "8,2 / 16 GB" style.
enum Formatting {
    private static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    static func oneDecimalString(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
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

    /// Resident memory: MB below a gigabyte, GB above, so a process list
    /// doesn't turn into a column of "0,4 GB".
    static func memory(mb: Double) -> String {
        if mb >= 1024 {
            return oneDecimalString(mb / 1024) + " GB"
        }
        return "\(Int(mb.rounded())) MB"
    }

    static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded())) °C"
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
