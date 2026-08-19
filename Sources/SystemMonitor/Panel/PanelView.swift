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

    // Not in AppSettings: a look-right-now toggle for this one popover
    // instance, not a preference worth persisting — PopoverController
    // builds a fresh PanelView every time it opens anyway.
    @State private var processSortMetric: ProcessSortMetric = .cpu

    private var sample: MetricSample { engine.sample }
    private var accent: Color { Color(hex: settings.accent.rawValue) }
    /// CPU-specific — feeds only the CPU card, which should redden for
    /// sustained CPU load and not for a thermal-only condition.
    private var isCritical: Bool { sample.isCritical }

    /// Header/footer/border alert: CPU pressure, thermal throttling, or
    /// both — nil when neither is active.
    private var alertLabel: String? {
        switch (isCritical, sample.isThermalThrottling) {
        case (true, true): return L10n.t("Pressão alta e térmica", "High load & thermal")
        case (true, false): return L10n.t("Pressão alta", "High pressure")
        case (false, true): return L10n.t("Limitação térmica", "Thermal throttling")
        case (false, false): return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeaderView(
                title: "Mac usage",
                alertLabel: alertLabel,
                interval: settings.sampleInterval.label,
                onOpenSettings: onOpenSettings
            )
            ForEach(settings.panelSectionOrder) { section in
                sectionView(for: section)
            }
            KeepAwakeRowView()
            PanelFooterView(
                alertLabel: alertLabel,
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
                .strokeBorder(alertLabel != nil ? DesignColor.critical.opacity(0.45) : Color.clear, lineWidth: 1)
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
                ProcessListPlaceholderView(title: L10n.t("Maiores consumos", "Top consumers"))
            } else if settings.showProcesses && !sample.processes.isEmpty {
                ProcessListView(
                    title: L10n.t("Maiores consumos", "Top consumers"),
                    rows: sample.processes.map { usage in
                        let ram = ramPercent(for: usage)
                        return ProcessListView.Row(
                            id: usage.id,
                            name: usage.name,
                            cpuPercent: usage.cpuPercent,
                            cpuText: Formatting.oneDecimalString(usage.cpuPercent) + "%",
                            ramPercent: ram,
                            ramText: Formatting.oneDecimalString(ram) + "%"
                        )
                    },
                    accent: accent,
                    sortMetric: $processSortMetric
                )
            }
        }
    }

    /// A process's resident memory as a fraction of total system RAM — the
    /// same "% of the whole" shape as cpuPercent, so the two columns read
    /// side by side without one needing an absolute-size mental model the
    /// other doesn't.
    ///
    /// `* 1024` converts memoryTotalGB to MB correctly only because
    /// MemorySampler reports RAM in GiB — usage.memoryMB is already true
    /// MiB (ProcessSampler divides resident_size by 1_048_576), so both
    /// sides of this division share the same binary base.
    private func ramPercent(for usage: ProcessUsage) -> Double {
        guard sample.memoryTotalGB > 0 else { return 0 }
        return usage.memoryMB / (sample.memoryTotalGB * 1024) * 100
    }
}
