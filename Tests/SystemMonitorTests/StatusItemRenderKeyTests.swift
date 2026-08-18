import AppKit
import XCTest
@testable import SystemMonitor

/// The render key is what lets the status item skip a redraw. If it ever
/// stops reflecting something the drawing uses, the bar silently freezes on
/// a stale image — so these check both directions: equal keys for pictures
/// that are the same, different keys for pictures that aren't.
final class StatusItemRenderKeyTests: XCTestCase {
    private let accent = NSColor.systemCyan

    private func key(for sample: MetricSample, metrics: [MetricKind] = [.cpu], style: IconStyle = .numeric, colorMode: IconColorMode = .neutral, isDark: Bool = true) -> String {
        StatusItemContentRenderer.renderKey(
            metrics: metrics,
            sample: sample,
            style: style,
            accent: accent,
            colorMode: colorMode,
            isDark: isDark
        )
    }

    private func cpuSample(_ percent: Double, history: [Double] = [10, 20]) -> MetricSample {
        var sample = MetricSample()
        sample.cpuPercent = percent
        sample.cpuHistory = history
        return sample
    }

    func testMovementTooSmallToShowKeepsTheSameKey() {
        // Both render "42%" — this is the case that saves the work.
        XCTAssertEqual(key(for: cpuSample(42.1)), key(for: cpuSample(42.4)))
    }

    func testADifferentDisplayedNumberChangesTheKey() {
        XCTAssertNotEqual(key(for: cpuSample(42.4)), key(for: cpuSample(42.6)))
    }

    func testAppearanceFlipChangesTheKey() {
        let sample = cpuSample(42)
        XCTAssertNotEqual(key(for: sample, isDark: true), key(for: sample, isDark: false))
    }

    func testCriticalStateChangesTheKey() {
        var calm = cpuSample(95)
        var alarmed = cpuSample(95)
        alarmed.isCritical = true
        XCTAssertNotEqual(key(for: calm), key(for: alarmed))
        calm.isCritical = false
        XCTAssertEqual(key(for: calm), key(for: cpuSample(95)))
    }

    func testSparklineStyleFollowsTheHistory() {
        // Same percentage, one more point in the graph: the picture moved,
        // so the key has to move with it.
        let before = cpuSample(42, history: [10, 20])
        let after = cpuSample(42, history: [10, 20, 30])
        XCTAssertNotEqual(key(for: before, style: .capsule), key(for: after, style: .capsule))
        // The numeric style draws no sparkline, so there it's the same image.
        XCTAssertEqual(key(for: before, style: .numeric), key(for: after, style: .numeric))
    }

    func testBatteryIconChangeIsNoticedEvenAtTheSamePercent() {
        var discharging = MetricSample()
        discharging.batteryPercent = 100
        discharging.isCharging = false
        var charging = discharging
        charging.isCharging = true
        // Same "100%" text, different symbol (battery.100 vs .bolt).
        XCTAssertNotEqual(key(for: discharging, metrics: [.battery]), key(for: charging, metrics: [.battery]))
    }

    func testValueColoringIsPartOfTheKey() {
        // In .byValue mode the tint slides with the reading, so two loads
        // that print the same digits can still be drawn in different colors.
        var low = MetricSample()
        low.memoryTotalGB = 16
        low.memoryUsedGB = 12.08 // 75,5% → "76%", inside the warn ramp
        var high = MetricSample()
        high.memoryTotalGB = 16
        high.memoryUsedGB = 14.4 // 90% → red end
        XCTAssertNotEqual(
            key(for: low, metrics: [.ram], colorMode: .byValue),
            key(for: high, metrics: [.ram], colorMode: .byValue)
        )
    }

    func testDualValueMetricsCarryBothNumbers() {
        var down = MetricSample()
        down.networkDownRate = 1.2
        down.networkUpRate = 0.3
        var up = down
        up.networkUpRate = 9.9
        XCTAssertNotEqual(key(for: down, metrics: [.network]), key(for: up, metrics: [.network]))
    }

    func testKeyMatchesWhatRenderActuallyDraws() {
        // The safety net for the whole optimization: equal keys have to mean
        // equal pixels.
        let a = cpuSample(42.1)
        let b = cpuSample(42.4)
        XCTAssertEqual(key(for: a), key(for: b))
        let imageA = StatusItemContentRenderer.render(metrics: [.cpu], sample: a, style: .numeric, accent: accent, colorMode: .neutral, isDark: true)
        let imageB = StatusItemContentRenderer.render(metrics: [.cpu], sample: b, style: .numeric, accent: accent, colorMode: .neutral, isDark: true)
        XCTAssertEqual(imageA.tiffRepresentation, imageB.tiffRepresentation)
    }
}
