import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        guard hexString.count == 6, let value = UInt32(hexString, radix: 16) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

/// Fixed tokens from the design's "Fundamentos" section — these colors are
/// the same in light and dark, only the surfaces around them change.
enum DesignColor {
    static let memory = Color(hex: "#5E5CE6")
    static let memoryLight = Color(hex: "#8B89F5")
    static let diskThermalWarn = Color(hex: "#FF9F0A")
    static let networkHealthy = Color(hex: "#30D158")
    static let critical = Color(hex: "#FF453A")
}
