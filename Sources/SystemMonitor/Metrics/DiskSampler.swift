import Foundation
import Darwin

/// Disk usage via getattrlist's ATTR_VOL_SPACEUSED on the Data volume.
///
/// "/" on current macOS is the read-only sealed system snapshot, not where
/// your files live — statfs("/") reports a container-wide total (right) but
/// its own tiny system-volume usage (~13 GB on a fresh install), and doing
/// total-minus-available instead double-counts every other APFS volume
/// sharing the same container (System, Preboot, Recovery, VM), overstating
/// "used" by tens of GB. `/System/Volumes/Data` is the volume Finder and
/// `diskutil apfs list` actually mean by "used" — ATTR_VOL_SPACEUSED there
/// matches `diskutil`'s "Capacity Consumed" for the Data volume exactly
/// (verified against this machine's own `diskutil apfs list` output).
final class DiskSampler {
    struct Result {
        var usedGB: Double
        var totalGB: Double
    }

    private let volumePath = "/System/Volumes/Data"

    func sample() -> Result {
        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrList.volattr = ATTR_VOL_INFO | UInt32(ATTR_VOL_SIZE) | UInt32(ATTR_VOL_SPACEAVAIL) | UInt32(ATTR_VOL_SPACEUSED)

        // The kernel returns these tightly packed (length: 4 bytes, then
        // three 8-byte off_t values back to back, no alignment padding) —
        // a Swift/C struct with natural off_t alignment would read every
        // field 4 bytes off. Reading fixed offsets from raw bytes sidesteps
        // that mismatch entirely.
        var buffer = [UInt8](repeating: 0, count: 32)
        let result = buffer.withUnsafeMutableBytes { ptr -> Int32 in
            getattrlist(volumePath, &attrList, ptr.baseAddress, ptr.count, 0)
        }
        guard result == 0 else {
            return fallback()
        }

        let total = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
        let used = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 20, as: Int64.self) }

        return Result(usedGB: Double(used) / 1e9, totalGB: Double(total) / 1e9)
    }

    /// statfs total-minus-available on "/" — overstates usage (see above)
    /// but is still a reasonable fallback if getattrlist ever fails.
    private func fallback() -> Result {
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
