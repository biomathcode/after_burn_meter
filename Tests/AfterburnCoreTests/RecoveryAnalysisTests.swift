import XCTest
@testable import AfterburnCore

final class RecoveryAnalysisTests: XCTestCase {
    private func sample(_ time: Double, _ pulse: Double, valid: Bool = true) -> PulseSample {
        PulseSample(seconds: time, bpm: pulse, confidence: 95, stable: valid, validationOK: valid)
    }
    private func record(_ samples: [PulseSample], duration: Double = 10) -> SetRecord {
        SetRecord(exerciseID: "0662", exerciseName: "Push-up", setNumber: 1,
            repetitions: 10, workSeconds: 30, recoverySeconds: duration, baselineBPM: 70,
            finalBPM: 72, outcome: .observed, hadMeasurementGaps: false,
            samples: samples, policy: RecoveryPolicy(), sdkVersion: "3.5.0")
    }
    func testStatisticsExcludeUnstableAndOutOfRangeReadings() {
        let analysis = RecoveryAnalysis(record: record([
            sample(0, 70), sample(1, 90), sample(2, 100), sample(3, 109, valid: false), sample(4, 180)
        ]))
        XCTAssertEqual(analysis.validSampleCount, 3)
        XCTAssertEqual(analysis.totalSampleCount, 5)
        XCTAssertEqual(analysis.medianPulse, 90)
        XCTAssertEqual(analysis.peakPulse, 100)
        XCTAssertEqual(analysis.finalDelta, 2)
    }
    func testCoverageDoesNotInterpolateAcrossMissingMeasurements() {
        let analysis = RecoveryAnalysis(record: record([
            sample(0, 70), sample(1, 72), sample(8, 73), sample(9, 72)
        ]))
        XCTAssertEqual(analysis.signalCoverage, 0.2, accuracy: 0.001)
    }
    func testEmptyMeasurementProducesNoInventedStatistics() {
        let analysis = RecoveryAnalysis(record: record([]))
        XCTAssertNil(analysis.medianPulse)
        XCTAssertNil(analysis.peakPulse)
        XCTAssertNil(analysis.averageConfidence)
        XCTAssertEqual(analysis.signalCoverage, 0)
    }
    func testLegacySimulatedRecordCannotContributeToAnalysis() throws {
        let data = try JSONEncoder().encode(record([sample(0, 70), sample(1, 72)]))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["isDemo"] = true
        let legacy = try JSONDecoder().decode(SetRecord.self, from: JSONSerialization.data(withJSONObject: json))
        let analysis = RecoveryAnalysis(record: legacy)
        XCTAssertFalse(analysis.observedReturn)
        XCTAssertEqual(analysis.validSampleCount, 0)
        XCTAssertNil(analysis.medianPulse)
        XCTAssertNil(analysis.finalDelta)
    }
    func testCoverageIsBoundedAndMedianHandlesEvenCount() {
        let analysis = RecoveryAnalysis(record: record([sample(0, 70), sample(1, 80)], duration: 0.5))
        XCTAssertEqual(analysis.medianPulse, 75)
        XCTAssertEqual(analysis.signalCoverage, 1)
    }
}
