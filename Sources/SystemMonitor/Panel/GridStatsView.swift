import SwiftUI

struct GridStatsView: View {
    var sample: MetricSample
    var isCritical: Bool

    var body: some View {
        HStack(spacing: 8) {
            StatTile(
                title: "Rede",
                value: "↓ \(Formatting.mbps(sample.networkDownRate))",
                detail: "↑ \(Formatting.mbps(sample.networkUpRate)) MB/s",
                valueColor: DesignColor.networkHealthy,
                highlighted: false
            )
            StatTile(
                title: "Térmico",
                value: sample.thermalState.label.capitalized,
                detail: sample.thermalCelsius.map(Formatting.celsius) ?? "",
                valueColor: thermalColor,
                highlighted: sample.thermalState == .serious || sample.thermalState == .critical
            )
            if let percent = sample.batteryPercent {
                StatTile(
                    title: "Bateria",
                    value: "\(percent)%",
                    detail: batteryDetail,
                    valueColor: percent <= 20 && !sample.isCharging ? DesignColor.critical : .primary,
                    highlighted: false
                )
            }
        }
    }

    /// macOS only reports time-remaining once it has calibrated, so this is
    /// blank for a while after plugging/unplugging. Showing an em dash there
    /// read as broken; an empty detail line just collapses.
    private var batteryDetail: String {
        if sample.isCharging { return "carregando" }
        guard let minutes = sample.batteryTimeRemainingMinutes, minutes > 0 else { return "" }
        return Formatting.duration(minutes: minutes)
    }

    private var thermalColor: Color {
        switch sample.thermalState {
        case .nominal, .fair: return .primary
        case .serious, .critical: return DesignColor.diskThermalWarn
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: String
    var detail: String
    var valueColor: Color
    var highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
            // Rendered even when blank so all three tiles keep the same
            // baseline grid — a missing detail line made the row ragged.
            Text(detail.isEmpty ? " " : detail)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(highlighted ? DesignColor.diskThermalWarn.opacity(0.14) : Color.primary.opacity(0.06))
        )
    }
}
