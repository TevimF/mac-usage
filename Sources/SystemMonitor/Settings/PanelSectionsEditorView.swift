import SwiftUI

/// Reorders the popover panel's middle sections (CPU, memory/disk, network/
/// thermal/battery, processes). Header and footer aren't listed — they
/// always stay at the top and bottom. Drag any row to move it.
struct PanelSectionsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared
    // Highlights the row a drag is currently over — see
    // MetricOrderEditorView for why this is a plain VStack of rows rather
    // than `List` + `.onMove` (this editor lives inside
    // `Form { Section { ... } }`, and nesting a reorderable List inside
    // Form's own List-backed `.grouped` style silently breaks `.onMove`).
    @State private var dropTarget: PanelSection?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(settings.panelSectionOrder) { section in
                row(for: section)
            }
        }
    }

    private func row(for section: PanelSection) -> some View {
        HStack(spacing: 10) {
            DragHandle()

            Text("\(position(of: section))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .trailing)

            Text(section.displayName)
                .font(.system(size: 12.5))

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(dropTarget == section ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
        )
        .contentShape(Rectangle())
        // String payload, not the PanelSection Transferable — see
        // MetricOrderEditorView for why a custom Transferable's UTType
        // silently fails to round-trip without Info.plist registration.
        .draggable(section.rawValue)
        .dropDestination(for: String.self) { dropped, _ in
            defer { dropTarget = nil }
            guard let raw = dropped.first, let dragged = PanelSection(rawValue: raw), dragged != section,
                  let from = settings.panelSectionOrder.firstIndex(of: dragged),
                  let to = settings.panelSectionOrder.firstIndex(of: section)
            else { return false }
            settings.panelSectionOrder.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            return true
        } isTargeted: { isTargeted in
            dropTarget = isTargeted ? section : (dropTarget == section ? nil : dropTarget)
        }
    }

    private func position(of section: PanelSection) -> Int {
        (settings.panelSectionOrder.firstIndex(of: section) ?? 0) + 1
    }
}
