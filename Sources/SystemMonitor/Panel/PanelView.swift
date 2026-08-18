import SwiftUI

/// The one and only panel, opened by clicking the metrics status item.
/// Every metric lives here regardless of what the menu bar shows — the bar
/// is just a shortcut to the first one or two.
struct PanelView: View {
    @ObservedObject private var engine = SystemMetricsEngine.shared
    @ObservedObject private var settings = AppSettings.shared

    var onOpenActivityMonitor: () -> Void
    var onOpenSettings: () -> Void
    var onOpenAbout: () -> Void

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
            ForEach(settings.panelSectionOrder) { section in
                sectionView(for: section)
            }
            KeepAwakeRowView()
            PanelFooterView(
                isCritical: isCritical,
                onOpenActivityMonitor: onOpenActivityMonitor,
                onOpenSettings: onOpenSettings,
                onOpenAbout: onOpenAbout
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
        // Quick settings on right click — the frequent knobs without
        // leaving the panel; the full Settings window stays one item away.
        .contextMenu {
            Picker(L10n.t("Atualizar a cada", "Update every"), selection: $settings.sampleInterval) {
                ForEach(SampleInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            Picker(L10n.t("Métricas na barra", "Metrics in the bar"), selection: $settings.barMetricCount) {
                Text(L10n.t("1 métrica", "1 metric")).tag(1)
                Text(L10n.t("2 métricas", "2 metrics")).tag(2)
            }
            Picker(L10n.t("Cor dos ícones", "Icon color"), selection: $settings.iconColorMode) {
                ForEach(IconColorMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Toggle(L10n.t("Mostrar maiores consumos", "Show top consumers"), isOn: $settings.showProcesses)
            Divider()
            Button(L10n.t("Ajustes…", "Settings…"), action: onOpenSettings)
            Button(L10n.t("Sair do Mac usage", "Quit Mac usage")) { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder
    private func sectionView(for section: PanelSection) -> some View {
        switch section {
        case .cpu:
            CPUCardView(sample: sample, accent: accent, isCritical: isCritical, sampleInterval: settings.sampleInterval)
        case .grid:
            MetricsGridView(sample: sample, isCritical: isCritical)
        case .processes:
            if settings.showProcesses && sample.processesPending {
                ProcessListPlaceholderView(
                    title: L10n.t("Maiores consumos", "Top consumers"),
                    unit: "CPU"
                )
            } else if settings.showProcesses && !sample.topProcesses.isEmpty {
                ProcessListView(
                    title: L10n.t("Maiores consumos", "Top consumers"),
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
        }
    }
}
