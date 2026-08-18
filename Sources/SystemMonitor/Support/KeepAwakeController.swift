import Foundation
import IOKit.pwr_mgt

/// Prevents the display from sleeping due to inactivity — the same public
/// IOKit power-management assertion Caffeine/Amphetamine use (no private
/// APIs, no entitlements). Deliberately not persisted across launches: like
/// the original Caffeine, it resets to off when the app restarts instead of
/// silently holding an assertion left over from a previous session.
///
/// Auto-disables after the duration configured in Settings — indefinite is
/// its own case, not a magic number, so there's no risk of "0 minutes"
/// silently meaning "forever" somewhere down the line.
final class KeepAwakeController: ObservableObject {
    static let shared = KeepAwakeController()

    @Published private(set) var isActive = false
    private var assertionID: IOPMAssertionID = 0
    private var autoDisableTimer: Timer?
    private var activatedAt: Date?

    private init() {}

    func toggle() {
        isActive ? disable() : enable()
    }

    var remainingSeconds: TimeInterval? {
        guard isActive, let activatedAt, AppSettings.shared.keepAwakeDuration != .indefinite else { return nil }
        let elapsed = Date().timeIntervalSince(activatedAt)
        return max(0, AppSettings.shared.keepAwakeDuration.rawValue - elapsed)
    }

    private func enable() {
        guard !isActive else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Mac usage — manter tela acesa" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            NSLog("KeepAwakeController: failed to create assertion (\(result))")
            return
        }
        assertionID = id
        isActive = true
        activatedAt = Date()
        scheduleAutoDisable()
    }

    private func disable() {
        guard isActive else { return }
        autoDisableTimer?.invalidate()
        autoDisableTimer = nil
        activatedAt = nil
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }

    private func scheduleAutoDisable() {
        autoDisableTimer?.invalidate()
        autoDisableTimer = nil
        let duration = AppSettings.shared.keepAwakeDuration
        guard duration != .indefinite else { return }
        autoDisableTimer = Timer.scheduledTimer(withTimeInterval: duration.rawValue, repeats: false) { [weak self] _ in
            self?.disable()
        }
    }
}
