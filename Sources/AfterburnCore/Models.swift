import Foundation

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let bodyPart: String
    public let equipment: String
    public let target: String
    public let muscleGroup: String
    public let secondaryMuscles: [String]
    public let instructions: String
    public let steps: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, category, equipment, target, instructions, steps
        case bodyPart = "body_part"
        case muscleGroup = "muscle_group"
        case secondaryMuscles = "secondary_muscles"
    }

    public var displayName: String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }

    public var symbol: String {
        switch category {
        case "cardio": "figure.run"
        case "waist": "figure.core.training"
        case "upper legs", "lower legs": "figure.strengthtraining.functional"
        case "back": "figure.rower"
        case "chest": "figure.strengthtraining.traditional"
        case "stretching": "figure.flexibility"
        default: "dumbbell"
        }
    }
}

public struct PlannedExercise: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var exerciseID: String
    public var sets: Int
    public var repetitions: Int
    public var targetSeconds: Int

    public init(id: UUID = UUID(), exerciseID: String, sets: Int = 3,
                repetitions: Int = 10, targetSeconds: Int = 45) {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = min(20, max(1, sets))
        self.repetitions = min(100, max(1, repetitions))
        self.targetSeconds = min(3600, max(10, targetSeconds))
    }
}

public struct PulseSample: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var seconds: TimeInterval
    public var bpm: Double
    public var confidence: Double
    public var stable: Bool
    public var validationOK: Bool

    public init(seconds: TimeInterval, bpm: Double, confidence: Double,
                stable: Bool, validationOK: Bool, id: UUID = UUID()) {
        self.id = id
        self.seconds = seconds
        self.bpm = bpm
        self.confidence = confidence
        self.stable = stable
        self.validationOK = validationOK
    }
}

public struct RecoveryPolicy: Codable, Equatable, Sendable {
    public var warmupSeconds: Double = 12
    public var baselineSeconds: Double = 30
    public var confirmationSeconds: Double = 15
    public var toleranceBPM: Double = 5
    public var minimumConfidence: Double = 90
    // Conservative until Presage resolves the conflicting SDK/model-card ranges.
    public var minimumBPM: Double = 40
    public var maximumBPM: Double = 110
    public var maximumSampleGap: Double = 3
    public init() {}

    public func accepts(_ sample: PulseSample) -> Bool {
        sample.seconds.isFinite && sample.bpm.isFinite && sample.confidence.isFinite &&
        sample.stable && sample.validationOK && sample.confidence >= minimumConfidence &&
        (minimumBPM...maximumBPM).contains(sample.bpm)
    }
}

public enum SetOutcome: String, Codable, Sendable {
    case observed, endedManually, interrupted
    public var label: String {
        switch self {
        case .observed: "Near baseline observed"
        case .endedManually: "Ended manually"
        case .interrupted: "Interrupted"
        }
    }
}

public struct SetRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let exerciseID: String
    public let exerciseName: String
    public let setNumber: Int
    public let repetitions: Int
    public let workSeconds: Double
    public let recoverySeconds: Double
    public let baselineBPM: Double
    public let finalBPM: Double?
    public let outcome: SetOutcome
    // Retained only to identify and exclude records from older simulated builds.
    public let isDemo: Bool
    public let hadMeasurementGaps: Bool
    public let samples: [PulseSample]
    public let policy: RecoveryPolicy
    public let sdkVersion: String

    public init(id: UUID = UUID(), date: Date = Date(), exerciseID: String,
                exerciseName: String, setNumber: Int, repetitions: Int,
                workSeconds: Double, recoverySeconds: Double, baselineBPM: Double,
                finalBPM: Double?, outcome: SetOutcome,
                hadMeasurementGaps: Bool, samples: [PulseSample],
                policy: RecoveryPolicy, sdkVersion: String) {
        self.id = id; self.date = date; self.exerciseID = exerciseID
        self.exerciseName = exerciseName; self.setNumber = setNumber
        self.repetitions = repetitions; self.workSeconds = workSeconds
        self.recoverySeconds = recoverySeconds; self.baselineBPM = baselineBPM
        self.finalBPM = finalBPM; self.outcome = outcome; self.isDemo = false
        self.hadMeasurementGaps = hadMeasurementGaps; self.samples = samples
        self.policy = policy; self.sdkVersion = sdkVersion
    }
}

public struct ConsentRecord: Codable, Sendable {
    public static let currentVersion = 2
    public let version: Int
    public let acceptedAt: Date
    public init(acceptedAt: Date = Date()) {
        self.version = Self.currentVersion
        self.acceptedAt = acceptedAt
    }
    public var isCurrent: Bool { version == Self.currentVersion }
}

public enum TimeText {
    public static func clock(_ seconds: Double) -> String {
        let value = seconds.isFinite ? Int(max(0, seconds).rounded(.down)) : 0
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
    public static func duration(_ seconds: Double) -> String {
        let value = seconds.isFinite ? Int(max(0, seconds).rounded()) : 0
        return value < 60 ? "\(value)s" : "\(value / 60)m \(value % 60)s"
    }
}

