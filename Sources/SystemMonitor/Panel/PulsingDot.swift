import SwiftUI

/// The header's live indicator — pulses faster (1.1s) when critical, slower
/// (2.4s) when normal, matching the design's `livepulse` keyframe.
struct PulsingDot: View {
    var color: Color
    var isCritical: Bool
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(pulsing ? 0.35 : 1)
            .scaleEffect(pulsing ? 0.82 : 1)
            .onAppear { restartPulse() }
            // isCritical can flip while the same popover instance stays
            // open (default interval × 3 samples is well within a normal
            // viewing session) — re-read it to speed the pulse up instead
            // of leaving it stuck at whatever cadence was captured on
            // appear.
            .onChange(of: isCritical) { _, _ in restartPulse() }
    }

    private func restartPulse() {
        pulsing = false
        withAnimation(.easeInOut(duration: isCritical ? 0.55 : 1.2).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}
