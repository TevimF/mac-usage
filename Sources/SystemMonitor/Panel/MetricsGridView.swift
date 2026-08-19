import SwiftUI

/// The chosen "CPU hero + grid" layout: below the CPU card, every other
/// metric gets a tile of equal visual weight in a two-column grid —
/// Memória, Disco, Rede, Swap, Térmico, Bateria. Rows are paired so
/// heights stay even: the first row's tiles both carry a bar, the rest
/// are text-only.
struct MetricsGridView: View {
    var sample: MetricSample
    var isCritical: Bool

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            MetricTile(
                title: L10n.t("Memória", "Memory"),
                value: "\(Formatting.gb(sample.memoryUsedGB)) / \(Formatting.gb(sample.memoryTotalGB)) GB",
                valueColor: memoryIsHot ? DesignColor.critical : .primary,
                detail: " "
            ) {
                memoryBar
            }
            MetricTile(
                title: L10n.t("Disco", "Disk"),
                value: "\(Formatting.gb(sample.diskUsedGB)) / \(Formatting.gb(sample.diskTotalGB)) GB",
                valueColor: .primary,
                detail: "↓ \(Formatting.mbps(sample.diskReadRate)) · ↑ \(Formatting.mbps(sample.diskWriteRate)) MB/s"
            ) {
                MeterBar(fraction: sample.diskFraction, color: DesignColor.diskThermalWarn)
            }
            MetricTile(
                title: L10n.t("Rede", "Network"),
                value: "↓ \(Formatting.throughput(sample.networkDownRate))",
                valueColor: DesignColor.networkHealthy,
                detail: "↑ \(Formatting.throughput(sample.networkUpRate))"
            )
            MetricTile(
                title: "Swap",
                value: swapValue,
                valueColor: sample.swapUsedGB > 0.05 ? .primary : .secondary,
                detail: " "
            )
            MetricTile(
                title: L10n.t("Térmico", "Thermal"),
                // No temperature reading on purpose (needs a private
                // entitlement) — the qualitative state is all macOS gives
                // a third-party app.
                value: sample.thermalState.label.capitalized,
                valueColor: thermalColor,
                detail: sample.isThermalThrottling ? L10n.t("⚠️ desempenho reduzido", "⚠️ throttling active") : " ",
                highlighted: sample.isThermalThrottling
            )
            if let percent = sample.batteryPercent {
                MetricTile(
                    title: L10n.t("Bateria", "Battery"),
                    value: "\(percent)%",
                    valueColor: percent <= 20 && !sample.isCharging ? DesignColor.critical : .primary,
                    detail: batteryDetail
                )
            }
        }
    }

    private var memoryIsHot: Bool { isCritical && sample.memoryFraction > 0.9 }

    /// Active/wired/compressed segments over the total, same reading the
    /// old memory section gave — kept because it says *what kind* of use,
    /// not just how much.
    private var memoryBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(memoryIsHot ? DesignColor.critical : DesignColor.memory)
                    .frame(width: geo.size.width * memoryFraction(sample.memoryActiveGB))
                Rectangle().fill(memoryIsHot ? DesignColor.critical.opacity(0.6) : DesignColor.memoryLight)
                    .frame(width: geo.size.width * memoryFraction(sample.memoryWiredGB))
                Rectangle().fill(Color.primary.opacity(0.35))
                    .frame(width: geo.size.width * memoryFraction(sample.memoryCompressedGB))
            }
            // Full width BEFORE the background: the segments only span the
            // used fraction, and a background applied straight to the
            // HStack would end where they end — a track that stops at 60%
            // instead of running the tile's full width like the disk bar.
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(height: 4)
    }

    private func memoryFraction(_ value: Double) -> CGFloat {
        guard sample.memoryTotalGB > 0 else { return 0 }
        return CGFloat(value / sample.memoryTotalGB)
    }

    private var swapValue: String {
        guard sample.swapTotalGB > 0, sample.swapUsedGB > 0.05 else { return L10n.t("não usado", "not used") }
        return "\(Formatting.gb(sample.swapUsedGB)) / \(Formatting.gb(sample.swapTotalGB)) GB"
    }

    /// macOS only reports time-remaining once it has calibrated, so this is
    /// blank for a while after plugging/unplugging. Showing an em dash there
    /// read as broken; a space keeps the tile's baseline grid instead.
    private var batteryDetail: String {
        if sample.isCharging { return L10n.t("carregando", "charging") }
        guard let minutes = sample.batteryTimeRemainingMinutes, minutes > 0 else { return " " }
        return Formatting.duration(minutes: minutes)
    }

    private var thermalColor: Color {
        switch sample.thermalState {
        case .nominal, .fair: return .primary
        case .serious, .critical: return DesignColor.diskThermalWarn
        }
    }
}

/// One cell of the grid: eyebrow title, value, optional bar, detail line.
/// The detail renders even when blank so tiles in the same row share a
/// baseline grid instead of going ragged.
private struct MetricTile<Bar: View>: View {
    var title: String
    var value: String
    var valueColor: Color
    var detail: String
    var highlighted: Bool
    @ViewBuilder var bar: Bar

    init(
        title: String,
        value: String,
        valueColor: Color,
        detail: String,
        highlighted: Bool = false,
        @ViewBuilder bar: () -> Bar = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.detail = detail
        self.highlighted = highlighted
        self.bar = bar()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .eyebrowStyle()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            bar
            Text(detail.isEmpty ? " " : detail)
                .detailStyle()
                .monospacedDigit()
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
