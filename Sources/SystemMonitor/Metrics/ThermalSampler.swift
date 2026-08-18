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
    struct Result {
        var celsius: Double?
        var state: ThermalState
        var fanRPM: Int?
    }

    func sample() -> Result {
        let state: ThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: state = .nominal
        case .fair: state = .fair
        case .serious: state = .serious
        case .critical: state = .critical
        @unknown default: state = .nominal
        }
        return Result(celsius: nil, state: state, fanRPM: nil)
    }
}
