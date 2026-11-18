import Foundation

/// Least-squares trend over actual timestamped pulse, centered for numerical
/// stability. Predictions are a fitted summary, never additional measurements.
public struct PulseRegression: Sendable {
    public let origin: Double
    public let start: Double
    public let end: Double
    public let intercept: Double
    public let slope: Double
    public let rSquared: Double
    public let sampleCount: Int

    public init?(samples: [PulseSample], policy: RecoveryPolicy) {
        let points = samples.filter { policy.accepts($0) }.sorted { $0.seconds < $1.seconds }
        guard points.count >= 2, let first = points.first, let last = points.last,
              last.seconds > first.seconds else { return nil }
        let origin = first.seconds
        let count = Double(points.count)
        let meanX = points.reduce(0) { $0 + ($1.seconds - origin) } / count
        let meanY = points.reduce(0) { $0 + $1.bpm } / count
        var xx = 0.0, xy = 0.0, yy = 0.0
        for point in points {
            let x = point.seconds - origin - meanX, y = point.bpm - meanY
            xx += x * x; xy += x * y; yy += y * y
        }
        guard xx > 0 else { return nil }
        let slope = xy / xx, intercept = meanY - slope * meanX
        guard slope.isFinite, intercept.isFinite else { return nil }
        self.origin = origin; start = first.seconds; end = last.seconds
        self.slope = slope; self.intercept = intercept; sampleCount = points.count
        rSquared = yy > 0 ? min(1, max(0, xy * xy / (xx * yy))) : 1
    }

    public func value(at seconds: Double) -> Double { intercept + slope * (seconds - origin) }
}
