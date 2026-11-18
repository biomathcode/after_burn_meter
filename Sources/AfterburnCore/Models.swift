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
    public var algorithmVersion: Int = 1
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

    private enum CodingKeys: String, CodingKey {
        case algorithmVersion, warmupSeconds, baselineSeconds, confirmationSeconds
        case toleranceBPM, minimumConfidence, minimumBPM, maximumBPM, maximumSampleGap
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        algorithmVersion = try values.decodeIfPresent(Int.self, forKey: .algorithmVersion) ?? 1
        warmupSeconds = try values.decode(Double.self, forKey: .warmupSeconds)
        baselineSeconds = try values.decode(Double.self, forKey: .baselineSeconds)
        confirmationSeconds = try values.decode(Double.self, forKey: .confirmationSeconds)
        toleranceBPM = try values.decode(Double.self, forKey: .toleranceBPM)
        minimumConfidence = try values.decode(Double.self, forKey: .minimumConfidence)
        minimumBPM = try values.decode(Double.self, forKey: .minimumBPM)
        maximumBPM = try values.decode(Double.self, forKey: .maximumBPM)
        maximumSampleGap = try values.decode(Double.self, forKey: .maximumSampleGap)
    }

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
    public let captureStartedAt: Double?

    // Session demographics, 1-min baseline, and snapshots:
    public let gender: String?
    public let age: Int?
    public let normalSeconds: Double?
    public let peakPulseBPM: Double?
    public let peakSnapshotData: Data?
    public let restedSnapshotData: Data?
    public let baselineSamples: [PulseSample]?
    public let exerciseSamples: [PulseSample]?

    // Respiration recovery (Afterburn), Pulse recovery, and Calories:
    public let baselineBreathing: Double?
    public let finalBreathing: Double?
    public let breathRecoverySeconds: Double?
    public let pulseRecoverySeconds: Double?
    public let caloriesBurned: Double?
    public let epocCalories: Double?

    public init(id: UUID = UUID(), date: Date = Date(), exerciseID: String = "session",
                exerciseName: String, setNumber: Int = 1, repetitions: Int = 0,
                workSeconds: Double, recoverySeconds: Double, baselineBPM: Double,
                finalBPM: Double?, outcome: SetOutcome,
                hadMeasurementGaps: Bool = false, samples: [PulseSample],
                policy: RecoveryPolicy = RecoveryPolicy(), sdkVersion: String = "3.5.0", captureStartedAt: Double? = nil,
                gender: String? = nil, age: Int? = nil, normalSeconds: Double? = 30.0,
                peakPulseBPM: Double? = nil, peakSnapshotData: Data? = nil, restedSnapshotData: Data? = nil,
                baselineSamples: [PulseSample]? = nil, exerciseSamples: [PulseSample]? = nil,
                baselineBreathing: Double? = nil, finalBreathing: Double? = nil,
                breathRecoverySeconds: Double? = nil, pulseRecoverySeconds: Double? = nil,
                caloriesBurned: Double? = nil, epocCalories: Double? = nil) {
        self.id = id; self.date = date; self.exerciseID = exerciseID
        self.exerciseName = exerciseName; self.setNumber = setNumber
        self.repetitions = repetitions; self.workSeconds = workSeconds
        self.recoverySeconds = recoverySeconds; self.baselineBPM = baselineBPM
        self.finalBPM = finalBPM; self.outcome = outcome; self.isDemo = false
        self.hadMeasurementGaps = hadMeasurementGaps; self.samples = samples
        self.policy = policy; self.sdkVersion = sdkVersion
        self.captureStartedAt = captureStartedAt
        self.gender = gender; self.age = age
        self.normalSeconds = normalSeconds; self.peakPulseBPM = peakPulseBPM
        self.peakSnapshotData = peakSnapshotData; self.restedSnapshotData = restedSnapshotData
        self.baselineSamples = baselineSamples; self.exerciseSamples = exerciseSamples
        self.baselineBreathing = baselineBreathing; self.finalBreathing = finalBreathing
        self.breathRecoverySeconds = breathRecoverySeconds
        self.pulseRecoverySeconds = pulseRecoverySeconds
        self.caloriesBurned = caloriesBurned; self.epocCalories = epocCalories
    }
}

// MARK: - Calorie & Energy Expenditure Calculator
public struct CalorieCalculator: Sendable {
    public static func calculate(
        gender: String?,
        age: Int?,
        weightKg: Double = 70.0,
        workSeconds: Double,
        recoverySeconds: Double,
        exerciseName: String,
        averagePulseBPM: Double? = nil,
        peakPulseBPM: Double? = nil
    ) -> (total: Double, active: Double, epoc: Double) {
        let name = exerciseName.lowercased()
        let met: Double = {
            if name.contains("burpee") { return 10.0 }
            if name.contains("jack") { return 8.0 }
            if name.contains("push") { return 8.0 }
            if name.contains("squat") { return 7.5 }
            if name.contains("run") { return 9.5 }
            if name.contains("cycle") || name.contains("cycling") { return 7.5 }
            if name.contains("yoga") { return 3.5 }
            return 8.0
        }()

        let isFemale = gender?.lowercased().contains("female") == true
        let userWeight = isFemale ? 60.0 : weightKg
        let effectiveAge = Double(age ?? 26)
        let effectiveHR = averagePulseBPM ?? (peakPulseBPM.map { $0 * 0.85 } ?? 125.0)

        // Keytel et al. (2005) Heart-rate energy expenditure
        let keytelKcalPerMin: Double
        if !isFemale {
            keytelKcalPerMin = ((-55.0969 + (0.6309 * effectiveHR) + (0.1988 * userWeight) + (0.2017 * effectiveAge)) / 4.184)
        } else {
            keytelKcalPerMin = ((-20.4022 + (0.4472 * effectiveHR) - (0.1263 * userWeight) + (0.074 * effectiveAge)) / 4.184)
        }

        // MET energy expenditure = (MET * 3.5 * weight) / 200 (kcal/min)
        let metKcalPerMin = (met * 3.5 * userWeight) / 200.0
        let blendedRatePerMin = max(4.0, (keytelKcalPerMin > 0 ? (keytelKcalPerMin * 0.55 + metKcalPerMin * 0.45) : metKcalPerMin))

        let activeMinutes = max(0.5, workSeconds / 60.0)
        let activeKcal = blendedRatePerMin * activeMinutes
        // EPOC: acute 1-minute excess post-exercise oxygen consumption
        let epocKcal = max(1.5, activeKcal * 0.20 * (recoverySeconds / 60.0))
        let total = activeKcal + epocKcal

        return (
            total: (total * 10).rounded() / 10,
            active: (activeKcal * 10).rounded() / 10,
            epoc: (epocKcal * 10).rounded() / 10
        )
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

