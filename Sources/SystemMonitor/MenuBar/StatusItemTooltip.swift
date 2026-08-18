import Foundation

/// Hover text for a status item: the detail behind the number it's showing.
///
/// A native tooltip rather than a hover-triggered popover — it costs nothing
/// when the pointer isn't there, it's the behavior macOS users already
/// expect from menu bar items, and it doesn't fight the click that opens the
/// real panel.
enum StatusItemTooltip {
    static func text(for slot: StatusItemSlot, sample: MetricSample) -> String {
        let blocks = slot.metrics.filter(\.isAvailable).map { lines(for: $0, sample: sample).joined(separator: "\n") }
        return blocks.joined(separator: "\n\n")
    }

    private static func lines(for metric: MetricKind, sample: MetricSample) -> [String] {
        switch metric {
        case .cpu:
            var lines = [
                "CPU — \(Formatting.percent(sample.cpuPercent))%",
                "usuário \(Formatting.percent(sample.cpuUserPercent))% · sistema \(Formatting.percent(sample.cpuSystemPercent))%",
                "\(sample.cpuModel) · \(sample.cpuCoreCount) núcleos"
            ]
            if let top = sample.topProcesses.first {
                lines.append("maior consumo: \(top.name) \(Formatting.oneDecimalString(top.cpuPercent))%")
            }
            return lines

        case .ram:
            var lines = [
                "Memória — \(Formatting.gb(sample.memoryUsedGB)) / \(Formatting.gb(sample.memoryTotalGB)) GB (\(Formatting.percent(sample.memoryFraction * 100))%)",
                "ativa \(Formatting.gb(sample.memoryActiveGB)) · reservada \(Formatting.gb(sample.memoryWiredGB)) · comprimida \(Formatting.gb(sample.memoryCompressedGB)) GB"
            ]
            if let top = sample.topMemoryProcesses.first {
                lines.append("maior consumo: \(top.name) \(Formatting.memory(mb: top.memoryMB))")
            }
            return lines

        case .swap:
            guard sample.swapTotalGB > 0 else { return ["Swap — não usado"] }
            return [
                "Swap — \(Formatting.gb(sample.swapUsedGB)) / \(Formatting.gb(sample.swapTotalGB)) GB",
                sample.swapUsedGB > 1 ? "paginando para o disco" : "sem pressão de memória relevante"
            ]

        case .disk:
            return [
                "Disco — \(Formatting.gb(sample.diskUsedGB)) / \(Formatting.gb(sample.diskTotalGB)) GB",
                "livre \(Formatting.gb(sample.diskTotalGB - sample.diskUsedGB)) GB (\(Formatting.percent((1 - sample.diskFraction) * 100))%)"
            ]

        case .diskIO:
            return [
                "Disco (velocidade)",
                "↓ \(Formatting.mbps(sample.diskReadRate)) MB/s · ↑ \(Formatting.mbps(sample.diskWriteRate)) MB/s"
            ]

        case .network:
            return [
                "Rede",
                "↓ \(Formatting.mbps(sample.networkDownRate)) MB/s · ↑ \(Formatting.mbps(sample.networkUpRate)) MB/s"
            ]

        case .thermal:
            return ["Térmico — \(sample.thermalState.label)"]

        case .battery:
            guard let percent = sample.batteryPercent else { return ["Bateria — sem bateria"] }
            var lines = ["Bateria — \(percent)%"]
            if sample.isCharging {
                lines.append("carregando")
            } else if let minutes = sample.batteryTimeRemainingMinutes, minutes > 0 {
                lines.append("\(Formatting.duration(minutes: minutes)) restantes")
            }
            return lines

        case .gpu:
            return []
        }
    }
}
