import XCTest
@testable import SystemMonitor

/// The alert is defined in seconds, and these pin that down — the bug this
/// replaced counted ticks, so the same load tripped the alert at 6s with
/// the panel open and 15s with it closed.
final class CriticalTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testCalmLoadNeverTrips() {
        var tracker = CriticalTracker(threshold: 90, sustainedFor: 10)
        for step in stride(from: 0.0, through: 60.0, by: 1.0) {
            XCTAssertFalse(tracker.update(cpuPercent: 89.9, now: start.addingTimeInterval(step)))
        }
    }

    func testHighLoadHasToLast() {
        var tracker = CriticalTracker(threshold: 90, sustainedFor: 10)
        XCTAssertFalse(tracker.update(cpuPercent: 99, now: start))
        XCTAssertFalse(tracker.update(cpuPercent: 99, now: start.addingTimeInterval(9.9)))
        XCTAssertTrue(tracker.update(cpuPercent: 99, now: start.addingTimeInterval(10)))
    }

    func testOneCalmReadingRestartsTheClock() {
        var tracker = CriticalTracker(threshold: 90, sustainedFor: 10)
        _ = tracker.update(cpuPercent: 99, now: start)
        XCTAssertFalse(tracker.update(cpuPercent: 12, now: start.addingTimeInterval(9)))
        // 9s of high load already banked, but the dip spent it: the streak
        // starts over from here, so 10s from *this* point, not from t0.
        XCTAssertFalse(tracker.update(cpuPercent: 99, now: start.addingTimeInterval(10)))
        XCTAssertFalse(tracker.update(cpuPercent: 99, now: start.addingTimeInterval(19.9)))
        XCTAssertTrue(tracker.update(cpuPercent: 99, now: start.addingTimeInterval(20)))
    }

    func testItTripsAtTheSameMomentAtEverySamplingInterval() {
        // 1s is the fastest the panel samples, 5s is what runs with the
        // panel closed. Same load, same wall clock, same answer.
        for interval in [1.0, 2.0, 5.0] {
            var tracker = CriticalTracker(threshold: 90, sustainedFor: 10)
            var trippedAt: TimeInterval?
            for step in stride(from: 0.0, through: 30.0, by: interval) {
                if tracker.update(cpuPercent: 95, now: start.addingTimeInterval(step)), trippedAt == nil {
                    trippedAt = step
                }
            }
            XCTAssertEqual(trippedAt, 10, "interval \(interval)s tripped at \(String(describing: trippedAt))s")
        }
    }

    func testRecoveryClearsItImmediately() {
        var tracker = CriticalTracker(threshold: 90, sustainedFor: 10)
        for step in stride(from: 0.0, through: 15.0, by: 1.0) {
            _ = tracker.update(cpuPercent: 99, now: start.addingTimeInterval(step))
        }
        XCTAssertFalse(tracker.update(cpuPercent: 30, now: start.addingTimeInterval(16)))
    }
}
