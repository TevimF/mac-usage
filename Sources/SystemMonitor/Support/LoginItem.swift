import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService (macOS 13+), the current API for
/// registering a login item — replaces the legacy SMLoginItemSetEnabled.
enum LoginItem {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
    }
}
