import SwiftUI

/// The one and only panel. Every status item opens this same widget — the
/// groups in the menu bar are just different readouts of the same machine,
/// so splitting them into separate panels made the app feel like two apps.
struct PanelView: View {
    @ObservedObject private var engine = SystemMetricsEngine.shared
    @ObservedObject private var settings = AppSettings.shared

    var onOpenActivityMonitor: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    private var sample: MetricSample { engine.sample }
    private var accent: Color { Color(hex: settings.accent.rawValue) }
    private var isCritical: Bool { sample.isCritical }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeaderView(
                title: "Mac usage",
                isCritical: isCritical,
                interval: settings.sampleInterval.label,
                onOpenSettings: onOpenSettings
            )
            CPUCardView(sample: sample, accent: accent, isCritical: isCritical, sampleInterval: settings.sampleInterval)
            MemoryDiskView(sample: sample, isCritical: isCritical)
            GridStatsView(sample: sample, isCritical: isCritical)
            if settings.showProcesses && !sample.topProcesses.isEmpty {
                ProcessListView(
                    title: "Maiores consumos",
                    unit: "CPU",
                    rows: sample.topProcesses.map {
                        ProcessListView.Row(
                            id: $0.id,
                            name: $0.name,
                            value: Formatting.oneDecimalString($0.cpuPercent) + "%",
                            fraction: min($0.cpuPercent / 100, 1)
                        )
                    },
                    accent: accent
                )
            }
            PanelFooterView(
                isCritical: isCritical,
                onOpenActivityMonitor: onOpenActivityMonitor,
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
        }
        .padding(16)
        .frame(width: 320)
        .foregroundStyle(.primary)
        // No background here on purpose — NSPopover supplies the material,
        // which is Liquid Glass on macOS 26. See GlassControls.swift.
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isCritical ? DesignColor.critical.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }
}
