import Foundation

struct ProcessUsage: Identifiable, Equatable {
    let id: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
}

/// One full snapshot of every metric, plus the rolling history needed for
/// sparklines. This is the single value the menu bar icons and the panel
/// both observe.
struct MetricSample: Equatable {
    // CPU
    var cpuPercent: Double = 0
    var cpuUserPercent: Double = 0
    var cpuSystemPercent: Double = 0
    var cpuHistory: [Double] = []
    var cpuModel: String = ""
    var cpuCoreCount: Int = 0

    // Memory
    var memoryUsedGB: Double = 0
    var memoryTotalGB: Double = 0
    var memoryActiveGB: Double = 0
    var memoryWiredGB: Double = 0
    var memoryCompressedGB: Double = 0
    var swapUsedGB: Double = 0
    var swapTotalGB: Double = 0

    // Disk
    var diskUsedGB: Double = 0
    var diskTotalGB: Double = 0
    var diskReadRate: Double = 0 // MB/s
    var diskWriteRate: Double = 0 // MB/s

    // Network (MB/s)
    var networkDownRate: Double = 0
    var networkUpRate: Double = 0

    // Thermal
    var thermalState: ThermalState = .nominal
    /// Hottest CPU die reading in °C, nil on machines that don't expose
    /// the HID temperature sensors.
    var cpuTemperatureCelsius: Double?

    // Battery
    var batteryPercent: Int?
    var batteryTimeRemainingMinutes: Int?
    var isCharging: Bool = false

    // Processes
    /// Candidate pool for the panel's "maiores consumos" list: the union of
    /// top-by-CPU and top-by-memory (deduplicated by pid) — see
    /// SystemMetricsEngine. Each entry already carries both cpuPercent and
    /// memoryMB, so sorting the panel by either metric never drops a
    /// process that was only prominent in the other.
    var processes: [ProcessUsage] = []
    /// The panel just opened and the process baseline was seeded this tick,
    /// so there's no reading yet — the list shows a placeholder rather than
    /// collapsing to nothing and pushing the panel's height around.
    var processesPending: Bool = false

    // Derived
    var isCritical: Bool = false

    var memoryFraction: Double { memoryTotalGB > 0 ? memoryUsedGB / memoryTotalGB : 0 }
    var diskFraction: Double { diskTotalGB > 0 ? diskUsedGB / diskTotalGB : 0 }

    /// `.serious`/`.critical` are the two states where macOS is actually
    /// throttling CPU/GPU to shed heat, not just running warm.
    var isThermalThrottling: Bool { thermalState == .serious || thermalState == .critical }
}

enum ThermalState: String, Equatable {
    case nominal, fair, serious, critical

    var label: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return L10n.t("elevado", "elevated")
        case .serious: return L10n.t("alto", "high")
        case .critical: return "throttling"
        }
    }
}
