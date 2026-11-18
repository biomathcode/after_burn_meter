import Foundation

/// SDK credit conservation vs production continuous streaming mode.
public enum SDKOperationMode: String, CaseIterable, Codable, Sendable {
    case testingCreditSaver = "Testing (Credit Saver)"
    case productionFullUse = "Production (Full Use)"

    public var summary: String {
        switch self {
        case .testingCreditSaver:
            return "Conserves API credits: runs only during 30s baseline & 60s recovery. Pauses SDK during exercise."
        case .productionFullUse:
            return "Full continuous SDK measurement across exercise sets and recovery without interruption."
        }
    }
}

/// Named preset durations for the graph time window.
public enum TrendPeriodPreset: String, CaseIterable, Codable, Sendable {
    case s30 = "30s"
    case m1  = "1m"
    case m2  = "2m"
    case m5  = "5m"
    case custom = "Custom"

    public var seconds: Double? {
        switch self {
        case .s30: return 30
        case .m1:  return 60
        case .m2:  return 120
        case .m5:  return 300
        case .custom: return nil
        }
    }

    public static func matching(_ seconds: Double) -> TrendPeriodPreset {
        for preset in allCases {
            if let s = preset.seconds, abs(s - seconds) < 0.5 { return preset }
        }
        return .custom
    }
}

public struct MeasurementSettings: Codable, Equatable, Sendable {
    public var policy = RecoveryPolicy()
    public var trendWindowSeconds: Double = 60
    /// Remembered preset selection; kept in sync with trendWindowSeconds.
    public var trendPeriodPreset: TrendPeriodPreset = .m1
    /// Operational mode: testing credit saver (default) vs production full continuous use.
    public var sdkOperationMode: SDKOperationMode = .testingCreditSaver
    public init() {}

    public var normalized: Self {
        var value = self
        func bounded(_ number: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            number.isFinite ? min(range.upperBound, max(range.lowerBound, number)) : fallback
        }
        value.policy.algorithmVersion = 2
        value.policy.minimumConfidence = bounded(policy.minimumConfidence, 40...100, fallback: 90)
        value.policy.toleranceBPM = bounded(policy.toleranceBPM, 1...20, fallback: 5)
        value.policy.warmupSeconds = bounded(policy.warmupSeconds, 12...120, fallback: 12)
        value.policy.baselineSeconds = bounded(policy.baselineSeconds, 5...300, fallback: 30)
        value.policy.confirmationSeconds = bounded(policy.confirmationSeconds, 1...120, fallback: 15)
        value.policy.maximumSampleGap = bounded(policy.maximumSampleGap, 1...15, fallback: 3)
        value.policy.minimumBPM = 40; value.policy.maximumBPM = 110
        value.trendWindowSeconds = bounded(trendWindowSeconds, 10...300, fallback: 60)
        // Keep preset in sync with the stored window length.
        value.trendPeriodPreset = TrendPeriodPreset.matching(value.trendWindowSeconds)
        return value
    }
}
