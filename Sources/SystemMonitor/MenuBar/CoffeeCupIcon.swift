import AppKit

/// Hand-drawn cup + saucer + handle, matching the line weight of the SF
/// Symbol it replaces. Off and on share the exact same outline; "on" adds a
/// coffee-fill line inside the rim and two steam wisps above it — the state
/// is the drink, not a color change.
enum CoffeeCupIcon {
    private static let designWidth: CGFloat = 22
    private static let designHeight: CGFloat = 20

    static func draw(in rect: CGRect, steaming: Bool, cupColor: NSColor, coffeeColor: NSColor, steamColor: NSColor) {
        let scale = min(rect.width / designWidth, rect.height / designHeight)
        let offsetX = rect.minX + (rect.width - designWidth * scale) / 2
        let offsetY = rect.minY + (rect.height - designHeight * scale) / 2
        let strokeWidth = max(1.1, 1.5 * scale)

        // A point given in design space, y measured downward from the top
        // (steam sits near y=0, the saucer near y=19) — flipped here since
        // we draw into a y-up NSImage context.
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: offsetX + x * scale, y: offsetY + (designHeight - y) * scale)
        }

        // A rect given by its design-space top-left corner and size.
        func designRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
            let actualHeight = height * scale
            let topY = offsetY + (designHeight - y) * scale
            return NSRect(x: offsetX + x * scale, y: topY - actualHeight, width: width * scale, height: actualHeight)
        }

        let cup = NSBezierPath()
        cup.move(to: p(5, 6))
        cup.line(to: p(17, 6))
        cup.line(to: p(14.5, 15))
        cup.curve(to: p(7.5, 15), controlPoint1: p(13, 16.3), controlPoint2: p(9, 16.3))
        cup.line(to: p(5, 6))
        cup.close()
        cup.lineWidth = strokeWidth
        cup.lineJoinStyle = .round
        cupColor.setStroke()
        cup.stroke()

        let handle = NSBezierPath()
        handle.appendArc(withCenter: p(16.2, 10.3), radius: 2.7 * scale, startAngle: -50, endAngle: 50)
        handle.lineWidth = strokeWidth
        handle.lineCapStyle = .round
        cupColor.setStroke()
        handle.stroke()

        let saucer = NSBezierPath(ovalIn: designRect(x: 1, y: 15.5, width: 20, height: 3))
        saucer.lineWidth = strokeWidth
        cupColor.setStroke()
        saucer.stroke()

        guard steaming else { return }

        let coffee = NSBezierPath(ovalIn: designRect(x: 6, y: 6.6, width: 10, height: 2))
        coffeeColor.setFill()
        coffee.fill()

        let steamWidth = max(0.8, strokeWidth * 0.65)
        let wisps: [(CGFloat, CGFloat)] = [(8.5, 5.5), (13.5, 5.0)]
        for (baseX, height) in wisps {
            let wisp = NSBezierPath()
            wisp.move(to: p(baseX, 5.5))
            wisp.curve(
                to: p(baseX, 5.5 - height),
                controlPoint1: p(baseX - 2.2, 5.5 - height * 0.35),
                controlPoint2: p(baseX + 2.2, 5.5 - height * 0.75)
            )
            wisp.lineWidth = steamWidth
            wisp.lineCapStyle = .round
            steamColor.setStroke()
            wisp.stroke()
        }
    }
}
