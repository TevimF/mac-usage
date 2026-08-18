import SwiftUI

private struct SparklineLine: Shape {
    var history: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard history.count >= 2 else { return path }
        let maxValue = max(history.max() ?? 100, 20)
        let points: [CGPoint] = history.enumerated().map { index, value in
            let x = rect.minX + CGFloat(index) / CGFloat(history.count - 1) * rect.width
            let fraction = max(0, min(1, value / maxValue))
            let y = rect.maxY - CGFloat(fraction) * rect.height
            return CGPoint(x: x, y: y)
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }
}

private struct SparklineArea: Shape {
    var history: [Double]

    func path(in rect: CGRect) -> Path {
        var path = SparklineLine(history: history).path(in: rect)
        guard history.count >= 2 else { return path }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The 60-second CPU trend chart in the panel — area fill + stroked line,
/// same visual language as the design's inline SVG.
struct SparklineChartView: View {
    var history: [Double]
    var color: Color

    var body: some View {
        ZStack {
            SparklineArea(history: history)
                .fill(LinearGradient(colors: [color.opacity(0.42), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            SparklineLine(history: history)
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}
