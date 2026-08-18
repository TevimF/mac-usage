import XCTest
@testable import SystemMonitor

/// Formatting decides what the menu bar actually says, and the render key
/// now compares those strings — a change here changes both.
final class FormattingTests: XCTestCase {
    private var originalLanguage: AppLanguage = .portuguese

    override func setUp() {
        super.setUp()
        originalLanguage = AppSettings.shared.language
        AppSettings.shared.language = .portuguese
    }

    override func tearDown() {
        AppSettings.shared.language = originalLanguage
        super.tearDown()
    }

    func testPercentRoundsToWholeNumbers() {
        XCTAssertEqual(Formatting.percent(0), "0")
        XCTAssertEqual(Formatting.percent(42.4), "42")
        XCTAssertEqual(Formatting.percent(42.5), "43")
        XCTAssertEqual(Formatting.percent(99.6), "100")
    }

    func testDecimalSeparatorFollowsTheAppLanguage() {
        AppSettings.shared.language = .portuguese
        XCTAssertEqual(Formatting.oneDecimalString(8.26), "8,3")
        AppSettings.shared.language = .english
        XCTAssertEqual(Formatting.oneDecimalString(8.26), "8.3")
    }

    /// NumberFormatter rounds half to even by default, so an exact .x5
    /// lands on the even digit — 8,25 shows as 8,2 while 8,35 shows as 8,4.
    /// Nothing depends on it going the other way; this is here so a future
    /// change of rounding rule is a decision, not a surprise.
    func testExactHalvesRoundToEven() {
        AppSettings.shared.language = .portuguese
        XCTAssertEqual(Formatting.oneDecimalString(8.25), "8,2")
        XCTAssertEqual(Formatting.oneDecimalString(8.35), "8,4")
    }

    func testProcessMemorySwitchesUnitAtAGigabyte() {
        XCTAssertEqual(Formatting.memory(mb: 512), "512 MB")
        XCTAssertEqual(Formatting.memory(mb: 1023), "1023 MB")
        XCTAssertEqual(Formatting.memory(mb: 1024), "1,0 GB")
        XCTAssertEqual(Formatting.memory(mb: 2560), "2,5 GB")
    }

    func testDuration() {
        XCTAssertEqual(Formatting.duration(minutes: 0), "—")
        XCTAssertEqual(Formatting.duration(minutes: -5), "—")
        XCTAssertEqual(Formatting.duration(minutes: 45), "45 min")
        XCTAssertEqual(Formatting.duration(minutes: 80), "1 h 20 min")
        XCTAssertEqual(Formatting.duration(minutes: 320), "5 h 20 min")
    }
}
