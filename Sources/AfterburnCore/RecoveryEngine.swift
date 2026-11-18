import Foundation

/// Elapsed capture time and recorded progress survive invalid readings and gaps.
/// Only valid, adjacent measured intervals contribute near-baseline evidence.
public struct RecoveryEngine: Sendable {
    public var policy: RecoveryPolicy
    public var baseline: Double?
    public private(set) var baselineProgress: Double = 0
    public private(set) var confirmationProgress: Double = 0
    public private(set) var recovered = false
    public private(set) var hadGaps = false
    private var captureStarted: Double = 0
    private var baselineStarted: Double?
    private var baselineValues: [Double] = []
    private var lastSampleTime: Double?
    private var previousNearBaselineTime: Double?
    private var isCollectingBaseline = false

    public init(policy: RecoveryPolicy = RecoveryPolicy(), baseline: Double? = nil) {
        self.policy = policy; self.baseline = baseline
    }

    public mutating func startBaseline(at seconds: Double) {
        baseline = nil; baselineProgress = 0; confirmationProgress = 0
        baselineStarted = nil; baselineValues = []; lastSampleTime = nil
        previousNearBaselineTime = nil; recovered = false; hadGaps = false
        captureStarted = seconds; isCollectingBaseline = true
    }

    public mutating func restartCapture(at seconds: Double) {
        // Explicit capture restart only; signal loss never calls this.
        captureStarted = seconds; lastSampleTime = nil
        invalidate()
    }

    public mutating func startRecovery(at seconds: Double) {
        confirmationProgress = 0; previousNearBaselineTime = nil
        lastSampleTime = nil; recovered = false; hadGaps = false
        captureStarted = seconds; isCollectingBaseline = false
    }

    public mutating func invalidate() {
        if policy.algorithmVersion < 2 {
            if baseline == nil {
                baselineStarted = nil
                baselineValues = []
                baselineProgress = 0
            }
            confirmationProgress = 0
        }
        previousNearBaselineTime = nil
    }

    public mutating func checkFreshness(at seconds: Double) {
        guard seconds.isFinite else { return }
        if isCollectingBaseline {
            if policy.algorithmVersion >= 2 {
                baselineProgress = max(baselineProgress, min(policy.baselineSeconds,
                    max(0, seconds - captureStarted - policy.warmupSeconds)))
            }
            finishBaselineIfReady()
        }
        if let last = lastSampleTime, seconds - last > policy.maximumSampleGap {
            hadGaps = true; invalidate()
        }
    }

    public mutating func consumeBaseline(_ sample: PulseSample) {
        guard baseline == nil else { return }
        guard prepare(sample) else { return }
        baselineValues.append(sample.bpm)
        if policy.algorithmVersion < 2 {
            if baselineStarted == nil { baselineStarted = sample.seconds }
            baselineProgress = max(0, sample.seconds - (baselineStarted ?? sample.seconds))
        }
        finishBaselineIfReady()
    }

    public mutating func consumeRecovery(_ sample: PulseSample) {
        guard let baseline, !recovered else { return }
        guard prepare(sample) else { return }
        guard abs(sample.bpm - baseline) <= policy.toleranceBPM else {
            previousNearBaselineTime = nil
            if policy.algorithmVersion < 2 {
                confirmationProgress = 0
            }
            return
        }
        if policy.algorithmVersion >= 2 {
            if let previous = previousNearBaselineTime {
                let interval = sample.seconds - previous
                if interval > 0, interval <= policy.maximumSampleGap { confirmationProgress += interval }
            }
            previousNearBaselineTime = sample.seconds
        } else {
            if previousNearBaselineTime == nil { previousNearBaselineTime = sample.seconds }
            confirmationProgress = max(0, sample.seconds - (previousNearBaselineTime ?? sample.seconds))
        }
        recovered = confirmationProgress >= policy.confirmationSeconds
    }

    private mutating func finishBaselineIfReady() {
        guard baseline == nil, baselineProgress >= policy.baselineSeconds, baselineValues.count >= 2 else { return }
        let sorted = baselineValues.sorted(), middle = sorted.count / 2
        baseline = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private mutating func prepare(_ sample: PulseSample) -> Bool {
        guard sample.seconds.isFinite else { invalidate(); return false }
        if let lastSampleTime, sample.seconds <= lastSampleTime { return false }
        if let lastSampleTime, sample.seconds - lastSampleTime > policy.maximumSampleGap {
            hadGaps = true; invalidate()
        }
        lastSampleTime = sample.seconds
        checkFreshness(at: sample.seconds)
        guard sample.seconds - captureStarted >= policy.warmupSeconds,
              policy.accepts(sample) else {
            invalidate(); return false
        }
        return true
    }
}

