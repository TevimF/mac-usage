import SwiftUI
import UniformTypeIdentifiers

/// Purely decorative — a visual "this row can be dragged" cue. The actual
/// dragging is `.draggable`/`.dropDestination` on each row (see
/// MetricOrderEditorView, PanelSectionsEditorView) — not `List`'s built-in
/// `.onMove`, which was tried first and looked fine in isolation but
/// silently stopped reordering once these rows live where they actually
/// do: inside a `Form { Section { ... } }`. On macOS, `Form` with
/// `.formStyle(.grouped)` is itself backed by a List-like table view, and
/// nesting a reorderable `List` inside that outer one means two AppKit
/// drag/selection machineries are competing for the same mouse-down — the
/// outer one wins, so `.onMove` never sees the gesture. `.draggable` runs
/// on plain `VStack` rows instead, with no inner List to lose that
/// contest.
struct DragHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 14)
    }
}

extension UTType {
    static let systemMonitorMetricKind = UTType(exportedAs: "com.estevaofonseca.systemmonitor.metric-kind")
    static let systemMonitorPanelSection = UTType(exportedAs: "com.estevaofonseca.systemmonitor.panel-section")
}
