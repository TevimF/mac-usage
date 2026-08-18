import SwiftUI

/// Reorders the popover panel's middle sections (CPU, memory/disk, network/
/// thermal/battery, processes). Header and footer aren't listed — they
/// always stay at the top and bottom. Drag any row to move it — `List` on
/// macOS enables that straight from `.onMove`, no explicit "Edit" mode or
/// custom drag handling needed.
struct PanelSectionsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        List {
            ForEach(settings.panelSectionOrder) { section in
                row(for: section)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { indices, destination in
                settings.panelSectionOrder.move(fromOffsets: indices, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
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
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
    }

    private func position(of section: PanelSection) -> Int {
        (settings.panelSectionOrder.firstIndex(of: section) ?? 0) + 1
    }
}
