import SwiftUI

/// Shared text roles for the panel. Before this, every section wrote its
/// own `.font(.system(size:...))` for what was meant to be the same
/// "section label" role — CPU/Memória/Disco/tile titles/Maiores consumos
/// each landed on a slightly different size and tracking (10.5/0.9,
/// 10.5/0.7, 9.5/0.7) purely because they were written at different points
/// rather than sharing a style. One definition here instead of N drifting
/// copies.
extension View {
    /// Small uppercase label that introduces a section or tile — pass the
    /// natural-case string ("Memória"), the uppercase transform is applied
    /// for display only.
    func eyebrowStyle() -> some View {
        font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Small secondary readout — footer stats, byte counts, timestamps.
    func detailStyle() -> some View {
        font(.system(size: 10.5))
            .foregroundStyle(.secondary)
    }
}
