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

    // Network (MB/s)
    var networkDownRate: Double = 0
    var networkUpRate: Double = 0

    // Thermal
    var thermalCelsius: Double?
    var thermalState: ThermalState = .nominal
    var fanRPM: Int?

    // Battery
    var batteryPercent: Int?
    var batteryTimeRemainingMinutes: Int?
    var isCharging: Bool = false

    // Processes
    var topProcesses: [ProcessUsage] = []
    var topMemoryProcesses: [ProcessUsage] = []

    // Derived
    var isCritical: Bool = false

    var memoryFraction: Double { memoryTotalGB > 0 ? memoryUsedGB / memoryTotalGB : 0 }
    var diskFraction: Double { diskTotalGB > 0 ? diskUsedGB / diskTotalGB : 0 }
}

enum ThermalState: String, Equatable {
    case nominal, fair, serious, critical

    var label: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "elevado"
        case .serious: return "alto"
        case .critical: return "throttling"
        }
    }
}
