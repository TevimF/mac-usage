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
    // The row currently being dragged over, so it can highlight as the
    // drop target — otherwise a drag in progress gives no feedback at all
    // about where the row would land.
    @State private var dropTarget: MetricKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(L10n.t("Na barra", "In the bar"), selection: $settings.barMetricCount) {
                Text(L10n.t("1 métrica", "1 metric")).tag(1)
                Text(L10n.t("2 métricas", "2 metrics")).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // A plain VStack, not `List` — `List`'s own `.onMove` looked
            // right in isolation, but this editor lives inside
            // `Form { Section { ... } }`, and on macOS `Form`'s
            // `.formStyle(.grouped)` is itself a List-like table view.
            // Nesting a reorderable List inside that outer one means two
            // AppKit drag/selection machineries compete for the same
            // mouse-down; the outer one wins, so `.onMove` never fires.
            // `.draggable`/`.dropDestination` run on plain rows instead,
            // with no inner List to lose that contest.
            VStack(spacing: 4) {
                ForEach(settings.metricOrder) { metric in
                    row(for: metric)
                }
            }

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
                .fill(dropTarget == metric ? Color.accentColor.opacity(0.22)
                      : focusedMetric == metric ? Color.accentColor.opacity(0.14)
                      : Color.primary.opacity(0.05))
        )
        .contentShape(Rectangle())
        .focusable()
        .focused($focusedMetric, equals: metric)
        // `.simultaneousGesture` rather than `.onTapGesture`: a plain tap
        // gesture would otherwise claim the mouse-down exclusively, ahead
        // of `.draggable`'s own recognizer, so a click-and-hold could never
        // turn into a drag.
        .simultaneousGesture(TapGesture().onEnded { focusedMetric = metric })
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            guard press.modifiers.contains(.option) else { return .ignored }
            move(metric, by: press.key == .upArrow ? -1 : 1)
            return .handled
        }
        // A plain String payload (metric.rawValue), not a custom
        // Transferable — a custom type needs its UTType actually
        // registered (normally via Info.plist's UTExportedTypeDeclarations)
        // to round-trip reliably through NSItemProvider; without that, the
        // drop silently decodes to nothing and `dropped.first` is always
        // nil, so the reorder quietly never happens. String's built-in
        // Transferable conformance uses a standard system type (plain
        // text), which needs no registration at all.
        .draggable(metric.rawValue)
        .dropDestination(for: String.self) { dropped, _ in
            defer { dropTarget = nil }
            guard let raw = dropped.first, let dragged = MetricKind(rawValue: raw), dragged != metric,
                  let from = settings.metricOrder.firstIndex(of: dragged),
                  let to = settings.metricOrder.firstIndex(of: metric)
            else { return false }
            settings.metricOrder.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            return true
        } isTargeted: { isTargeted in
            dropTarget = isTargeted ? metric : (dropTarget == metric ? nil : dropTarget)
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
        case .network: return "↓ \(Formatting.throughput(sample.networkDownRate)) · ↑ \(Formatting.throughput(sample.networkUpRate))"
        case .thermal: return sample.thermalState.label
        case .battery: return sample.batteryPercent.map { "\($0)%" } ?? "—"
        case .gpu: return ""
        }
    }
}
