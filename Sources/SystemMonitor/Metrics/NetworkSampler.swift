import Foundation
import Darwin

/// Aggregate throughput across active, non-loopback interfaces via
/// getifaddrs — polled and diffed, not read from a subprocess like
/// `netstat`.
final class NetworkSampler {
    struct Result {
        var downRate: Double // MB/s
        var upRate: Double // MB/s
    }

    private var lastBytesIn: UInt64?
    private var lastBytesOut: UInt64?
    private var lastTimestamp: Date?

    func sample() -> Result {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return Result(downRate: 0, upRate: 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            let entry = current.pointee
            let flags = Int32(entry.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let data = entry.ifa_data else { continue }

            let ifData = data.assumingMemoryBound(to: if_data.self).pointee
            totalIn += UInt64(ifData.ifi_ibytes)
            totalOut += UInt64(ifData.ifi_obytes)
        }

        let now = Date()
        defer {
            lastBytesIn = totalIn
            lastBytesOut = totalOut
            lastTimestamp = now
        }

        guard let prevIn = lastBytesIn, let prevOut = lastBytesOut, let last = lastTimestamp else {
            return Result(downRate: 0, upRate: 0)
        }

        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0, totalIn >= prevIn, totalOut >= prevOut else {
            return Result(downRate: 0, upRate: 0)
        }

        let down = Double(totalIn - prevIn) / elapsed / 1_000_000
        let up = Double(totalOut - prevOut) / elapsed / 1_000_000
        return Result(downRate: down, upRate: up)
    }
}
