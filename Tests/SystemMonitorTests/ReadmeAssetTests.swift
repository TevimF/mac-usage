import AppKit
import SwiftUI
import XCTest
@testable import SystemMonitor

/// Draws the README's images with the app's own rendering code, so the
/// pictures in the docs are the real status item and the real icon family —
/// not a mockup that drifts the first time the renderer changes.
///
/// Skipped in a normal `swift test`; regenerating writes into the repo, and
/// that should be something you asked for:
///
///     README_ASSETS_DIR=Docs swift test --filter ReadmeAssetTests
final class ReadmeAssetTests: XCTestCase {
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let path = ProcessInfo.processInfo.environment["README_ASSETS_DIR"] else {
            throw XCTSkip("set README_ASSETS_DIR to regenerate the README images")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        AppSettings.shared.language = .portuguese
    }

    // MARK: - Sample readings

    /// A believable machine under moderate load. Fixed numbers on purpose:
    /// the images shouldn't change just because they were regenerated on a
    /// different day.
    private func busySample() -> MetricSample {
        var sample = MetricSample()
        sample.cpuPercent = 42
        sample.cpuUserPercent = 31
        sample.cpuSystemPercent = 11
        sample.cpuHistory = [18, 24, 21, 33, 47, 39, 28, 35, 52, 61, 48, 37, 30, 42]
        sample.cpuModel = "Apple M-series"
        sample.cpuCoreCount = 10
        sample.memoryUsedGB = 11.4
        sample.memoryTotalGB = 16
        // The panel's memory bar is segmented, so these have to add up to
        // memoryUsedGB or the bar draws short.
        sample.memoryActiveGB = 6.9
        sample.memoryWiredGB = 3.2
        sample.memoryCompressedGB = 1.3
        sample.swapUsedGB = 1.2
        sample.swapTotalGB = 8
        sample.diskUsedGB = 494
        sample.diskTotalGB = 994
        sample.diskReadRate = 12.4
        sample.diskWriteRate = 3.1
        sample.networkDownRate = 8.6
        sample.networkUpRate = 1.2
        sample.batteryPercent = 78
        sample.batteryTimeRemainingMinutes = 322
        sample.isCharging = false
        sample.thermalState = .nominal
        return sample
    }

    private func criticalSample() -> MetricSample {
        var sample = busySample()
        sample.cpuPercent = 97
        sample.cpuHistory = [62, 71, 85, 92, 96, 99, 97, 94, 98, 97]
        sample.isCritical = true
        return sample
    }

    // MARK: - Images

    func testGenerateMenuBarSamples() throws {
        let accent = NSColor(hex: AccentOption.cyan.rawValue)!
        let busy = busySample()

        let rows: [(String, [MetricKind], IconStyle, IconColorMode, MetricSample)] = [
            ("Numérico", [.cpu], .numeric, .neutral, busy),
            ("Sparkline", [.cpu], .sparkline, .neutral, busy),
            ("Cápsula de vidro", [.cpu], .capsule, .neutral, busy),
            ("Duas métricas", [.cpu, .ram], .capsule, .neutral, busy),
            ("Rede (↓ ↑)", [.network], .capsule, .neutral, busy),
            ("Cores por métrica", [.cpu, .ram], .capsule, .perMetric, busy),
            ("Cores por valor", [.ram, .disk], .capsule, .byValue, busy),
            ("Estado crítico", [.cpu, .ram], .capsule, .perMetric, criticalSample())
        ]

        for isDark in [true, false] {
            let images = rows.map { row in
                (row.0, StatusItemContentRenderer.render(
                    metrics: row.1,
                    sample: row.4,
                    style: row.2,
                    accent: accent,
                    colorMode: row.3,
                    isDark: isDark
                ))
            }
            let sheet = labelledRows(images, isDark: isDark)
            try write(sheet, named: isDark ? "menu-bar-dark.png" : "menu-bar-light.png")
        }
    }

    func testGenerateIconFamily() throws {
        let sample = busySample()
        let metrics = MetricKind.allCases.filter(\.isAvailable)
        for isDark in [true, false] {
            let sheet = iconSheet(metrics: metrics, sample: sample, isDark: isDark)
            try write(sheet, named: isDark ? "icon-family-dark.png" : "icon-family-light.png")
        }
    }

    // MARK: - Composition

    private let scale: CGFloat = 2
    private func background(isDark: Bool) -> NSColor {
        isDark ? NSColor(calibratedWhite: 0.13, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
    }
    private func labelColor(isDark: Bool) -> NSColor {
        isDark ? NSColor(calibratedWhite: 1, alpha: 0.55) : NSColor(calibratedWhite: 0, alpha: 0.5)
    }

    /// One labelled row per status-item variant, laid out like a spec sheet:
    /// caption on the left, the real rendered item on the right.
    private func labelledRows(_ rows: [(String, NSImage)], isDark: Bool) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: labelColor(isDark: isDark)]
        let labelColumn: CGFloat = 132
        let rowHeight: CGFloat = 30
        let padding: CGFloat = 16
        let itemWidth = rows.map(\.1.size.width).max() ?? 0
        let size = CGSize(
            width: padding * 2 + labelColumn + itemWidth + 12,
            height: padding * 2 + rowHeight * CGFloat(rows.count)
        )

