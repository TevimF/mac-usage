import Foundation

/// Decides when sustained high CPU counts as "critical" — the state that
/// turns the status item red and puts the alert row in the panel.
///
/// Measured in seconds rather than in ticks. The sampling interval isn't
/// fixed (1/2/5s while the panel is open, 5s while it's closed), so a tick
/// count meant the same load tripped the alert after 6s if you had the
/// panel open and 15s if you didn't — the threshold moved depending on
/// whether anyone was looking at it.
///
/// `sustainedFor` sits above the longest interval on purpose: at 5s
/// sampling it still takes three readings to confirm, so one stray spike
/// between two calm samples can't light it up.
struct CriticalTracker {
    let threshold: Double
    let sustainedFor: TimeInterval

    private var highSince: Date?

    init(threshold: Double = 90, sustainedFor: TimeInterval = 10) {
        self.threshold = threshold
        self.sustainedFor = sustainedFor
    }

    /// Feeds one reading in and returns whether the alert should be on.
    /// Dropping below the threshold clears the streak immediately — the
    /// alert is about load that stays up, so recovery shouldn't linger.
    mutating func update(cpuPercent: Double, now: Date = Date()) -> Bool {
        guard cpuPercent >= threshold else {
            highSince = nil
            return false
        }
        let start = highSince ?? now
        highSince = start
        return now.timeIntervalSince(start) >= sustainedFor
    }
}
