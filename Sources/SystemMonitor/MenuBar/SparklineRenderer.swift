import AppKit

/// Draws a miniature area+line trend chart, the same visual language as
/// the CPU card's big sparkline in the panel, scaled down for the menu
/// bar. Called once per metrics tick (via MenuBarController.redrawAll, in
/// response to a new engine.sample) rather than per animation frame — ticks
/// are already throttled to the user's sampling interval, so this never
/// redraws faster than the underlying data actually changes.
enum SparklineRenderer {
    static func draw(history: [Double], in rect: CGRect, context: CGContext, strokeColor: NSColor, fillColor: NSColor) {
        guard history.count >= 2 else { return }

        let maxValue = max(history.max() ?? 100, 20)
        let points: [CGPoint] = history.enumerated().map { index, value in
            let x = rect.minX + CGFloat(index) / CGFloat(history.count - 1) * rect.width
            let fraction = max(0, min(1, value / maxValue))
            let y = rect.minY + CGFloat(fraction) * rect.height
            return CGPoint(x: x, y: y)
        }

        let linePath = CGMutablePath()
        linePath.move(to: points[0])
        for point in points.dropFirst() {
            linePath.addLine(to: point)
        }

        let fillPath = linePath.mutableCopy()!
        fillPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        fillPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        fillPath.closeSubpath()

        context.saveGState()
        context.addPath(fillPath)
        context.setFillColor(fillColor.withAlphaComponent(0.35).cgColor)
        context.fillPath()

        context.addPath(linePath)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.2)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.strokePath()
        context.restoreGState()
    }
}
