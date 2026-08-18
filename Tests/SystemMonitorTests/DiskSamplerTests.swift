import XCTest
@testable import SystemMonitor

/// The getattrlist reply is read at hardcoded byte offsets. Getting one
/// wrong doesn't crash — it silently reports a number from the wrong field,
/// which is exactly the kind of thing that survives a manual once-over.
final class DiskSamplerTests: XCTestCase {
    /// Same layout the kernel writes: 4-byte length, then size, available
    /// and used as 8-byte values in the order the attrlist asked for them.
    private func attributeBuffer(total: Int64, available: Int64, used: Int64) -> [UInt8] {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: UInt32(DiskSampler.bufferSize)) { bytes.append(contentsOf: $0) }
        withUnsafeBytes(of: total) { bytes.append(contentsOf: $0) }
        withUnsafeBytes(of: available) { bytes.append(contentsOf: $0) }
        withUnsafeBytes(of: used) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: [UInt8](repeating: 0, count: DiskSampler.bufferSize - bytes.count))
        return bytes
    }

    func testReadsTotalAndUsedFromTheirOwnFields() {
        let buffer = attributeBuffer(total: 994_662_584_320, available: 494_662_584_320, used: 500_000_000_000)
        let parsed = DiskSampler.parse(attributeBuffer: buffer)
        XCTAssertEqual(parsed?.totalGB ?? 0, 994.66258432, accuracy: 0.0001)
        XCTAssertEqual(parsed?.usedGB ?? 0, 500.0, accuracy: 0.0001)
    }

    /// The offsets are the whole point: reading "used" from where
    /// "available" lives is the classic failure here, and it looks
    /// perfectly plausible on screen.
    func testUsedIsNotTheAvailableField() {
        let buffer = attributeBuffer(total: 1_000, available: 400, used: 600)
        let parsed = DiskSampler.parse(attributeBuffer: buffer)
        XCTAssertEqual(parsed?.usedGB ?? 0, 600 / 1e9, accuracy: 1e-12)
    }

    func testShortReplyFallsBack() {
        XCTAssertNil(DiskSampler.parse(attributeBuffer: [UInt8](repeating: 0, count: 16)))
    }

    func testNonsenseValuesFallBack() {
        XCTAssertNil(DiskSampler.parse(attributeBuffer: attributeBuffer(total: 0, available: 0, used: 0)))
        XCTAssertNil(DiskSampler.parse(attributeBuffer: attributeBuffer(total: 100, available: 0, used: 200)))
    }

    /// End to end against the real volume — no fixed expectation, just that
    /// the numbers are ordered and in a sane range for a Mac.
    func testRealVolumeReadsBackSomethingPlausible() {
        let result = DiskSampler().sample()
        XCTAssertGreaterThan(result.totalGB, 1)
        XCTAssertGreaterThan(result.usedGB, 0)
        XCTAssertLessThanOrEqual(result.usedGB, result.totalGB)
    }
}
