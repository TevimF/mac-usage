import Foundation

/// Thermal pressure via ProcessInfo.thermalState (the public API) plus the
/// hottest CPU die temperature from the HID sensors when this machine
/// exposes them — see TemperatureSensorReader.
///
/// Raw SMC temperature was evaluated and dropped: IOConnectCallStructMethod
/// against the AppleSMC user client returns kIOReturnNotPrivileged for
/// third-party processes on current macOS.
final class ThermalSampler {
    struct Reading {
        var state: ThermalState
        var celsius: Double?
    }

    private let temperatureReader = TemperatureSensorReader()

    func sample() -> Reading {
        Reading(state: currentState(), celsius: temperatureReader?.hottestCelsius())
    }

    private func currentState() -> ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
