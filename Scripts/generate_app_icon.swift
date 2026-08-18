#!/usr/bin/env swift
// Draws the 1024x1024 app icon from the design spec (section 05): dark flat
// background edge-to-edge, white rounded-square chip outline with 8 corner
// pins, and a heartbeat/pulse line through the middle in the accent color.
// No gradients, no rounded corners baked in (the OS masks those).
//
// Usage: swift generate_app_icon.swift <accentHex> <outputPath>

import AppKit

let canvasSize: CGFloat = 1024
let viewBoxSize: CGFloat = 100
let scale: CGFloat = (canvasSize * 0.58) / viewBoxSize
let offset = (canvasSize - viewBoxSize * scale) / 2

func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: offset + x * scale, y: offset + y * scale)
}

func color(hex: String) -> NSColor {
    var hexString = hex
    if hexString.hasPrefix("#") { hexString.removeFirst() }
    var value: UInt64 = 0
    Scanner(string: hexString).scanHexInt64(&value)
    let r = CGFloat((value & 0xFF0000) >> 16) / 255
    let g = CGFloat((value & 0x00FF00) >> 8) / 255
    let b = CGFloat(value & 0x0000FF) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

let accentHex = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "64D2FF"
let outputPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "AppIcon-1024.png"

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: true) { _ in
    color(hex: "1C1C1E").setFill()
    NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize).fill()

    let chipRect = NSRect(x: p(28, 28).x, y: p(28, 28).y, width: 44 * scale, height: 44 * scale)
    let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: 9 * scale, yRadius: 9 * scale)
    chipPath.lineWidth = 5.5 * scale
    NSColor.white.setStroke()
    chipPath.stroke()

    let pins: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (38, 10, 38, 28), (62, 10, 62, 28), (38, 72, 38, 90), (62, 72, 62, 90),
        (10, 38, 28, 38), (10, 62, 28, 62), (72, 38, 90, 38), (72, 62, 90, 62)
    ]
    let pinPath = NSBezierPath()
    pinPath.lineWidth = 4.5 * scale
    pinPath.lineCapStyle = .round
    for (x1, y1, x2, y2) in pins {
        pinPath.move(to: p(x1, y1))
        pinPath.line(to: p(x2, y2))
    }
    NSColor.white.setStroke()
    pinPath.stroke()

    let pulsePoints: [(CGFloat, CGFloat)] = [(30, 50), (42, 50), (47, 38), (53, 62), (58, 50), (70, 50)]
    let pulsePath = NSBezierPath()
    pulsePath.move(to: p(pulsePoints[0].0, pulsePoints[0].1))
    for pt in pulsePoints.dropFirst() { pulsePath.line(to: p(pt.0, pt.1)) }
    pulsePath.lineWidth = 4.5 * scale
    pulsePath.lineCapStyle = .round
    pulsePath.lineJoinStyle = .round
    color(hex: accentHex).setStroke()
    pulsePath.stroke()

    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}

try? png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
