import XCTest
@testable import AfterburnCore

final class LiveVitalsTests: XCTestCase {
    func testPacketsStayBoundedAndRejectReplaysAndNonFiniteValues() {
        var vitals = LiveVitals(capacity: 3)
        for t in 0...8 { vitals.append(.pulse, value: 72, confidence: 95, stable: true, seconds: Double(t)) }
        XCTAssertEqual(vitals.history[.pulse]?.count, 3)
        XCTAssertFalse(vitals.append(.pulse, value: 80, confidence: 95, stable: true, seconds: 7))
        XCTAssertFalse(vitals.append(.eda, value: .nan, confidence: nil, stable: true, seconds: 9))
        XCTAssertFalse(vitals.append(.pulse, value: 72, confidence: 101, stable: true, seconds: 9))
        XCTAssertNil(vitals.history[.eda])
    }

    func testHrvRequiresItsOwnWindowConfidenceAndFreshness() {
        var vitals = LiveVitals()
        vitals.append(.rmssd, value: 35, confidence: 80, stable: true, seconds: 59)
        XCTAssertFalse(vitals.isReliable(.rmssd, at: 59, elapsed: 59, validationOK: true))
        XCTAssertTrue(vitals.isReliable(.rmssd, at: 60, elapsed: 60, validationOK: true))
        XCTAssertFalse(vitals.isReliable(.rmssd, at: 63, elapsed: 63, validationOK: true))
        XCTAssertFalse(vitals.isReliable(.rmssd, at: 60, elapsed: 60, validationOK: false))
        XCTAssertNil(vitals.fresh(.sdnn, at: 60))
    }

    func testWaveformsBreakAcrossGapsAndKeepSignedRelativeValues() {
        var vitals = LiveVitals()
        vitals.append(.arterial, value: -0.4, confidence: 90, stable: true, seconds: 12)
        vitals.append(.arterial, value: 0.2, confidence: 90, stable: true, seconds: 13)
        vitals.append(.arterial, value: -0.1, confidence: 90, stable: true, seconds: 18)
        XCTAssertEqual(vitals.history[.arterial]?.map(\.segment), [0, 0, 1])
        XCTAssertTrue(vitals.isReliable(.arterial, at: 18, elapsed: 18, validationOK: true))
    }

    func testClockPreservesSampleAgeAndSharedRelativeTimeline() {
        var clock = MetricClock()
        XCTAssertEqual(clock.seconds(for: 9_000_000, callback: 10_000_000, uptime: 100, wallTime: 1_800_000_000), 99)
        XCTAssertEqual(clock.seconds(for: 11_000_000, callback: 12_000_000, uptime: 102, wallTime: 1_800_000_002), 101)
        XCTAssertEqual(clock.seconds(for: 1_800_000_000_000_000, callback: 1_800_000_005_000_000,
                                    uptime: 200, wallTime: 1_800_000_005), 195)
    }
}