        return NSImage(size: size, flipped: false) { _ in
            self.background(isDark: isDark).setFill()
            NSRect(origin: .zero, size: size).fill()

            for (index, row) in rows.enumerated() {
                let top = size.height - padding - rowHeight * CGFloat(index + 1)
                let textSize = row.0.size(withAttributes: labelAttrs)
                row.0.draw(at: CGPoint(x: padding, y: top + (rowHeight - textSize.height) / 2), withAttributes: labelAttrs)

                // The item is drawn at its natural size — this is exactly
                // the bitmap the menu bar gets.
                let itemY = top + (rowHeight - row.1.size.height) / 2
                row.1.draw(at: CGPoint(x: padding + labelColumn, y: itemY), from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
    }

    private func iconSheet(metrics: [MetricKind], sample: MetricSample, isDark: Bool) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: labelColor(isDark: isDark)]
        let cell = CGSize(width: 78, height: 62)
        let padding: CGFloat = 12
        let columns = metrics.count
        let size = CGSize(width: padding * 2 + cell.width * CGFloat(columns), height: padding * 2 + cell.height)
        let tintBase: NSColor = isDark ? NSColor(white: 1, alpha: 0.94) : NSColor(white: 0.11, alpha: 1)

        return NSImage(size: size, flipped: false) { _ in
            self.background(isDark: isDark).setFill()
            NSRect(origin: .zero, size: size).fill()

            for (index, metric) in metrics.enumerated() {
                let originX = padding + cell.width * CGFloat(index)
                let icon = MetricIconLibrary.image(for: metric, pointSize: 22, sample: sample)
                // Same per-metric palette the menu bar uses in colour mode.
                let tint = StatusItemContentRenderer.iconTintColor(
                    metric: metric,
                    sample: sample,
                    accent: NSColor(hex: AccentOption.cyan.rawValue)!,
                    base: tintBase,
                    colorMode: .perMetric
                )
                let tinted = icon.tinted(with: tint)
                tinted.draw(at: CGPoint(x: originX + (cell.width - tinted.size.width) / 2, y: padding + 26), from: .zero, operation: .sourceOver, fraction: 1)

                let label = metric.displayName
                let textSize = label.size(withAttributes: labelAttrs)
                label.draw(at: CGPoint(x: originX + (cell.width - textSize.width) / 2, y: padding + 6), withAttributes: labelAttrs)
            }
            return true
        }
    }

    /// NSImage draws in points; the README wants real pixels, so everything
    /// is rasterised at 2x for a retina-crisp PNG.
    private func write(_ image: NSImage, named name: String) throws {
        let pixelSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw XCTSkip("could not allocate a bitmap for \(name)")
        }
        rep.size = image.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw XCTSkip("could not encode \(name)")
        }
        try data.write(to: outputDirectory.appendingPathComponent(name))
        XCTAssertGreaterThan(data.count, 1_000, "\(name) looks empty")
    }
}

// MARK: - The panel

extension ReadmeAssetTests {
    /// Draws the real `PanelView` offscreen through NSHostingView. The
    /// numbers come from `busySample()` rather than from this machine, so
    /// the image is the same every time it's regenerated and doesn't
    /// publish the author's running apps.
    func testGeneratePanel() throws {
        let engine = SystemMetricsEngine.shared
        engine.isPanelOpen = false
        AppSettings.shared.sampleInterval = .fiveSeconds
        AppSettings.shared.showProcesses = true

        var sample = busySample()
        sample.topProcesses = [
            ProcessUsage(id: 1, name: "Xcode", cpuPercent: 62.4, memoryMB: 3180),
            ProcessUsage(id: 2, name: "Blender", cpuPercent: 28.1, memoryMB: 2440),
            ProcessUsage(id: 3, name: "Safari", cpuPercent: 9.7, memoryMB: 1290),
            ProcessUsage(id: 4, name: "Music", cpuPercent: 3.2, memoryMB: 410)
        ]

        defer { SystemMetricsEngine.shared.unfreezeForTesting() }

        for isDark in [true, false] {
            let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            let image = try renderPanel(sample: sample, appearance: appearance)
            try write(image, named: isDark ? "panel-dark.png" : "panel-light.png")
        }
    }

    private func renderPanel(sample: MetricSample, appearance: NSAppearance?) throws -> NSImage {
        let hosting = NSHostingView(rootView: PanelView(
            onOpenActivityMonitor: {},
            onOpenSettings: {},
            onOpenAbout: {}
        ))
        hosting.appearance = appearance

        // The panel deliberately draws no background of its own — NSPopover
        // supplies the material at runtime — so the image needs one, or it
        // comes out as floating text on transparency.
        let container = NSView(frame: .zero)
        container.appearance = appearance
        container.wantsLayer = true
        container.layer?.backgroundColor = (appearance?.name == .darkAqua
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor(calibratedWhite: 0.97, alpha: 1)).cgColor
        container.addSubview(hosting)

        // A real window: SwiftUI measures and draws through one, and an
        // orphan view hierarchy renders blank.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = container
        window.appearance = appearance

        // Freeze twice on purpose: the first call cancels the timer, the
        // run loop below lets a tick that was already in flight deliver its
        // own reading, and the second call is then the last word.
        SystemMetricsEngine.shared.freezeForTesting(sample)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        SystemMetricsEngine.shared.freezeForTesting(sample)
        // Let SwiftUI take the new value, lay out, and settle.
        for _ in 0..<12 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        // Nothing else writes to the engine while it's frozen, so what's on
        // screen now is exactly the fixture.
        XCTAssertEqual(SystemMetricsEngine.shared.sample.cpuPercent, sample.cpuPercent)

        let fitting = hosting.fittingSize
        window.setContentSize(fitting)
        container.frame = NSRect(origin: .zero, size: fitting)
        hosting.frame = container.bounds
        hosting.layoutSubtreeIfNeeded()
        for _ in 0..<6 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        guard let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else {
            throw XCTSkip("no bitmap for the panel")
        }
        container.cacheDisplay(in: container.bounds, to: rep)

        let image = NSImage(size: container.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
