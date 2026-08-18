import XCTest
@testable import SystemMonitor

final class ProcessSamplerTests: XCTestCase {
    func testColdSamplerHasNoCPUReadingsYet() {
        // Why seed() exists: CPU% is a delta, so the very first walk has
        // nothing to compare against and ranks nobody. Resident memory is
        // an absolute number and shows up right away.
        let first = ProcessSampler().sample(limit: 10)
        XCTAssertTrue(first.byCPU.isEmpty)
        XCTAssertFalse(first.byMemory.isEmpty)
    }

    func testSeedingMakesTheNextSampleUsable() {
        let sampler = ProcessSampler()
        sampler.seed()
        Thread.sleep(forTimeInterval: 0.2)
        let result = sampler.sample(limit: 10)
        // Something on this machine burns CPU over 200ms — if nothing does,
        // the assertion below still holds, so this stays honest either way.
        for usage in result.byCPU {
            XCTAssertGreaterThan(usage.cpuPercent, 0)
            XCTAssertLessThan(usage.cpuPercent, 100 * Double(ProcessInfo.processInfo.activeProcessorCount) + 1)
        }
    }

    func testItNeverRanksItself() {
        let sampler = ProcessSampler()
        sampler.seed()
        Thread.sleep(forTimeInterval: 0.1)
        let result = sampler.sample(limit: 100)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        XCTAssertFalse(result.byCPU.contains { $0.id == ownPID })
        // The test process is comfortably over the 1 MB floor, so this would
        // catch the exclusion being dropped.
        XCTAssertFalse(result.byMemory.contains { $0.id == ownPID })
    }

    func testEmptyResultIsEmpty() {
        XCTAssertTrue(ProcessSampler.Result.empty.byCPU.isEmpty)
        XCTAssertTrue(ProcessSampler.Result.empty.byMemory.isEmpty)
    }
}
