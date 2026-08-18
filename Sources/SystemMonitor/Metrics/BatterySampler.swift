import Foundation
import IOKit.ps

/// Battery state via IOPowerSources. Returns nils on desktop Macs with no
/// battery — callers hide the battery card in that case.
final class BatterySampler {
    struct Result {
        var percent: Int?
        var minutesRemaining: Int?
        var isCharging: Bool
    }

    func sample() -> Result {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return Result(percent: nil, minutesRemaining: nil, isCharging: false)
        }

        let capacity = description[kIOPSCurrentCapacityKey] as? Int
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Int
        let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
        let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
        let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int

        var percent: Int?
        if let capacity, let maxCapacity, maxCapacity > 0 {
            percent = Int((Double(capacity) / Double(maxCapacity) * 100).rounded())
        }

        let minutesRemaining: Int?
        if isCharging {
            minutesRemaining = (timeToFull ?? -1) > 0 ? timeToFull : nil
        } else {
            minutesRemaining = (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil
        }

        return Result(percent: percent, minutesRemaining: minutesRemaining, isCharging: isCharging)
    }
}
