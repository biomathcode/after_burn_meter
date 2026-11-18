import Foundation

/// Descriptive statistics from measured samples, never generated vitals or advice.
public struct RecoveryAnalysis: Sendable {
    public let validSampleCount: Int
    public let totalSampleCount: Int
    public let medianPulse: Double?
    public let peakPulse: Double?
    public let averageConfidence: Double?
    public let signalCoverage: Double
    public let baseline: Double
    public let finalDelta: Double?
    public let observedReturn: Bool

    public init(record: SetRecord) {
        let samples = record.isDemo ? [] : record.samples.sorted { $0.seconds < $1.seconds }
        let valid = samples.filter { record.policy.accepts($0) }
        let values = valid.map(\.bpm).sorted()
        validSampleCount = valid.count
        totalSampleCount = samples.count
        baseline = record.baselineBPM
        if values.isEmpty { medianPulse = nil }
        else {
            let middle = values.count / 2
            medianPulse = values.count.isMultiple(of: 2)
                ? (values[middle - 1] + values[middle]) / 2 : values[middle]
        }
        peakPulse = values.last
        averageConfidence = valid.isEmpty ? nil : valid.reduce(0) { $0 + $1.confidence } / Double(valid.count)
        var validSeconds: Double = 0
        for (previous, current) in zip(samples, samples.dropFirst()) {
            let delta = current.seconds - previous.seconds
            if delta > 0, delta <= record.policy.maximumSampleGap,
               record.policy.accepts(previous), record.policy.accepts(current) { validSeconds += delta }
        }
        signalCoverage = record.recoverySeconds > 0 ? min(1, validSeconds / record.recoverySeconds) : 0
        finalDelta = record.isDemo ? nil : record.finalBPM.map { $0 - record.baselineBPM }
        observedReturn = !record.isDemo && record.outcome == .observed
    }
}
