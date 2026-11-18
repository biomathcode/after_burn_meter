import Foundation

public enum VitalKind: String, CaseIterable, Sendable {
    case pulse, breathing, rmssd, sdnn, meanNN, baevsky
    case arterial, chest, abdomen, eda

    public var title: String {
        switch self {
        case .pulse: "Pulse"
        case .breathing: "Breathing"
        case .rmssd: "HRV · RMSSD"
        case .sdnn: "HRV · SDNN"
        case .meanNN: "Mean NN interval"
        case .baevsky: "Baevsky index"
        case .arterial: "Arterial waveform"
        case .chest: "Chest movement"
        case .abdomen: "Abdominal movement"
        case .eda: "EDA Proxy"
        }
    }

    public var unit: String {
        switch self {
        case .pulse: "BPM"
        case .breathing: "breaths/min"
        case .rmssd, .sdnn, .meanNN: "ms"
        case .baevsky: "index"
        default: "relative units"
        }
    }

    public var warmupSeconds: Double {
        switch self {
        case .pulse, .arterial: 12
        case .breathing, .chest, .abdomen: 30
        case .eda: 35
        default: 60
        }
    }

    public var minimumConfidence: Double? {
        switch self {
        case .pulse, .arterial: 40
        case .breathing: 45
        case .rmssd, .sdnn, .meanNN, .baevsky: 50
        default: nil
        }
    }

    public var isWaveform: Bool { [.arterial, .chest, .abdomen, .eda].contains(self) }

    public func acceptsValue(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        switch self {
        // Match the app's conservative published operating range.
        case .pulse: return (40...110).contains(value)
        case .breathing: return (5...40).contains(value)
        case .rmssd, .sdnn, .meanNN, .baevsky: return value >= 0
        default: return true
        }
    }
}

public struct VitalPoint: Equatable, Sendable {
    public let seconds: Double
    public let value: Double
    public let confidence: Double?
    public let stable: Bool
    public let segment: Int
}

/// Bounded, measured samples only. A missing metric never becomes a zero reading.
public struct LiveVitals: Sendable {
    public private(set) var history: [VitalKind: [VitalPoint]] = [:]
    public let capacity: Int

    public init(capacity: Int = 600) { self.capacity = max(2, capacity) }

    @discardableResult
    public mutating func append(_ kind: VitalKind, value: Double, confidence: Double?,
                                stable: Bool, seconds: Double) -> Bool {
        guard value.isFinite, seconds.isFinite,
              confidence.map({ $0.isFinite && (0...100).contains($0) }) ?? true else { return false }
        var points = history[kind] ?? []
        if let last = points.last, seconds <= last.seconds { return false }
        let previous = points.last
        let segment = (previous?.segment ?? 0) + (previous.map { seconds - $0.seconds > 3 } == true ? 1 : 0)
        points.append(VitalPoint(seconds: seconds, value: value, confidence: confidence,
                                 stable: stable, segment: segment))
        if points.count > capacity { points.removeFirst(points.count - capacity) }
        history[kind] = points
        return true
    }

    public func fresh(_ kind: VitalKind, at now: Double) -> VitalPoint? {
        guard let point = history[kind]?.last, now - point.seconds <= 3,
              point.seconds <= now + 0.5 else { return nil }
        return point
    }

    public func isReliable(_ kind: VitalKind, at now: Double, elapsed: Double, validationOK: Bool) -> Bool {
        guard validationOK, elapsed >= kind.warmupSeconds,
              let point = fresh(kind, at: now), point.stable, kind.acceptsValue(point.value) else { return false }
        if let minimum = kind.minimumConfidence { return (point.confidence ?? -1) >= minimum }
        return true
    }
}

/// SDK samples and callbacks share microsecond source timestamps. Keep their
/// original relative age instead of making every old sample fresh on receipt.
public struct MetricClock: Sendable {
    private var sourceAnchor: Int64?
    private var uptimeAnchor: Double = 0
    public init() {}

    public mutating func seconds(for timestamp: Int64, callback: Int64,
                                 uptime: Double, wallTime: Double) -> Double {
        let epochSeconds = Double(timestamp) / 1_000_000
        if abs(epochSeconds - wallTime) < 86_400 {
            return uptime - (wallTime - epochSeconds)
        }
        if sourceAnchor == nil { sourceAnchor = callback; uptimeAnchor = uptime }
        return uptimeAnchor + (Double(timestamp) - Double(sourceAnchor ?? callback)) / 1_000_000
    }
}
