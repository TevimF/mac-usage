import SwiftUI

/// Which reading orders the "maiores consumos" list — tapped from the CPU
/// or RAM column header. Deliberately not persisted in AppSettings: it's a
/// look-right-now toggle for the session, not a preference worth carrying
/// across launches, and the panel is rebuilt fresh every time it opens
/// anyway (see PopoverController).
enum ProcessSortMetric {
    case cpu, ram
}

/// Ranked process list. Every row already carries both CPU% and RAM% — the
/// candidate pool it's built from (`SystemMetricsEngine`'s merge of top-by-
/// CPU and top-by-memory) exists specifically so that toggling the sort
/// doesn't lose whichever metric wasn't driving the list a moment ago.
struct ProcessListView: View {
    struct Row: Identifiable {
        let id: Int32
        let name: String
        let cpuPercent: Double
        let cpuText: String
        let ramPercent: Double
        let ramText: String
    }

    var title: String
    var rows: [Row]
    var accent: Color
    @Binding var sortMetric: ProcessSortMetric

    static let meterWidth: CGFloat = 46
    static let valueWidth: CGFloat = 40
    static let columnSpacing: CGFloat = 8

    private var sortedRows: [Row] {
        switch sortMetric {
        case .cpu: return rows.sorted { $0.cpuPercent > $1.cpuPercent }
        case .ram: return rows.sorted { $0.ramPercent > $1.ramPercent }
        }
    }

    var body: some View {
        ProcessListFrame(title: title) {
            columnHeaders
        } content: {
            ForEach(sortedRows.prefix(4)) { row in
                HStack(spacing: 10) {
                    Text(row.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    MeterBar(fraction: activeFraction(for: row), color: accent)
                        .frame(width: Self.meterWidth)
                    HStack(spacing: Self.columnSpacing) {
                        Text(row.cpuText).frame(width: Self.valueWidth, alignment: .trailing)
                        Text(row.ramText).frame(width: Self.valueWidth, alignment: .trailing)
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                }
            }
        }
    }

    /// The meter bar always tracks whichever metric is currently sorting
    /// the list — it's the reading the row is ranked by, so it's the one
    /// worth seeing at a glance.
    private func activeFraction(for row: Row) -> Double {
        switch sortMetric {
        case .cpu: return min(row.cpuPercent / 100, 1)
        case .ram: return min(row.ramPercent / 100, 1)
        }
    }

    @ViewBuilder
    private var columnHeaders: some View {
        HStack(spacing: 0) {
            // Lines the CPU/RAM labels up over their value columns below —
            // the meter bar has no header of its own, so its width has to
            // be accounted for here as blank space instead.
            Spacer().frame(width: Self.meterWidth + 10)
            HStack(spacing: Self.columnSpacing) {
                columnButton(L10n.t("CPU", "CPU"), isActive: sortMetric == .cpu) { sortMetric = .cpu }
                    .frame(width: Self.valueWidth, alignment: .trailing)
                columnButton(L10n.t("RAM", "RAM"), isActive: sortMetric == .ram) { sortMetric = .ram }
                    .frame(width: Self.valueWidth, alignment: .trailing)
            }
        }
    }

    private func columnButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

/// Header, divider and row spacing shared by the real list and its
/// placeholder, so the two occupy the same height and the panel doesn't
/// resize when the first reading lands.
private struct ProcessListFrame<Header: View, Content: View>: View {
    var title: String
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .eyebrowStyle()
                Spacer()
                header
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
    var rowCount: Int = 4

    var body: some View {
        ProcessListFrame(title: title) {
            HStack(spacing: 0) {
                Spacer().frame(width: ProcessListView.meterWidth + 10)
                HStack(spacing: ProcessListView.columnSpacing) {
                    Text(L10n.t("CPU", "CPU")).frame(width: ProcessListView.valueWidth, alignment: .trailing)
                    Text(L10n.t("RAM", "RAM")).frame(width: ProcessListView.valueWidth, alignment: .trailing)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary.opacity(0.7))
            }
        } content: {
            ForEach(0..<rowCount, id: \.self) { index in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        // Uneven widths so it reads as "names loading"
                        // rather than as a table someone drew by hand.
                        .frame(width: [92.0, 74.0, 108.0, 66.0][index % 4], height: 10)
                    Spacer(minLength: 8)
                    MeterBar(fraction: 0, color: .clear)
                        .frame(width: ProcessListView.meterWidth)
                    HStack(spacing: ProcessListView.columnSpacing) {
                        Text("—").frame(width: ProcessListView.valueWidth, alignment: .trailing)
                        Text("—").frame(width: ProcessListView.valueWidth, alignment: .trailing)
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
        }
        .accessibilityLabel(L10n.t("Medindo consumo por app", "Measuring per-app usage"))
    }
}
