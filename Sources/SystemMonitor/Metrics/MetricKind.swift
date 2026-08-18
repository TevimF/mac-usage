import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// One measurable system resource. Each case maps to one icon in the
/// custom 24pt-grid icon family from the design spec (section 04).
///
/// Disk space and disk throughput are separate cases on purpose — "how full
/// is it" and "how fast is it moving right now" are different questions,
/// and collapsing them into one metric meant picking one and hiding the
/// other instead of letting the user choose (or show both).
enum MetricKind: String, Codable, CaseIterable, Identifiable {
    case cpu, ram, swap, disk, diskIO, network, thermal, battery, gpu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .swap: return "Swap"
        case .disk: return L10n.t("Disco", "Disk")
        case .diskIO: return L10n.t("Disco E/S", "Disk I/O")
        case .network: return L10n.t("Rede", "Network")
        case .thermal: return L10n.t("Térmico", "Thermal")
        case .battery: return L10n.t("Bateria", "Battery")
        case .gpu: return "GPU"
        }
    }

    /// Metrics that carry two directional values (network down/up, disk
    /// read/write) contribute two chips — instead of one — to a status
    /// item's row.
    var isDualValue: Bool { self == .network || self == .diskIO }

    /// Whether this metric is currently implemented end-to-end. GPU has an
    /// icon in the family but no reliable public data source yet.
    var isAvailable: Bool { self != .gpu }
}

extension MetricKind: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .systemMonitorMetricKind)
    }
}
