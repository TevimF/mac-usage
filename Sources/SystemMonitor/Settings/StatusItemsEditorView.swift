import SwiftUI

/// Lets the user compose the status items: 1–2 metrics per item, network
/// always alone (it already carries two values — down and up), matching
/// the design's "no máximo duas métricas por item" rule.
struct StatusItemsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($settings.statusItemSlots) { $slot in
                SlotRow(slot: $slot, onRemove: { removeSlot(slot) })
            }

            Button {
                addSlot()
            } label: {
                Label("Novo item de status", systemImage: "plus.circle")
            }
            .disabled(nextAvailableMetric() == nil)

            Text("Até 2 métricas por item · rede ocupa o item sozinha (já mostra ↓ e ↑). Cada item extra vira um ícone a mais na barra.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addSlot() {
        guard let metric = nextAvailableMetric() else { return }
        settings.statusItemSlots.append(StatusItemSlot(metrics: [metric]))
    }

    private func removeSlot(_ slot: StatusItemSlot) {
        guard settings.statusItemSlots.count > 1 else { return }
        settings.statusItemSlots.removeAll { $0.id == slot.id }
    }

    private func nextAvailableMetric() -> MetricKind? {
        let assigned = Set(settings.statusItemSlots.flatMap(\.metrics))
        return MetricKind.allCases.first { $0.isAvailable && !assigned.contains($0) }
    }
}

private struct SlotRow: View {
    @Binding var slot: StatusItemSlot
    var onRemove: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(slot.metrics) { metric in
                HStack(spacing: 4) {
                    Image(systemName: MetricIconLibrary.symbolName(for: metric))
                    Text(metric.displayName)
                    Button {
                        slot.metrics.removeAll { $0 == metric }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(slot.metrics.count <= 1)
                    .opacity(slot.metrics.count <= 1 ? 0.3 : 1)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            }

            if canAddMore {
                Menu {
                    ForEach(addableMetrics) { metric in
                        Button(metric.displayName) { slot.metrics.append(metric) }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var canAddMore: Bool {
        guard !slot.metrics.contains(.network) else { return false }
        return slot.metrics.count < 2 && !addableMetrics.isEmpty
    }

    private var addableMetrics: [MetricKind] {
        let assignedElsewhere = Set(settings.statusItemSlots.filter { $0.id != slot.id }.flatMap(\.metrics))
        let assignedHere = Set(slot.metrics)
        return MetricKind.allCases.filter {
            $0.isAvailable && $0 != .network && !assignedElsewhere.contains($0) && !assignedHere.contains($0)
        }
    }
}
