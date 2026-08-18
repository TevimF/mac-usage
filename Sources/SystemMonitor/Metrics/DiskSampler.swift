import Foundation

/// Disk usage for the boot volume via statfs — no Disk Arbitration, no subprocess.
final class DiskSampler {
    struct Result {
        var usedGB: Double
        var totalGB: Double
    }

    func sample() -> Result {
        var stat = statfs()
        guard statfs("/", &stat) == 0 else {
            return Result(usedGB: 0, totalGB: 0)
        }
        let blockSize = Double(stat.f_bsize)
        let total = Double(stat.f_blocks) * blockSize
        let available = Double(stat.f_bavail) * blockSize
        let used = max(0, total - available)
        return Result(usedGB: used / 1e9, totalGB: total / 1e9)
    }
}
