import Foundation
import Darwin

/// Physical memory via host_statistics64 (VM stats) and swap via the
/// vm.swapusage sysctl — same sources Activity Monitor uses internally.
///
/// RAM figures (total/used/active/wired/compressed) are reported in GiB,
/// not decimal GB, unlike every other size in this app. Apple's spec sheet
/// and "Sobre este Mac" both label a machine's physical memory using GiB
/// magnitude while writing "GB" — a 16 GiB machine is sold as "16GB". A
/// literal bytes/1e9 conversion (the convention Finder/diskutil use for
/// storage, and what disk/swap use here) turns that same 16 GiB machine
/// into "17,18 GB", which reads as a bug against the number on the spec
/// sheet, not a rounding convention. Storage keeps decimal GB below — disk
/// capacities really are decimal on macOS, so it still needs to.
final class MemorySampler {
    struct Result {
        var usedGB: Double
        var totalGB: Double
        var activeGB: Double
        var wiredGB: Double
        var compressedGB: Double
        var swapUsedGB: Double
        var swapTotalGB: Double
    }

    private let totalPhysicalBytes: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    private static let bytesPerGiB = 1_073_741_824.0

    func sample() -> Result {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }

        let totalGB = Double(totalPhysicalBytes) / Self.bytesPerGiB
        guard kr == KERN_SUCCESS else {
            return Result(usedGB: 0, totalGB: totalGB, activeGB: 0, wiredGB: 0, compressedGB: 0, swapUsedGB: 0, swapTotalGB: 0)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pageBytes = Double(pageSize)

        let active = Double(stats.active_count) * pageBytes
        let wired = Double(stats.wire_count) * pageBytes
        let compressed = Double(stats.compressor_page_count) * pageBytes
        let used = active + wired + compressed

        let (swapUsed, swapTotal) = Self.readSwapUsage()

        return Result(
            usedGB: used / Self.bytesPerGiB,
            totalGB: totalGB,
            activeGB: active / Self.bytesPerGiB,
            wiredGB: wired / Self.bytesPerGiB,
            compressedGB: compressed / Self.bytesPerGiB,
            // Swap keeps decimal GB: it's a dynamic pool macOS manages on
            // its own, not a number Apple prints on a spec sheet for
            // someone to compare this reading against.
            swapUsedGB: swapUsed / 1e9,
            swapTotalGB: swapTotal / 1e9
        )
    }

    private static func readSwapUsage() -> (used: Double, total: Double) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (Double(usage.xsu_used), Double(usage.xsu_total))
    }
}
