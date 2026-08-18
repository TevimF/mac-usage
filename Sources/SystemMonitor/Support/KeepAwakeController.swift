import Combine
import Foundation
import IOKit.pwr_mgt
import UserNotifications

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
    private var durationObserver: AnyCancellable?

    private init() {
        // Picking a new duration while already active reschedules the
        // running countdown from the original activation moment — without
        // this, the tooltip/panel showed the remaining time implied by the
        // new duration while the timer still fired at the old one. The sink
        // gets the new value as its payload ($-publishers emit at willSet,
        // when the property itself still holds the old duration).
        durationObserver = AppSettings.shared.$keepAwakeDuration
            .dropFirst()
            .sink { [weak self] newDuration in
                guard let self, self.isActive else { return }
                self.scheduleAutoDisable(duration: newDuration)
            }
    }

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
        scheduleAutoDisable(duration: AppSettings.shared.keepAwakeDuration)
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

    private func scheduleAutoDisable(duration: KeepAwakeDuration) {
        autoDisableTimer?.invalidate()
        autoDisableTimer = nil
        guard duration != .indefinite, let activatedAt else { return }
        let remaining = duration.rawValue - Date().timeIntervalSince(activatedAt)
        // Switching to a duration the activation has already outlived just
        // turns it off now — quietly, since the user is mid-interaction.
        guard remaining > 0 else {
            disable()
            return
        }
        autoDisableTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.disable()
            self?.notifyExpired()
        }
    }

    /// Only the timer firing calls this — a manual toggle-off is something
    /// the user just did themselves and doesn't need announcing back to
    /// them. Authorization is requested lazily, at the point a notification
    /// is actually needed; macOS only prompts once per install, so this is
    /// safe to call every time. A denied/undetermined authorization just
    /// means no notification shows — never a crash or a repeated prompt.
    private func notifyExpired() {
        // UNUserNotificationCenter needs a real bundle identifier — calling
        // it from the unbundled debug binary (`swift build && .build/debug/SystemMonitor`,
        // used for quick iteration) has none, so skip rather than risk a
        // runtime fault there. The packaged `Mac usage.app` always has one.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Mac usage"
            content.body = L10n.t(
                "Tela liberada — o tempo de manter tela ativa acabou.",
                "Screen released — the keep-awake time is up."
            )
            let request = UNNotificationRequest(identifier: "keep-awake-expired", content: content, trigger: nil)
            center.add(request)
        }
    }
}
