import SwiftUI

/// Thin rounded progress bar used by the process list and the disk row.
struct MeterBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.1))
                Rectangle().fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(fraction, 1))))
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(height: 4)
    }
}
