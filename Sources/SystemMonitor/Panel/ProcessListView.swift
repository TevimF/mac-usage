import SwiftUI

/// Ranked process list. Generic over what's being ranked so the CPU widget
/// can show CPU% and the memory widget can show resident size.
struct ProcessListView: View {
    struct Row: Identifiable {
        let id: Int32
        let name: String
        let value: String
        let fraction: Double
    }

    var title: String
    var unit: String
    var rows: [Row]
    var accent: Color

    var body: some View {
        ProcessListFrame(title: title, unit: unit) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Text(row.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    MeterBar(fraction: row.fraction, color: accent)
                        .frame(width: 56)
                    Text(row.value)
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}

/// Header, divider and row spacing shared by the real list and its
/// placeholder, so the two occupy the same height and the panel doesn't
/// resize when the first reading lands.
private struct ProcessListFrame<Content: View>: View {
    var title: String
    var unit: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .eyebrowStyle()
                Spacer()
                Text(unit)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            VStack(spacing: 7) {
                content
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
        }
    }
}

/// Stand-in for the one interval between opening the panel and the first
/// process reading. The sampler only runs while the panel is open, so it
/// spends that tick seeding its baseline (see ProcessSampler.seed) and has
/// no percentages to show yet.
struct ProcessListPlaceholderView: View {
    var title: String
    var unit: String
    var rowCount: Int = 4

    var body: some View {
        ProcessListFrame(title: title, unit: unit) {
            ForEach(0..<rowCount, id: \.self) { index in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        // Uneven widths so it reads as "names loading"
                        // rather than as a table someone drew by hand.
                        .frame(width: [92.0, 74.0, 108.0, 66.0][index % 4], height: 10)
                    Spacer(minLength: 8)
                    MeterBar(fraction: 0, color: .clear)
                        .frame(width: 56)
                    Text("—")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .accessibilityLabel(L10n.t("Medindo consumo por app", "Measuring per-app usage"))
    }
}
