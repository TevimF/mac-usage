import Foundation
import Darwin

/// Per-core CPU load via host_processor_info — no subprocess spawning.
/// Percentages are deltas between consecutive ticks, matching Activity
/// Monitor's convention (aggregate across all cores, 0–100%).
final class CPUSampler {
    struct Result {
        var totalPercent: Double
        var userPercent: Double
        var systemPercent: Double
        var model: String
        var coreCount: Int
    }

    private var previousLoad: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
    private let model: String
    private let coreCount: Int

    init() {
        model = Self.readCPUModel()
        coreCount = Self.readCoreCount()
    }

    func sample() -> Result {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)
        guard kr == KERN_SUCCESS, let info = cpuInfo else {
            return Result(totalPercent: 0, userPercent: 0, systemPercent: 0, model: model, coreCount: coreCount)
        }
        defer {
            let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: Int(bitPattern: info)), size)
        }

        var newLoad: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
        newLoad.reserveCapacity(Int(numCPUsU))

        var userDelta: UInt32 = 0
        var systemDelta: UInt32 = 0
        var idleDelta: UInt32 = 0
        var niceDelta: UInt32 = 0

        for i in 0..<Int(numCPUsU) {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt32(info[base + Int(CPU_STATE_USER)])
            let system = UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(info[base + Int(CPU_STATE_NICE)])
            newLoad.append((user, system, idle, nice))

            if previousLoad.indices.contains(i) {
                let prev = previousLoad[i]
                userDelta += user &- prev.user
                systemDelta += system &- prev.system
                idleDelta += idle &- prev.idle
                niceDelta += nice &- prev.nice
            }
        }
        previousLoad = newLoad

        let totalTicks = Double(userDelta) + Double(systemDelta) + Double(idleDelta) + Double(niceDelta)
        guard totalTicks > 0 else {
            return Result(totalPercent: 0, userPercent: 0, systemPercent: 0, model: model, coreCount: coreCount)
        }

        let userPct = (Double(userDelta) + Double(niceDelta)) / totalTicks * 100
        let systemPct = Double(systemDelta) / totalTicks * 100

        return Result(totalPercent: userPct + systemPct, userPercent: userPct, systemPercent: systemPct, model: model, coreCount: coreCount)
    }

    private static func readCPUModel() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        return String(cString: buf).trimmingCharacters(in: .whitespaces)
    }

    private static func readCoreCount() -> Int {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &count, &size, nil, 0)
        return Int(count)
    }
}
