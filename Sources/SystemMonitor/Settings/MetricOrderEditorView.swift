import SwiftUI

/// Every available metric, in one draggable list — this is
/// `AppSettings.metricOrder`. Only the front `barMetricCount` entries show
/// in the menu bar, as one combined status item; everything else is
/// panel-only (design v2, section 08). Drag any row to reorder, or click a
/// row to select it and press ⌥↑ / ⌥↓.
struct MetricOrderEditorView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = SystemMetricsEngine.shared
    @FocusState private var focusedMetric: MetricKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(L10n.t("Na barra", "In the bar"), selection: $settings.barMetricCount) {
                Text(L10n.t("1 métrica", "1 metric")).tag(1)
                Text(L10n.t("2 métricas", "2 metrics")).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            List {
                ForEach(settings.metricOrder) { metric in
                    row(for: metric)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove { indices, destination in
                    settings.metricOrder.move(fromOffsets: indices, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)

            SettingsHelp(L10n.t(
                "Arraste uma linha pra mudar a ordem, ou selecione e use ⌥↑ / ⌥↓. As primeiras \(settings.barMetricCount == 1 ? "1 fica" : "2 ficam") na barra, numa cápsula só; o resto só aparece no painel.",
                "Drag a row to reorder, or select one and press ⌥↑ / ⌥↓. The first \(settings.barMetricCount == 1 ? "1 shows" : "2 show") in the bar, as a single capsule; the rest only appear in the panel."
            ))
        }
    }

    @ViewBuilder
    private func row(for metric: MetricKind) -> some View {
        let index = settings.metricOrder.firstIndex(of: metric) ?? 0
        let onBar = index < settings.barMetricCount

        HStack(spacing: 11) {
            DragHandle()

            Image(systemName: MetricIconLibrary.symbolName(for: metric))
                .font(.system(size: 13))
                .foregroundStyle(iconColor(for: metric))
                .frame(width: 18)

            Text(metric.displayName)
                .font(.system(size: 13, weight: .medium))

            if onBar {
                Text(L10n.t("na barra", "in the bar"))
                    .font(.system(size: 9.5, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: settings.accent.rawValue)))
            }

            Spacer(minLength: 8)

            Text(previewValue(for: metric, sample: engine.sample))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(focusedMetric == metric ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
        )
        .contentShape(Rectangle())
        .focusable()
        .focused($focusedMetric, equals: metric)
        .onTapGesture { focusedMetric = metric }
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            guard press.modifiers.contains(.option) else { return .ignored }
            move(metric, by: press.key == .upArrow ? -1 : 1)
            return .handled
        }
    }

    private func move(_ metric: MetricKind, by offset: Int) {
        guard let index = settings.metricOrder.firstIndex(of: metric) else { return }
        let target = index + offset
        guard settings.metricOrder.indices.contains(target) else { return }
        settings.metricOrder.swapAt(index, target)
    }

    private func iconColor(for metric: MetricKind) -> Color {
        switch metric {
        case .cpu: return Color(hex: settings.accent.rawValue)
        case .ram, .swap: return DesignColor.memory
        case .disk, .diskIO, .thermal: return DesignColor.diskThermalWarn
        case .network: return DesignColor.networkHealthy
        case .battery, .gpu: return .secondary
        }
    }

    private func previewValue(for metric: MetricKind, sample: MetricSample) -> String {
        switch metric {
        case .cpu: return "\(Formatting.percent(sample.cpuPercent))%"
        case .ram: return "\(Formatting.gb(sample.memoryUsedGB)) / \(Formatting.gb(sample.memoryTotalGB)) GB"
        case .swap:
            guard sample.swapTotalGB > 0 else { return L10n.t("não usado", "not used") }
            return "\(Formatting.gb(sample.swapUsedGB)) / \(Formatting.gb(sample.swapTotalGB)) GB"
        case .disk: return "\(Formatting.gb(sample.diskUsedGB)) / \(Formatting.gb(sample.diskTotalGB)) GB"
        case .diskIO: return "↓ \(Formatting.mbps(sample.diskReadRate)) · ↑ \(Formatting.mbps(sample.diskWriteRate)) MB/s"
        case .network: return "↓ \(Formatting.mbps(sample.networkDownRate)) · ↑ \(Formatting.mbps(sample.networkUpRate)) MB/s"
        case .thermal: return sample.thermalState.label
        case .battery: return sample.batteryPercent.map { "\($0)%" } ?? "—"
        case .gpu: return ""
        }
    }
}
