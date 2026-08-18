import SwiftUI

/// Lets the user compose the status items: up to 4 metrics per item, laid
/// out left to right in one row. A dual-value metric (network down/up, disk
/// read/write) contributes two chips instead of one, grouped together with
/// no divider between them. Order here is the order they're created in the
/// menu bar — reorder with the arrows, or afterwards by holding ⌘ and
/// dragging any item directly in the menu bar (works for any app's icons,
/// not just this one — that's a system feature, not something apps opt into).
struct StatusItemsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(settings.statusItemSlots.enumerated()), id: \.element.id) { index, _ in
                SlotRow(
                    slot: $settings.statusItemSlots[index],
                    isFirst: index == 0,
                    isLast: index == settings.statusItemSlots.count - 1,
                    onMoveUp: { moveSlot(at: index, by: -1) },
                    onMoveDown: { moveSlot(at: index, by: 1) },
                    onRemove: { removeSlot(at: index) }
                )
            }

            Button {
                addSlot()
            } label: {
                Label("Novo item de status", systemImage: "plus.circle")
            }
            .disabled(nextAvailableMetric() == nil)

            Text("Até 4 métricas por item, uma ao lado da outra. Rede e disco (velocidade) mostram ↓ e ↑ juntos. Cada item extra vira um ícone a mais na barra.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addSlot() {
        guard let metric = nextAvailableMetric() else { return }
        settings.statusItemSlots.append(StatusItemSlot(metrics: [metric]))
    }

    private func removeSlot(at index: Int) {
        guard settings.statusItemSlots.count > 1, settings.statusItemSlots.indices.contains(index) else { return }
        settings.statusItemSlots.remove(at: index)
    }

    private func moveSlot(at index: Int, by offset: Int) {
        let target = index + offset
        guard settings.statusItemSlots.indices.contains(index), settings.statusItemSlots.indices.contains(target) else { return }
        settings.statusItemSlots.swapAt(index, target)
    }

    private func nextAvailableMetric() -> MetricKind? {
        let assigned = Set(settings.statusItemSlots.flatMap(\.metrics))
        return MetricKind.allCases.first { $0.isAvailable && !assigned.contains($0) }
    }
}

private struct SlotRow: View {
    @Binding var slot: StatusItemSlot
    var isFirst: Bool
    var isLast: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onRemove: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(isFirst)
                .opacity(isFirst ? 0.3 : 1)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(isLast)
                .opacity(isLast ? 0.3 : 1)
            }
            .foregroundStyle(.secondary)

            // Chips never wrap — with 4 metrics and a long-ish label this can
            // need more width than the fixed Settings window has, so it
            // scrolls sideways instead of SwiftUI wrapping the label text
            // and turning the capsule into a tall, broken pill.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
                        .fixedSize()
                    }
                }
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
                .fixedSize()
            }

            Spacer(minLength: 8)

            Button(action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .fixedSize()
        }
    }

    private var canAddMore: Bool {
        slot.metrics.count < 4 && !addableMetrics.isEmpty
    }

    private var addableMetrics: [MetricKind] {
        let assignedElsewhere = Set(settings.statusItemSlots.filter { $0.id != slot.id }.flatMap(\.metrics))
        let assignedHere = Set(slot.metrics)
        return MetricKind.allCases.filter {
            $0.isAvailable && !assignedElsewhere.contains($0) && !assignedHere.contains($0)
        }
    }
}
