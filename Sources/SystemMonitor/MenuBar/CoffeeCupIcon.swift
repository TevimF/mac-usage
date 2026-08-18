import AppKit

/// The design v2 mark (section 07): a flat-rimmed cup with a side handle
/// and a baseline instead of a saucer. Off is an outlined cup, on is the
/// same cup with an amber coffee level inset inside it — the silhouette
/// never changes size between the two, so the state reads as "empty vs.
/// full" rather than a recolor or an added badge.
///
/// The rising vapor wisps aren't drawn here: they need to loop
/// continuously, which a one-shot `NSImage` can't do. `KeepAwakeStatusItemController`
/// adds them as `CALayer`s directly on the button, in the same 24-unit
/// design space this file draws in (see `designSize`), so they line up
/// with the cup regardless of what size the button ends up at.
enum CoffeeCupIcon {
    static let designSize: CGFloat = 24
    static let coffeeFill = NSColor(red: 0.851, green: 0.627, blue: 0.357, alpha: 1) // #D9A05B

    static func draw(in rect: CGRect, filled: Bool, cupColor: NSColor) {
        let scale = min(rect.width, rect.height) / designSize
        let offsetX = rect.minX + (rect.width - designSize * scale) / 2
        let offsetY = rect.minY + (rect.height - designSize * scale) / 2
        let strokeWidth = max(1.0, 1.6 * scale)

        // Design space is y-down (rim near the top, baseline at the
        // bottom); the NSImage context is y-up, so every point flips here.
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: offsetX + x * scale, y: offsetY + (designSize - y) * scale)
        }

        cupColor.setStroke()

        // Handle: a rounded loop on the right side of the cup wall.
        let handle = NSBezierPath()
        handle.move(to: p(15.5, 10))
        handle.curve(to: p(15.5, 15), controlPoint1: p(17.4, 10), controlPoint2: p(17.4, 15))
        handle.lineWidth = strokeWidth
        handle.lineCapStyle = .round
        handle.stroke()

        // Cup body: flat rim, near-straight walls, rounded base corners.
        let cup = NSBezierPath()
        cup.move(to: p(5, 8.5))
        cup.line(to: p(15.5, 8.5))
        cup.line(to: p(15.5, 14.1))
        cup.curve(to: p(11.3, 18.3), controlPoint1: p(15.5, 16.42), controlPoint2: p(13.62, 18.3))
        cup.line(to: p(9.2, 18.3))
        cup.curve(to: p(5, 14.1), controlPoint1: p(6.88, 18.3), controlPoint2: p(5, 16.42))
        cup.close()
        cup.lineWidth = strokeWidth
        cup.lineJoinStyle = .round

        // Coffee level: a separate, slightly inset path (not a fill of the
        // cup's own outline) so the liquid reads as sitting inside the cup
        // rather than the whole shape swapping color.
        if filled {
            let level = NSBezierPath()
            level.move(to: p(6.4, 10.2))
            level.line(to: p(14.1, 10.2))
            level.line(to: p(14.1, 14.1))
            level.curve(to: p(11.2, 17), controlPoint1: p(14.1, 15.7), controlPoint2: p(12.8, 17))
            level.line(to: p(9.3, 17))
            level.curve(to: p(6.4, 14.1), controlPoint1: p(7.7, 17), controlPoint2: p(6.4, 15.7))
            level.close()
            coffeeFill.setFill()
            level.fill()
        }
        cup.stroke()

        // Baseline instead of a saucer — the cup rests on a surface
        // without needing its own filled plate shape.
        let base = NSBezierPath()
        base.move(to: p(3.6, 21))
        base.line(to: p(17, 21))
        base.lineWidth = strokeWidth
        base.lineCapStyle = .round
        base.stroke()
    }
}
