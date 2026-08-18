import SwiftUI

struct CPUCardView: View {
    var sample: MetricSample
    var accent: Color
    var isCritical: Bool
    var sampleInterval: SampleInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .eyebrowStyle()
                    if isCritical {
                        Text(L10n.t("acima de 90% por várias amostras", "above 90% for several samples"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(DesignColor.critical)
                    } else {
                        Text("\(sample.cpuModel) · \(sample.cpuCoreCount) \(L10n.t("núcleos", "cores"))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                HStack(alignment: .top, spacing: 1) {
                    Text(Formatting.percent(sample.cpuPercent))
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(isCritical ? DesignColor.critical : Color.primary)
            }

            SparklineChartView(history: sample.cpuHistory, color: isCritical ? DesignColor.critical : accent)
                .frame(height: 54)

            HStack {
                Text("\(L10n.t("usuário", "user")) \(Formatting.percent(sample.cpuUserPercent))%")
                Spacer()
                Text("\(L10n.t("sistema", "system")) \(Formatting.percent(sample.cpuSystemPercent))%")
                Spacer()
                Text(windowLabel)
            }
            .detailStyle()
            .monospacedDigit()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCritical ? DesignColor.critical.opacity(0.12) : Color.primary.opacity(0.06))
        )
    }

    // Was a hardcoded "60 s", which was only ever true at the default 2s
    // interval — the sparkline actually spans however many samples are
    // buffered times whatever interval Settings currently has picked.
    private var windowLabel: String {
        let seconds = Int((Double(sample.cpuHistory.count) * sampleInterval.rawValue).rounded())
        return "\(seconds) s"
    }
}
