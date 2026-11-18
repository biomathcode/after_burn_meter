import XCTest
@testable import AfterburnCore

final class RecoveryEngineTests: XCTestCase {
    private func sample(_ time: Double, _ bpm: Double = 70, confidence: Double = 98,
                        stable: Bool = true, valid: Bool = true) -> PulseSample {
        PulseSample(seconds: time, bpm: bpm, confidence: confidence,
                    stable: stable, validationOK: valid)
    }

    private func calibrated() -> RecoveryEngine {
        var engine = RecoveryEngine()
        engine.startBaseline(at: 0)
        for second in 0...42 { engine.consumeBaseline(sample(Double(second))) }
        return engine
    }

    func testBaselineExcludesWarmupAndNeedsThirtyValidSeconds() {
        var engine = RecoveryEngine()
        engine.startBaseline(at: 0)
        for second in 0...41 { engine.consumeBaseline(sample(Double(second))) }
        XCTAssertNil(engine.baseline)
        engine.consumeBaseline(sample(42))
        XCTAssertEqual(engine.baseline, 70)
    }

    func testInvalidBaselineReadingsResetProgress() {
        var engine = RecoveryEngine()
        engine.startBaseline(at: 0)
        for second in 0...30 { engine.consumeBaseline(sample(Double(second))) }
        engine.consumeBaseline(sample(31, valid: false))
        for second in 32...61 { engine.consumeBaseline(sample(Double(second))) }
        XCTAssertNil(engine.baseline)
        engine.consumeBaseline(sample(62))
        XCTAssertEqual(engine.baseline, 70)
    }

    func testRecoveryRequiresWarmupAndSustainedNearBaselineReadings() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 100...126 { engine.consumeRecovery(sample(Double(second), 74)) }
        XCTAssertFalse(engine.recovered)
        engine.consumeRecovery(sample(127, 74))
        XCTAssertTrue(engine.recovered)
    }

    func testMotionAndLowConfidenceCannotConfirmRecovery() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 100...160 {
            engine.consumeRecovery(sample(Double(second), confidence: 99, stable: false))
        }
        XCTAssertFalse(engine.recovered)
        for second in 161...200 {
            engine.consumeRecovery(sample(Double(second), confidence: 40))
        }
        XCTAssertFalse(engine.recovered)
    }

    func testCameraGapResetsConfirmationWithoutErasingBaseline() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 112...120 { engine.consumeRecovery(sample(Double(second))) }
        engine.checkFreshness(at: 125)
        XCTAssertEqual(engine.confirmationProgress, 0)
        XCTAssertEqual(engine.baseline, 70)
        XCTAssertTrue(engine.hadGaps)
        for second in 130...144 { engine.consumeRecovery(sample(Double(second))) }
        XCTAssertFalse(engine.recovered)
        engine.consumeRecovery(sample(145))
        XCTAssertTrue(engine.recovered)
    }

    func testCrossingBaselineBrieflyDoesNotCompleteRecovery() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 112...120 { engine.consumeRecovery(sample(Double(second), 72)) }
        engine.consumeRecovery(sample(121, 90))
        XCTAssertEqual(engine.confirmationProgress, 0)
        XCTAssertFalse(engine.recovered)
    }

    func testValuesOutsideConservativeRangeAndNaNAreRejected() {
        let policy = RecoveryPolicy()
        XCTAssertFalse(policy.accepts(sample(12, 135)))
        XCTAssertFalse(policy.accepts(sample(12, 20)))
        XCTAssertFalse(policy.accepts(sample(12, .nan)))
        XCTAssertFalse(policy.accepts(sample(.infinity)))
        XCTAssertFalse(policy.accepts(sample(12, confidence: .nan)))
    }

    func testReplayDoesNotAdvanceOrResetQualification() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 112...120 { engine.consumeRecovery(sample(Double(second))) }
        let progress = engine.confirmationProgress
        engine.consumeRecovery(sample(119, valid: false))
        XCTAssertEqual(engine.confirmationProgress, progress)
        XCTAssertFalse(engine.recovered)
    }

    func testVeryLowPulseDoesNotCountAsRecovery() {
        var engine = calibrated()
        engine.startRecovery(at: 100)
        for second in 112...180 { engine.consumeRecovery(sample(Double(second), 45)) }
        XCTAssertFalse(engine.recovered)
    }

    func testNewBaselineCannotReusePreviousSession() {
        var engine = calibrated()
        engine.startBaseline(at: 200)
        XCTAssertNil(engine.baseline)
        XCTAssertEqual(engine.baselineProgress, 0)
    }

    func testRecordRoundTripPreservesCameraSourceAndGapFlags() throws {
        let record = SetRecord(exerciseID: "0001", exerciseName: "Sit-up", setNumber: 1,
            repetitions: 10, workSeconds: 45, recoverySeconds: 65, baselineBPM: 70,
            finalBPM: 73, outcome: .observed, hadMeasurementGaps: true,
            samples: [sample(12)], policy: RecoveryPolicy(), sdkVersion: "3.5.0")
        let decoded = try JSONDecoder().decode(SetRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.id, record.id)
        XCTAssertFalse(decoded.isDemo)
        XCTAssertTrue(decoded.hadMeasurementGaps)
        XCTAssertEqual(decoded.outcome, .observed)
    }
}
