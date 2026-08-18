import SwiftUI

/// Purely decorative — a visual "this row can be dragged" cue. The actual
/// dragging comes from `List`'s own `.onMove`, which on macOS lets you grab
/// anywhere on the row (no "Edit" mode or explicit handle needed, unlike
/// iOS). A hand-rolled `.onDrag`/`.onDrop` pair was tried first but didn't
/// reliably start a drag inside a `Form` on macOS — the row's own gesture
/// handling seems to win the mouse-down before `.onDrag` gets a chance,
/// so reordering silently did nothing. `List.onMove` is the mechanism
/// AppKit itself uses for exactly this, so it doesn't hit that problem.
struct DragHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 14)
    }
}
