import Foundation
import Darwin

/// Top processes by CPU% and by resident memory.
///
/// CPU% is computed the same way Activity Monitor does: the delta in each
/// process's accumulated user+system time between two polls, divided by
/// wall-clock elapsed time. One core fully busy = 100%.
///
/// Process names are resolved only for the handful that actually make it
/// into a top list — `proc_name` on every pid would be ~600 extra syscalls
/// per tick for rows nobody sees.
final class ProcessSampler {
    struct Result {
        var byCPU: [ProcessUsage]
        var byMemory: [ProcessUsage]
    }

    private struct RawUsage {
        let pid: Int32
        let cpuPercent: Double
        let memoryMB: Double
    }

    private var previousTimes: [Int32: (nanos: UInt64, timestamp: Date)] = [:]
    private let timebase: mach_timebase_info = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return info
    }()

    func sample(limit: Int) -> Result {
        // Excluded on purpose: this app briefly spikes its own CPU while
        // actively drawing the open panel, and showing up in your own
        // "biggest consumers" list is confusing self-reference, not a
        // useful reading of what else is running on the machine.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let pids = Self.listPIDs().filter { $0 != ownPID }
        let now = Date()
        var raw: [RawUsage] = []
        raw.reserveCapacity(pids.count)

        for pid in pids {
            guard let info = Self.taskInfo(pid: pid) else { continue }
            let nanos = ticksToNanoseconds(info.pti_total_user + info.pti_total_system)
            let memoryMB = Double(info.pti_resident_size) / 1_048_576

            var cpuPercent = 0.0
            if let prev = previousTimes[pid] {
                let elapsed = now.timeIntervalSince(prev.timestamp)
                if elapsed > 0, nanos >= prev.nanos {
                    cpuPercent = Double(nanos - prev.nanos) / 1_000_000_000 / elapsed * 100
                }
            }
            previousTimes[pid] = (nanos, now)

            raw.append(RawUsage(pid: pid, cpuPercent: cpuPercent, memoryMB: memoryMB))
        }

        let currentSet = Set(pids)
        previousTimes = previousTimes.filter { currentSet.contains($0.key) }

        let topCPU = raw.filter { $0.cpuPercent > 0.05 }
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(limit)
        let topMemory = raw.filter { $0.memoryMB > 1 }
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(limit)

        return Result(byCPU: topCPU.map(resolve), byMemory: topMemory.map(resolve))
    }

    private func resolve(_ usage: RawUsage) -> ProcessUsage {
        ProcessUsage(
            id: usage.pid,
            name: Self.processName(pid: usage.pid),
            cpuPercent: usage.cpuPercent,
            memoryMB: usage.memoryMB
        )
    }

    private func ticksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        guard timebase.denom != 0 else { return ticks }
        return ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private static func taskInfo(pid: Int32) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, size)
        }
        guard result == size else { return nil }
        return info
    }

    private static func listPIDs() -> [Int32] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        let capacity = Int(bufferSize) / MemoryLayout<Int32>.stride
        var pids = [Int32](repeating: 0, count: capacity)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        guard actualSize > 0 else { return [] }
        let count = Int(actualSize) / MemoryLayout<Int32>.stride
        return pids.prefix(count).filter { $0 > 0 }
    }

    private static func processName(pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return "pid \(pid)" }
        return String(cString: buffer)
    }
}
