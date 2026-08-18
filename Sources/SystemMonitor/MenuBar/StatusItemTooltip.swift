import Foundation

/// Hover text for a status item: the detail behind the number it's showing.
///
/// A native tooltip rather than a hover-triggered popover — it costs nothing
/// when the pointer isn't there, it's the behavior macOS users already
/// expect from menu bar items, and it doesn't fight the click that opens the
/// real panel.
enum StatusItemTooltip {
    static func text(for metrics: [MetricKind], sample: MetricSample) -> String {
        let blocks = metrics.filter(\.isAvailable).map { lines(for: $0, sample: sample).joined(separator: "\n") }
        return blocks.joined(separator: "\n\n")
    }

    private static func lines(for metric: MetricKind, sample: MetricSample) -> [String] {
        switch metric {
        case .cpu:
            var lines = [
                "CPU — \(Formatting.percent(sample.cpuPercent))%",
                "\(L10n.t("usuário", "user")) \(Formatting.percent(sample.cpuUserPercent))% · \(L10n.t("sistema", "system")) \(Formatting.percent(sample.cpuSystemPercent))%",
                "\(sample.cpuModel) · \(sample.cpuCoreCount) \(L10n.t("núcleos", "cores"))"
            ]
            if let top = sample.processes.max(by: { $0.cpuPercent < $1.cpuPercent }) {
                lines.append("\(L10n.t("maior consumo", "top consumer")): \(top.name) \(Formatting.oneDecimalString(top.cpuPercent))%")
            }
            return lines

        case .ram:
            var lines = [
                "\(L10n.t("Memória", "Memory")) — \(Formatting.gb(sample.memoryUsedGB)) / \(Formatting.gb(sample.memoryTotalGB)) GB (\(Formatting.percent(sample.memoryFraction * 100))%)",
                "\(L10n.t("ativa", "active")) \(Formatting.gb(sample.memoryActiveGB)) · \(L10n.t("reservada", "wired")) \(Formatting.gb(sample.memoryWiredGB)) · \(L10n.t("comprimida", "compressed")) \(Formatting.gb(sample.memoryCompressedGB)) GB"
            ]
            if let top = sample.processes.max(by: { $0.memoryMB < $1.memoryMB }) {
                lines.append("\(L10n.t("maior consumo", "top consumer")): \(top.name) \(Formatting.memory(mb: top.memoryMB))")
            }
            return lines

        case .swap:
            guard sample.swapTotalGB > 0 else { return ["Swap — \(L10n.t("não usado", "not used"))"] }
            return [
                "Swap — \(Formatting.gb(sample.swapUsedGB)) / \(Formatting.gb(sample.swapTotalGB)) GB",
                sample.swapUsedGB > 1
                    ? L10n.t("paginando para o disco", "paging to disk")
                    : L10n.t("sem pressão de memória relevante", "no relevant memory pressure")
            ]

        case .disk:
            return [
                "\(L10n.t("Disco", "Disk")) — \(Formatting.gb(sample.diskUsedGB)) / \(Formatting.gb(sample.diskTotalGB)) GB",
                "\(L10n.t("livre", "free")) \(Formatting.gb(sample.diskTotalGB - sample.diskUsedGB)) GB (\(Formatting.percent((1 - sample.diskFraction) * 100))%)"
            ]

        case .diskIO:
            return [
                L10n.t("Disco (velocidade)", "Disk (throughput)"),
                "↓ \(Formatting.mbps(sample.diskReadRate)) MB/s · ↑ \(Formatting.mbps(sample.diskWriteRate)) MB/s"
            ]

        case .network:
            return [
                L10n.t("Rede", "Network"),
                "↓ \(Formatting.mbps(sample.networkDownRate)) MB/s · ↑ \(Formatting.mbps(sample.networkUpRate)) MB/s"
            ]

        case .thermal:
            return ["\(L10n.t("Térmico", "Thermal")) — \(sample.thermalState.label)"]

        case .battery:
            guard let percent = sample.batteryPercent else {
                return ["\(L10n.t("Bateria", "Battery")) — \(L10n.t("sem bateria", "no battery"))"]
            }
            var lines = ["\(L10n.t("Bateria", "Battery")) — \(percent)%"]
            if sample.isCharging {
                lines.append(L10n.t("carregando", "charging"))
            } else if let minutes = sample.batteryTimeRemainingMinutes, minutes > 0 {
                lines.append(L10n.t("\(Formatting.duration(minutes: minutes)) restantes", "\(Formatting.duration(minutes: minutes)) remaining"))
            }
            return lines

        case .gpu:
            return []
        }
    }
}
