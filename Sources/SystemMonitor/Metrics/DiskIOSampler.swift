import Foundation
import IOKit

/// Disk throughput (not space) via each IOBlockStorageDriver's cumulative
/// "Statistics" property — the same counters `iostat`/Activity Monitor's
/// Disk tab read — polled and diffed like NetworkSampler does with network
/// byte counters. Summed across every block storage driver present (an
/// external drive adds a second one), so this reads as "how busy is disk
/// I/O right now" rather than being tied to one specific volume.
final class DiskIOSampler {
    struct Result {
        var readRate: Double // MB/s
        var writeRate: Double // MB/s
    }

    private var lastBytesRead: UInt64?
    private var lastBytesWritten: UInt64?
    private var lastTimestamp: Date?

    func sample() -> Result {
        let (bytesRead, bytesWritten) = Self.cumulativeBytes()
        let now = Date()

        defer {
            lastBytesRead = bytesRead
            lastBytesWritten = bytesWritten
            lastTimestamp = now
        }

        guard let prevRead = lastBytesRead, let prevWritten = lastBytesWritten, let last = lastTimestamp else {
            return Result(readRate: 0, writeRate: 0)
        }

        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0, bytesRead >= prevRead, bytesWritten >= prevWritten else {
            return Result(readRate: 0, writeRate: 0)
        }

        let read = Double(bytesRead - prevRead) / elapsed / 1_000_000
        let write = Double(bytesWritten - prevWritten) / elapsed / 1_000_000
        return Result(readRate: read, writeRate: write)
    }

    private static func cumulativeBytes() -> (read: UInt64, written: UInt64) {
        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard let property = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0),
                  let stats = property.takeRetainedValue() as? [String: Any]
            else { continue }

            if let read = stats["Bytes (Read)"] as? UInt64 { totalRead += read }
            if let written = stats["Bytes (Write)"] as? UInt64 { totalWritten += written }
        }

        return (totalRead, totalWritten)
    }
}
