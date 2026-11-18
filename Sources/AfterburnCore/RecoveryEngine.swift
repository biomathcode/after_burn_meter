import Foundation

/// Uses monotonic session time. Wall-clock time never drives qualification.
/// Invalid readings and gaps reset the current qualification window.
public struct RecoveryEngine: Sendable {
    public var policy: RecoveryPolicy
    public private(set) var baseline: Double?
    public private(set) var baselineProgress: Double = 0
    public private(set) var confirmationProgress: Double = 0
    public private(set) var recovered = false
    public private(set) var hadGaps = false
    private var captureStarted: Double = 0
    private var baselineStarted: Double?
    private var baselineValues: [Double] = []
    private var lastSampleTime: Double?
    private var nearBaselineStarted: Double?

    public init(policy: RecoveryPolicy = RecoveryPolicy()) { self.policy = policy }

    public mutating func startBaseline(at seconds: Double) {
        baseline = nil; baselineProgress = 0; confirmationProgress = 0
        baselineStarted = nil; baselineValues = []; lastSampleTime = nil
        nearBaselineStarted = nil; recovered = false; hadGaps = false
        captureStarted = seconds
    }

    public mutating func restartCapture(at seconds: Double) {
        captureStarted = seconds
        lastSampleTime = nil
        invalidate()
    }

    public mutating func startRecovery(at seconds: Double) {
        confirmationProgress = 0; nearBaselineStarted = nil
        lastSampleTime = nil; recovered = false; hadGaps = false
        captureStarted = seconds
    }

    public mutating func invalidate() {
        if baseline == nil {
            baselineStarted = nil; baselineValues = []; baselineProgress = 0
        }
        nearBaselineStarted = nil
        confirmationProgress = 0
    }

    public mutating func checkFreshness(at seconds: Double) {
        if let last = lastSampleTime, seconds - last > policy.maximumSampleGap {
            hadGaps = true
            invalidate()
        }
    }

    public mutating func consumeBaseline(_ sample: PulseSample) {
        guard baseline == nil else { return }
        guard let continuous = prepare(sample), continuous else { return }
        if baselineStarted == nil { baselineStarted = sample.seconds }
        baselineValues.append(sample.bpm)
        baselineProgress = max(0, sample.seconds - (baselineStarted ?? sample.seconds))
        if baselineProgress >= policy.baselineSeconds && baselineValues.count >= 2 {
            let sorted = baselineValues.sorted()
            let middle = sorted.count / 2
            baseline = sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        }
    }

    public mutating func consumeRecovery(_ sample: PulseSample) {
        guard let baseline, !recovered else { return }
        guard let continuous = prepare(sample), continuous else { return }
        // An implausibly low reading is not evidence of a return to baseline.
        guard abs(sample.bpm - baseline) <= policy.toleranceBPM else {
            nearBaselineStarted = nil; confirmationProgress = 0
            return
        }
        if nearBaselineStarted == nil { nearBaselineStarted = sample.seconds }
        confirmationProgress = max(0, sample.seconds - (nearBaselineStarted ?? sample.seconds))
        recovered = confirmationProgress >= policy.confirmationSeconds
    }

    private mutating func prepare(_ sample: PulseSample) -> Bool? {
        guard sample.seconds.isFinite else { invalidate(); return nil }
        // Reject replays/out-of-order callbacks without moving the timeline.
        if let lastSampleTime, sample.seconds <= lastSampleTime { return nil }
        let gap = lastSampleTime.map { sample.seconds - $0 > policy.maximumSampleGap } ?? false
        lastSampleTime = sample.seconds
        if gap { hadGaps = true; invalidate() }
        guard sample.seconds - captureStarted >= policy.warmupSeconds,
              policy.accepts(sample) else {
            invalidate()
            return false
        }
        return true
    }
}

