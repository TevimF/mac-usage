import Foundation
import IOKit

/// Reads die temperatures from the HID temperature sensors (usage page
/// 0xff00, usage 5) — the same source `powermetrics` and every third-party
/// temperature app uses on Apple Silicon.
///
/// Why not SMC: IOConnectCallStructMethod against AppleSMC returns
/// kIOReturnNotPrivileged for third-party processes. The HID sensor path
/// has no such restriction, but the symbols are private, so they're
/// resolved with dlsym instead of linked. Any missing symbol or empty
/// match just yields nil and the panel falls back to the qualitative
/// thermal state.
final class TemperatureSensorReader {
    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatchingFn = @convention(c) (AnyObject, CFDictionary?) -> Void
    private typealias CopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyEventFn = @convention(c) (AnyObject, Int64, Int32, Int32) -> Unmanaged<AnyObject>?
    private typealias GetFloatFn = @convention(c) (AnyObject, Int32) -> Double
    private typealias CopyPropertyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?

    /// kIOHIDEventTypeTemperature; the float field is the type shifted into
    /// the event-field encoding IOHIDEventGetFloatValue expects.
    private static let temperatureEventType: Int64 = 15
    private static let temperatureField: Int32 = 15 << 16

    /// The service clients borrow locks owned by the event system client —
    /// letting it deallocate after init crashes the next read with
    /// "os_unfair_lock is corrupt", so it's held for the reader's lifetime.
    private let client: AnyObject
    private let copyEvent: CopyEventFn
    private let getFloat: GetFloatFn
    /// Services matching CPU/SoC die sensors, resolved once — the set
    /// doesn't change while the machine is running.
    private let services: [AnyObject]

    init?() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return nil }
        func symbol<T>(_ name: String, _ type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        guard
            let create = symbol("IOHIDEventSystemClientCreate", CreateFn.self),
            let setMatching = symbol("IOHIDEventSystemClientSetMatching", SetMatchingFn.self),
            let copyServices = symbol("IOHIDEventSystemClientCopyServices", CopyServicesFn.self),
            let copyEvent = symbol("IOHIDServiceClientCopyEvent", CopyEventFn.self),
            let getFloat = symbol("IOHIDEventGetFloatValue", GetFloatFn.self),
            let copyProperty = symbol("IOHIDServiceClientCopyProperty", CopyPropertyFn.self),
            let client = create(kCFAllocatorDefault)?.takeRetainedValue()
        else { return nil }

        setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let all = copyServices(client)?.takeRetainedValue() as? [AnyObject] else { return nil }

        let matched = all.filter { service in
            guard let name = copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String
            else { return false }
            return Self.isDieSensor(name)
        }
        guard !matched.isEmpty else { return nil }

        self.client = client
        self.copyEvent = copyEvent
        self.getFloat = getFloat
        self.services = matched
    }

    /// Hottest die reading in °C, or nil if every sensor came back empty or
    /// implausible this tick. The hottest core is what throttles, so max
    /// tracks the thermal state better than an average would.
    func hottestCelsius() -> Double? {
        var hottest: Double?
        for service in services {
            guard let event = copyEvent(service, Self.temperatureEventType, 0, 0)?.takeRetainedValue()
            else { continue }
            let value = getFloat(event, Self.temperatureField)
            guard value > 1, value < 130 else { continue }
            if hottest == nil || value > hottest! { hottest = value }
        }
        return hottest
    }

    /// Apple Silicon exposes per-cluster die sensors as "PMU tdie3"/"PMU2
    /// tdie3"; Intel Macs report "PECI CPU"/"TCXC". Battery, NAND and
    /// ambient sensors are deliberately left out — they read much cooler
    /// and would hide a hot CPU.
    private static func isDieSensor(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("tdie") { return true }
        if lower.contains("peci") { return true }
        return lower.contains("cpu") || lower.contains("soc")
    }
}
