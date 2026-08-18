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
                if sample.processesPending, sample.topProcesses.isEmpty {
                    pendingCameFirst = true
                    sawPending.fulfill()
                }
                if !sample.topProcesses.isEmpty, pendingCameFirst {
                    sawRows.fulfill()
                }
            }
            .store(in: &cancellables)

        engine.isPanelOpen = true
        wait(for: [sawPending, sawRows], timeout: 10, enforceOrder: true)

        // And the readings that land are real, not a divide-by-nothing.
        let ceiling = 100 * Double(ProcessInfo.processInfo.activeProcessorCount) + 1
        for usage in engine.sample.topProcesses {
            XCTAssertGreaterThan(usage.cpuPercent, 0)
            XCTAssertLessThan(usage.cpuPercent, ceiling)
        }
    }

    func testClosingThePanelStopsProducingProcessRows() {
        let engine = SystemMetricsEngine.shared
        engine.isPanelOpen = true

        let gotRows = expectation(description: "rows while open")
        engine.$sample
            .sink { if !$0.topProcesses.isEmpty { gotRows.fulfill() } }
            .store(in: &cancellables)
        wait(for: [gotRows], timeout: 10)
        cancellables.removeAll()

        engine.isPanelOpen = false
        let wentQuiet = expectation(description: "no rows once closed")
        engine.$sample
            .dropFirst()
            .sink { sample in
                XCTAssertTrue(sample.topProcesses.isEmpty)
                XCTAssertFalse(sample.processesPending)
                wentQuiet.fulfill()
            }
            .store(in: &cancellables)
        wait(for: [wentQuiet], timeout: 10)
    }
}
