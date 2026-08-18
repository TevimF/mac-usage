import Foundation

/// One measurable system resource. Each case maps to one icon in the
/// custom 24pt-grid icon family from the design spec (section 04).
enum MetricKind: String, Codable, CaseIterable, Identifiable {
    case cpu, ram, swap, disk, network, thermal, battery, gpu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .swap: return "Swap"
        case .disk: return "Disco"
        case .network: return "Rede"
        case .thermal: return "Térmico"
        case .battery: return "Bateria"
        case .gpu: return "GPU"
        }
    }

    /// Metrics that carry two directional values (e.g. network down/up) use
    /// the two-line status item layout instead of a single value capsule.
    var isDualValue: Bool { self == .network }

    /// Whether this metric is currently implemented end-to-end. GPU has an
    /// icon in the family but no reliable public data source yet.
    var isAvailable: Bool { self != .gpu }
}
