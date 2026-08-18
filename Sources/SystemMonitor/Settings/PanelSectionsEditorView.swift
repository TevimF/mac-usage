import SwiftUI

/// Reorders the popover panel's middle sections (CPU, memory/disk, network/
/// thermal/battery, processes). Header and footer aren't listed — they
/// always stay at the top and bottom.
struct PanelSectionsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(settings.panelSectionOrder.enumerated()), id: \.element) { index, section in
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Button(action: { move(from: index, by: -1) }) {
                            Image(systemName: "chevron.up").font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)
                        .opacity(index == 0 ? 0.3 : 1)

                        Button(action: { move(from: index, by: 1) }) {
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == settings.panelSectionOrder.count - 1)
                        .opacity(index == settings.panelSectionOrder.count - 1 ? 0.3 : 1)
                    }
                    .foregroundStyle(.secondary)

                    Text(section.displayName)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }
        }
    }

    private func move(from index: Int, by offset: Int) {
        let target = index + offset
        guard settings.panelSectionOrder.indices.contains(index), settings.panelSectionOrder.indices.contains(target) else { return }
        settings.panelSectionOrder.swapAt(index, target)
    }
}
