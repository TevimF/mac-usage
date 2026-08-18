import SwiftUI

struct MemoryDiskView: View {
    var sample: MetricSample
    var isCritical: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Memória").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Formatting.gb(sample.memoryUsedGB)) / \(Formatting.gb(sample.memoryTotalGB)) GB")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(memoryIsHot ? DesignColor.critical : Color.primary)
                }
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle().fill(memoryIsHot ? DesignColor.critical : DesignColor.memory)
                            .frame(width: geo.size.width * fraction(sample.memoryActiveGB))
                        Rectangle().fill(memoryIsHot ? DesignColor.critical.opacity(0.6) : DesignColor.memoryLight)
                            .frame(width: geo.size.width * fraction(sample.memoryWiredGB))
                        Rectangle().fill(Color.primary.opacity(0.35))
                            .frame(width: geo.size.width * fraction(sample.memoryCompressedGB))
                    }
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(height: 4)
                if sample.swapUsedGB > 0.05 {
                    Text("swap \(Formatting.gb(sample.swapUsedGB)) GB")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Disco").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Formatting.gb(sample.diskUsedGB)) / \(Formatting.gb(sample.diskTotalGB)) GB")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
                MeterBar(fraction: sample.diskFraction, color: DesignColor.diskThermalWarn)
                HStack(spacing: 12) {
                    Text("↓ \(Formatting.mbps(sample.diskReadRate))")
                    Text("↑ \(Formatting.mbps(sample.diskWriteRate)) MB/s")
                }
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }

    private var memoryIsHot: Bool { isCritical && sample.memoryFraction > 0.9 }

    private func fraction(_ value: Double) -> CGFloat {
        guard sample.memoryTotalGB > 0 else { return 0 }
        return CGFloat(value / sample.memoryTotalGB)
    }
}
