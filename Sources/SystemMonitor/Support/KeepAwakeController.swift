import Foundation
import IOKit.pwr_mgt

/// Prevents the display from sleeping due to inactivity — the same public
/// IOKit power-management assertion Caffeine/Amphetamine use (no private
/// APIs, no entitlements). Deliberately not persisted across launches: like
/// the original Caffeine, it resets to off when the app restarts instead of
/// silently holding an assertion left over from a previous session.
final class KeepAwakeController: ObservableObject {
    static let shared = KeepAwakeController()

    @Published private(set) var isActive = false
    private var assertionID: IOPMAssertionID = 0

    private init() {}

    func toggle() {
        isActive ? disable() : enable()
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
    }

    private func disable() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}
