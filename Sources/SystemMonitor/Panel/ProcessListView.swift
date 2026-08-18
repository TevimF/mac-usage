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
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
        }
    }
}
