import Combine
import XCTest
@testable import SystemMonitor

/// Drives the real engine through the panel-open transition — the one path
/// that changed shape, and the one the unit tests around it can't reach.
/// Uses the shared instance because that's what the app runs; the timer is
/// already going either way.
final class SystemMetricsEngineTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var originalShowProcesses = true
    private var originalInterval: SampleInterval = .twoSeconds

    override func setUp() {
        super.setUp()
        originalShowProcesses = AppSettings.shared.showProcesses
        originalInterval = AppSettings.shared.sampleInterval
        AppSettings.shared.showProcesses = true
        AppSettings.shared.sampleInterval = .oneSecond
    }

    override func tearDown() {
        SystemMetricsEngine.shared.isPanelOpen = false
        cancellables.removeAll()
        AppSettings.shared.showProcesses = originalShowProcesses
        AppSettings.shared.sampleInterval = originalInterval
        super.tearDown()
    }

    func testOpeningThePanelAnnouncesPendingThenDeliversRows() {
        let engine = SystemMetricsEngine.shared
        engine.isPanelOpen = false

        let sawPending = expectation(description: "first sample after opening is pending")
        let sawRows = expectation(description: "process rows arrive a tick later")
        var pendingCameFirst = false

        engine.$sample
            .dropFirst()
            .sink { sample in
                if sample.processesPending, sample.processes.isEmpty {
                    pendingCameFirst = true
                    sawPending.fulfill()
                }
                if !sample.processes.isEmpty, pendingCameFirst {
                    sawRows.fulfill()
                }
            }
            .store(in: &cancellables)

        engine.isPanelOpen = true
        wait(for: [sawPending, sawRows], timeout: 10, enforceOrder: true)

        // And the readings that land are real, not a divide-by-nothing.
        let ceiling = 100 * Double(ProcessInfo.processInfo.activeProcessorCount) + 1
        for usage in engine.sample.processes {
            XCTAssertGreaterThan(usage.cpuPercent, 0)
            XCTAssertLessThan(usage.cpuPercent, ceiling)
        }
    }

    func testClosingThePanelStopsProducingProcessRows() {
        let engine = SystemMetricsEngine.shared
        engine.isPanelOpen = true

        let gotRows = expectation(description: "rows while open")
        engine.$sample
            .sink { if !$0.processes.isEmpty { gotRows.fulfill() } }
            .store(in: &cancellables)
        wait(for: [gotRows], timeout: 10)
        cancellables.removeAll()

        engine.isPanelOpen = false
        let wentQuiet = expectation(description: "no rows once closed")
        engine.$sample
            .dropFirst()
            .sink { sample in
                XCTAssertTrue(sample.processes.isEmpty)
                XCTAssertFalse(sample.processesPending)
                wentQuiet.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [wentQuiet], timeout: 10)
    }
}

// MARK: - Process pool merging

extension SystemMetricsEngineTests {
    /// The panel lets a person sort the "maiores consumos" list by CPU or
    /// by RAM. Neither of ProcessSampler's own rankings is enough on its
    /// own: a process could be a memory hog without showing up in the
    /// top-by-CPU list, or vice versa. SystemMetricsEngine.mergeCandidates
    /// is what stitches the two together, and this is what would catch it
    /// silently dropping one side.
    func testMergeUnionsBothRankingsWithoutDuplicates() {
        let onlyInCPU = ProcessUsage(id: 1, name: "Xcode", cpuPercent: 80, memoryMB: 50)
        let onlyInMemory = ProcessUsage(id: 2, name: "Blender", cpuPercent: 1, memoryMB: 4000)
        let inBoth = ProcessUsage(id: 3, name: "Safari", cpuPercent: 40, memoryMB: 2000)

        let result = ProcessSampler.Result(
            byCPU: [onlyInCPU, inBoth],
            byMemory: [onlyInMemory, inBoth]
        )

        let merged = SystemMetricsEngine.mergeCandidates(result)

        // A RAM-heavy process that never cracked the CPU ranking still has
        // to be reachable once the panel is sorted by RAM — this is the
        // failure this whole merge exists to prevent.
        XCTAssertTrue(merged.contains { $0.id == onlyInMemory.id })
        // Same the other way around.
        XCTAssertTrue(merged.contains { $0.id == onlyInCPU.id })
        // Present in both source rankings, but only once in the pool.
        XCTAssertEqual(merged.filter { $0.id == inBoth.id }.count, 1)
        XCTAssertEqual(merged.count, 3)
    }

    func testMergeOfTwoEmptyRankingsIsEmpty() {
        XCTAssertTrue(SystemMetricsEngine.mergeCandidates(.empty).isEmpty)
    }
}
