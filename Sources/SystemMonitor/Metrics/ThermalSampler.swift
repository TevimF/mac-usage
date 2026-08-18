import Foundation

/// Thermal pressure via ProcessInfo.thermalState, the public API.
///
/// Raw SMC temperature was evaluated and dropped: IOConnectCallStructMethod
/// against the AppleSMC user client returns kIOReturnNotPrivileged for
/// third-party processes on current macOS — it requires a private
/// entitlement Apple doesn't grant outside its own apps. Showing a made-up
/// number would be worse than showing the qualitative state the OS actually
/// gives us.
final class ThermalSampler {
    func sample() -> ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
