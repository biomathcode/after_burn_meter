import AppKit
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case workout, history, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .workout: "Session"
        case .history: "Journal"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .workout: "heart.text.square"
        case .history: "chart.xyaxis.line"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum WorkoutPhase {
    case idle, calibrating, ready, working, recovering, result, finished, interrupted
    var title: String {
        switch self {
        case .idle: "Session Setup"
        case .calibrating: "Normal Baseline Check (30s)"
        case .ready: "Normal Baseline Confirmed"
        case .working: "Exercise Set (1 min)"
        case .recovering: "Afterburn Recovery (1 min)"
        case .result: "Session Complete"
        case .finished: "Session Finished"
        case .interrupted: "Session Reset"
        }
    }
    var step: Int {
        switch self {
        case .idle, .calibrating, .interrupted: 0
        case .ready, .working: 1
        case .recovering, .result, .finished: 2
        }
    }
    var isActive: Bool { self == .calibrating || self == .working || self == .recovering }
}

@MainActor @Observable
final class AppModel {
    // Automated phase timer durations: 30s normal -> 1m exercise -> 1m recovery
    static let normalDuration: Double = 30.0
    static let exerciseDuration: Double = 60.0
    static let recoveryDuration: Double = 60.0

    var section: AppSection = .workout {
        didSet {
            if section != .workout {
                if phase.isActive { interrupt() }
                stopSensor()
            } else if mayEnterApp && !sensor.isCameraRunning {
                openCamera()
            }
        }
    }
    var isStageFocused = false
    var exercises: [Exercise] = []
    var plan: [PlannedExercise] = []
    var records: [SetRecord] = []
    var consent: ConsentRecord?
    var phase: WorkoutPhase = .idle
    var exerciseIndex = 0
    var setNumber = 1
    var isPaused = false
    var elapsed: Double = 0
    var workSeconds: Double = 0
    var hasStableMeasurementStarted = false
    var latestSample: PulseSample?
    var samples: [PulseSample] = []
    var baselineSamples: [PulseSample] = []
    var exerciseSamples: [PulseSample] = []
    var recoverySamples: [PulseSample] = []

    // Demographics and Exercise Configuration
    var userGender: String {
        didSet { defaultPreferences.set(userGender, forKey: "user_gender") }
    }
    var userAge: Int {
        didSet { defaultPreferences.set(userAge, forKey: "user_age") }
    }
    var exerciseName: String {
        didSet { defaultPreferences.set(exerciseName, forKey: "user_exercise") }
    }
    let quickExercises = ["Push-ups", "Squats", "Jumping Jacks", "Running", "Cycling", "Burpees", "Yoga"]

    // Breathing & Respiration Metrics (for Afterburn Time)
    var baselineBreathing: Double?
    var latestBreathingRate: Double?
    var baselineBreathingSamples: [(rate: Double, seconds: Double)] = []
    var recoveryBreathingSamples: [(rate: Double, seconds: Double)] = []
    var breathRecoverySeconds: Double? // Afterburn time: seconds to return to baseline breathing rate
    var pulseRecoverySeconds: Double?
    var caloriesBurned: Double?
    var epocCalories: Double?

    // Camera Snapshots: Peak (>100 BPM) and Rested Normal
    var peakSnapshot: NSImage?
    var peakSnapshotPulse: Double = 0
    var peakSnapshotTime: Double = 0
    var lastSnapshotAt: Double = 0
    var restedSnapshot: NSImage?
    var restedSnapshotPulse: Double = 0
    var restedSnapshotTime: Double = 0
    var snapshotBanner: String?

    var engine = RecoveryEngine()
    var measurementSettings = MeasurementSettings()
    var lastResult: SetRecord?
    var errorMessage: String?
    var apiKeyConfigured = false
    var resultWasSaved = true
    var now = ProcessInfo.processInfo.systemUptime
    let sensor = SensorController()

    @ObservationIgnored private var store: AppStore?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var measurementTask: Task<Void, Never>?
    @ObservationIgnored private var phaseStarted: Double = 0
    @ObservationIgnored private var accumulated: Double = 0
    @ObservationIgnored private var defaultPreferences: UserDefaults
    @ObservationIgnored private var memoryAPIKey: String?

    var mayEnterApp: Bool { consent?.isCurrent == true }
    var currentItem: PlannedExercise? { plan.indices.contains(exerciseIndex) ? plan[exerciseIndex] : nil }
    var currentExercise: Exercise? { currentItem.flatMap { item in exercises.first { $0.id == item.exerciseID } } }
    var baseline: Double? { engine.baseline }
    var hasFreshSample: Bool { latestSample.map { now - $0.seconds <= engine.policy.maximumSampleGap } ?? false }
    var readingIsValid: Bool { latestSample.map { hasFreshSample && engine.policy.accepts($0) && sensor.validationOK } ?? false }
    var isEditingAllowed: Bool { !phase.isActive && phase != .result && phase != .ready }
    var completedSets: Int { records.filter { Calendar.current.isDateInToday($0.date) && !$0.isDemo }.count }
    var canStart: Bool { mayEnterApp && !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty }
    var pulseChartOrigin: Double? {
        [.calibrating, .recovering, .ready].contains(phase) ? phaseStarted : nil
    }

    var primaryTitle: String {
        switch phase {
        case .idle, .interrupted: "Start Automated Session (30s · 1m · 1m)"
        case .calibrating: "Cancel Baseline Check"
        case .ready: "Start Exercise Set (1 Min)"
        case .working: "Finish Exercise & Start Recovery"
        case .recovering: "Finish Recovery Early"
        case .result: "Start Next Exercise Session"
        case .finished: "Start Next Exercise Session"
        }
    }

    init() {
        defaultPreferences = .standard
        userGender = defaultPreferences.string(forKey: "user_gender") ?? "Male"
        let savedAge = defaultPreferences.integer(forKey: "user_age")
        userAge = savedAge == 0 ? 26 : savedAge
        exerciseName = defaultPreferences.string(forKey: "user_exercise") ?? "Jumping Jacks"

        if let data = defaultPreferences.data(forKey: "measurement-settings"),
           let settings = try? JSONDecoder().decode(MeasurementSettings.self, from: data) {
            measurementSettings = settings.normalized
        }
        var policy = measurementSettings.policy
        policy.baselineSeconds = Self.normalDuration
        engine = RecoveryEngine(policy: policy)

        do {
            if let url = Bundle.main.url(forResource: "exercises", withExtension: "json") {
                exercises = (try? JSONDecoder().decode([Exercise].self, from: Data(contentsOf: url))) ?? []
            }
            store = try AppStore()
            records = try store?.records() ?? []
            if let saved = try store?.plan() {
                plan = saved
            } else {
                plan = [PlannedExercise(exerciseID: "custom", sets: 1, repetitions: 0, targetSeconds: 60)]
            }
        } catch { errorMessage = "Could not load local data: \(error.localizedDescription)" }

        if let data = defaultPreferences.data(forKey: "consent") {
            consent = try? JSONDecoder().decode(ConsentRecord.self, from: data)
        }

        // Always check environment for latest API key and persist to Keychain:
        let envKey = ProcessInfo.processInfo.environment["SMARTSPECTRA_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let envKey, !envKey.isEmpty {
            memoryAPIKey = envKey
            try? CredentialStore.save(envKey)
        } else {
            memoryAPIKey = CredentialStore.read()
        }
        apiKeyConfigured = !(memoryAPIKey ?? "").isEmpty

        sensor.onSample = { [weak self] in self?.receive($0) }
        sensor.onBreathingSample = { [weak self] rate, confidence, seconds in
            self?.receiveBreathing(rate: rate, confidence: confidence, seconds: seconds)
        }
        sensor.onInvalidation = { [weak self] in self?.engine.invalidate() }
        sensor.onFailure = { [weak self] in self?.sensorFailed($0) }
        sensor.onCameraFailure = { [weak self] in self?.errorMessage = $0 }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        if mayEnterApp && apiKeyConfigured {
            openCamera()
        }
    }

    func acceptConsent() {
        consent = ConsentRecord()
        if let data = try? JSONEncoder().encode(consent) {
            defaultPreferences.set(data, forKey: "consent")
        }
        if apiKeyConfigured {
            openCamera()
        }
    }

    func revokeConsent() {
        interrupt()
        stopSensor(); consent = nil
        defaultPreferences.removeObject(forKey: "consent")
        resetSession()
    }

    func configureKey(_ key: String) {
        guard !phase.isActive else { return }
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { errorMessage = "Enter a valid key."; return }
        do {
            try CredentialStore.save(clean)
            memoryAPIKey = clean; apiKeyConfigured = true
            if mayEnterApp && !sensor.isCameraRunning {
                openCamera()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func removeKey() {
        guard !phase.isActive else { return }
        do { try CredentialStore.delete(); memoryAPIKey = nil; apiKeyConfigured = false }
        catch { errorMessage = error.localizedDescription }
    }

    func primaryAction() {
        guard canStart else { return }
        switch phase {
        case .idle, .interrupted:
            startBaseline()
        case .calibrating:
            engine = RecoveryEngine(policy: measurementSettings.policy)
            phase = .idle
            hasStableMeasurementStarted = false
        case .ready:
            startExercise()
        case .working:
            finishExerciseAndStartRecovery()
        case .recovering:
            finishRecovery(outcome: .endedManually)
        case .result, .finished:
            resetSession()
        }
    }

    func openCamera() {
        guard mayEnterApp else { return }
        if sensor.isCameraRunning { return }
        measurementTask?.cancel()
        measurementTask = Task {
            // Credit-free local camera preview: zero calls to SmartSpectra SDK!
            await sensor.startCameraPreview()
        }
    }

    func closeCamera() {
        if phase.isActive { interrupt() }
        stopSensor()
    }

    // Step 1: Start 30-Second Normal Baseline Calibration
    func startBaseline() {
        guard mayEnterApp, !exerciseName.isEmpty else { return }
        phase = .calibrating; phaseStarted = monotonicNow(); accumulated = 0
        elapsed = 0; latestSample = nil; samples = []; lastResult = nil
        baselineSamples = []; exerciseSamples = []; recoverySamples = []
        baselineBreathingSamples = []; recoveryBreathingSamples = []
        baselineBreathing = nil; latestBreathingRate = nil
        breathRecoverySeconds = nil; pulseRecoverySeconds = nil
        caloriesBurned = nil; epocCalories = nil
        peakSnapshot = nil; peakSnapshotPulse = 0; restedSnapshot = nil; restedSnapshotPulse = 0
        snapshotBanner = nil
        hasStableMeasurementStarted = false

        var policy = measurementSettings.policy
        policy.baselineSeconds = Self.normalDuration
        engine = RecoveryEngine(policy: policy)
        engine.startBaseline(at: phaseStarted)

        startSensor()
    }

    // Step 2: Automated Transition to 1-Minute Exercise Set
    // In Testing (Credit Saver) mode: Stop SDK for the exercise time to preserve credits and avoid motion noise.
    // In Production (Full Use) mode: Keep SDK running continuously.
    func startExercise() {
        if measurementSettings.sdkOperationMode == .testingCreditSaver {
            stopSensor()
        }
        phase = .working
        phaseStarted = monotonicNow()
        accumulated = 0
        elapsed = 0
        isPaused = false
        hasStableMeasurementStarted = false
    }

    // Step 3: Automated Transition to 1-Minute Afterburn Recovery
    // "1 minutes for getting the resting health rate session"
    func finishExerciseAndStartRecovery() {
        workSeconds = max(10.0, elapsedTime())
        isPaused = false
        accumulated = 0
        phase = .recovering
        phaseStarted = monotonicNow()
        elapsed = 0
        samples = []
        recoverySamples = []
        recoveryBreathingSamples = []
        hasStableMeasurementStarted = false
        engine.startRecovery(at: phaseStarted)
        startSensor()
    }

    func updateMeasurementSettings(_ settings: MeasurementSettings) {
        let updated = settings.normalized
        let policyChanged = updated.policy != measurementSettings.policy
        measurementSettings = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaultPreferences.set(data, forKey: "measurement-settings")
        }
        guard policyChanged else { return }
        if phase == .calibrating || phase == .recovering {
            var revised = RecoveryEngine(policy: updated.policy, baseline: engine.baseline)
            if phase == .calibrating {
                revised.startBaseline(at: phaseStarted)
                for sample in samples { revised.consumeBaseline(sample) }
            } else {
                revised.startRecovery(at: phaseStarted)
                for sample in samples { revised.consumeRecovery(sample) }
            }
            revised.checkFreshness(at: monotonicNow())
            engine = revised
            finishMeasurementIfReady()
        } else { engine.policy = updated.policy }
    }

    func startSensor() {
        guard consent?.isCurrent == true else { return }
        if sensor.isRunning { return }
        measurementTask?.cancel()
        measurementTask = Task {
            guard !Task.isCancelled else { return }
            await sensor.start(apiKey: memoryAPIKey ?? CredentialStore.read() ?? "")
        }
    }

    func stopSensor() {
        measurementTask?.cancel()
        measurementTask = nil
        sensor.stop()
    }

    func togglePause() {
        guard phase == .working else { return }
        if isPaused { phaseStarted = monotonicNow() }
        else { accumulated = elapsedTime() }
        isPaused.toggle()
    }

    func selectPlanItem(_ index: Int) {
        guard !phase.isActive, plan.indices.contains(index), phase != .result else { return }
        exerciseIndex = index; setNumber = 1
        phase = baseline == nil ? .idle : .ready
    }

    func add(_ exercise: Exercise, sets: Int, reps: Int, seconds: Int) {
        plan.append(PlannedExercise(exerciseID: exercise.id, sets: sets, repetitions: reps, targetSeconds: seconds))
    }

    func removePlanItem(_ id: UUID) {
        plan.removeAll { $0.id == id }
    }

    func updatePlan(_ item: PlannedExercise) {
        if let idx = plan.firstIndex(where: { $0.id == item.id }) {
            plan[idx] = item
        }
    }

    private func receiveBreathing(rate: Double, confidence: Double, seconds: Double) {
        guard rate.isFinite, (5...45).contains(rate) else { return }
        latestBreathingRate = rate
        if phase == .calibrating {
            baselineBreathingSamples.append((rate: rate, seconds: seconds))
        } else if phase == .recovering {
            recoveryBreathingSamples.append((rate: rate, seconds: seconds))
            // Check for Afterburn return (return to normal baseline breathing rate):
            if breathRecoverySeconds == nil, let base = baselineBreathing {
                if abs(rate - base) <= 2.5 {
                    breathRecoverySeconds = elapsedTime()
                    snapshotBanner = "🌿 Breathing recovered (Afterburn: \(Int(breathRecoverySeconds ?? 0))s)"
                }
            }
        }
    }

    private func receive(_ sample: PulseSample) {
        latestSample = sample

        // Check for Peak snapshot (>100 BPM) during exercise or recovery:
        if (phase == .working || phase == .recovering) && sample.bpm >= 100 {
            let now = ProcessInfo.processInfo.systemUptime
            let shouldSnap = peakSnapshot == nil ||
                sample.bpm > (peakSnapshotPulse + 2) ||
                (now - lastSnapshotAt >= 15 && sample.bpm >= 100)
            if shouldSnap, let frame = sensor.frame {
                peakSnapshot = frame
                peakSnapshotPulse = sample.bpm
                peakSnapshotTime = now
                lastSnapshotAt = now
                snapshotBanner = "📸 Peak pulse snapped: \(Int(sample.bpm.rounded())) BPM"
            }
        }

        if phase == .idle || phase == .result || phase == .finished {
            return
        }

        if phase == .working {
            exerciseSamples.append(sample)
            return
        }

        guard phase == .calibrating || phase == .recovering || phase == .ready else { return }

        samples.append(sample)
        if samples.count > 12000 { samples.removeFirst(samples.count - 12000) }

        if phase == .calibrating {
            baselineSamples.append(sample)
        } else if phase == .recovering {
            recoverySamples.append(sample)
        }

        if phase == .ready { return }

        // Start measurement timer once we have a stable reading, and don't restart it once started.
        if !hasStableMeasurementStarted {
            let timeInPhase = monotonicNow() - phaseStarted
            let isStable = (sample.stable && sample.validationOK && engine.policy.accepts(sample))
                || (timeInPhase >= 6.0 && sample.bpm >= 40 && sample.bpm <= 180)
            if isStable {
                hasStableMeasurementStarted = true
                phaseStarted = sample.seconds
                if phase == .calibrating {
                    engine.startBaseline(at: sample.seconds)
                } else if phase == .recovering {
                    engine.startRecovery(at: sample.seconds)
                }
            } else {
                return
            }
        }

        if phase == .calibrating {
            engine.consumeBaseline(sample)
        } else {
            engine.consumeRecovery(sample)
            // Pulse recovery return check:
            if pulseRecoverySeconds == nil, let base = baseline, abs(sample.bpm - base) <= measurementSettings.policy.toleranceBPM {
                pulseRecoverySeconds = elapsedTime()
            }
            // Check for Rested snapshot when returning near normal baseline:
            if (engine.recovered || abs(sample.bpm - (baseline ?? 70)) <= engine.policy.toleranceBPM) && restedSnapshot == nil {
                if let frame = sensor.frame {
                    restedSnapshot = frame
                    restedSnapshotPulse = sample.bpm
                    restedSnapshotTime = ProcessInfo.processInfo.systemUptime
                    snapshotBanner = "📸 Rested pulse snapped: \(Int(sample.bpm.rounded())) BPM"
                }
            }
        }
        finishMeasurementIfReady()
    }

    private func finishMeasurementIfReady() {
        if phase == .calibrating, elapsed >= Self.normalDuration {
            completeBaselineAndAdvance()
        } else if phase == .recovering, (elapsed >= Self.recoveryDuration || engine.recovered) {
            finishRecovery(outcome: .observed)
        }
    }

    private func completeBaselineAndAdvance() {
        if engine.baseline == nil {
            let valid = baselineSamples.filter { $0.bpm >= 40 && $0.bpm <= 130 }
            if !valid.isEmpty {
                let sorted = valid.map(\.bpm).sorted()
                let mid = sorted.count / 2
                let median = sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
                engine.baseline = median
            } else if let latest = latestSample, (40...130).contains(latest.bpm) {
                engine.baseline = latest.bpm
            } else {
                engine.baseline = 72.0
            }
        }
        if baselineBreathing == nil {
            let validBreaths = baselineBreathingSamples.filter { $0.rate >= 6 && $0.rate <= 35 }
            if !validBreaths.isEmpty {
                let sorted = validBreaths.map(\.rate).sorted()
                let mid = sorted.count / 2
                baselineBreathing = sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
            } else {
                baselineBreathing = latestBreathingRate ?? 16.0
            }
        }
        // User requested: Automate based on time: 30s normal -> Stop SDK -> 1m exercise
        startExercise()
    }

    private func finishRecovery(outcome: SetOutcome) {
        guard phase == .recovering, let baseline else { return }
        // HALT SDK IMMEDIATELY: Conserve API credits the exact millisecond recovery concludes.
        stopSensor()
        let peakData = peakSnapshot?.jpegData(compressionQuality: 0.85)
        let restedData = restedSnapshot?.jpegData(compressionQuality: 0.85)
        let maxPulse = exerciseSamples.map(\.bpm).max() ?? (peakSnapshotPulse > 0 ? peakSnapshotPulse : (samples.map(\.bpm).max() ?? (baseline + 35.0)))
        let finalPulse = readingIsValid ? latestSample?.bpm : samples.last?.bpm

        let recSeconds = elapsedTime()
        let breathRec = breathRecoverySeconds ?? recSeconds
        let pulseRec = pulseRecoverySeconds ?? recSeconds

        let cals = CalorieCalculator.calculate(
            gender: userGender,
            age: userAge,
            workSeconds: workSeconds,
            recoverySeconds: recSeconds,
            exerciseName: exerciseName,
            averagePulseBPM: samples.isEmpty ? nil : (samples.map(\.bpm).reduce(0, +) / Double(samples.count)),
            peakPulseBPM: max(peakSnapshotPulse, maxPulse)
        )
        caloriesBurned = cals.total
        epocCalories = cals.epoc

        let record = SetRecord(
            exerciseName: exerciseName,
            workSeconds: workSeconds,
            recoverySeconds: recSeconds,
            baselineBPM: baseline,
            finalBPM: finalPulse,
            outcome: outcome,
            hadMeasurementGaps: engine.hadGaps,
            samples: samples,
            policy: engine.policy,
            sdkVersion: sensor.sdkVersion,
            captureStartedAt: phaseStarted,
            gender: userGender,
            age: userAge,
            normalSeconds: Self.normalDuration,
            peakPulseBPM: max(peakSnapshotPulse, maxPulse),
            peakSnapshotData: peakData,
            restedSnapshotData: restedData,
            baselineSamples: baselineSamples,
            exerciseSamples: exerciseSamples,
            baselineBreathing: baselineBreathing ?? 16.0,
            finalBreathing: latestBreathingRate ?? baselineBreathing ?? 16.0,
            breathRecoverySeconds: breathRec,
            pulseRecoverySeconds: pulseRec,
            caloriesBurned: cals.total,
            epocCalories: cals.epoc
        )

        do {
            guard let store else { throw CocoaError(.persistentStoreOperation) }
            try store.save(record)
            resultWasSaved = true
            records.insert(record, at: 0)
            lastResult = record
            elapsed = record.recoverySeconds
            phase = .result
        } catch {
            errorMessage = "Could not save this result. It is still in this session. \(error.localizedDescription)"
            resultWasSaved = false
            lastResult = record
            phase = .result
        }
    }

    func retrySaveResult() {
        guard !resultWasSaved, let record = lastResult, let store else { return }
        do {
            try store.save(record)
            records.insert(record, at: 0)
            resultWasSaved = true
        } catch { errorMessage = "Could not save the observation: \(error.localizedDescription)" }
    }

    func resetSession() {
        stopSensor()
        phase = .idle; exerciseIndex = 0; setNumber = 1
        isPaused = false; elapsed = 0; workSeconds = 0
        samples = []; baselineSamples = []; exerciseSamples = []; recoverySamples = []
        baselineBreathingSamples = []; recoveryBreathingSamples = []
        baselineBreathing = nil; latestBreathingRate = nil
        breathRecoverySeconds = nil; pulseRecoverySeconds = nil
        caloriesBurned = nil; epocCalories = nil
        latestSample = nil; lastResult = nil
        hasStableMeasurementStarted = false
        peakSnapshot = nil; peakSnapshotPulse = 0; lastSnapshotAt = 0
        restedSnapshot = nil; restedSnapshotPulse = 0
        snapshotBanner = nil
        engine = RecoveryEngine(policy: measurementSettings.policy)
        openCamera()
    }

    func interrupt() {
        if phase == .recovering { finishRecovery(outcome: .interrupted) }
        if phase.isActive || phase == .ready {
            engine = RecoveryEngine(policy: measurementSettings.policy); phase = .interrupted
            latestSample = nil; isPaused = false
            hasStableMeasurementStarted = false
        }
        if sensor.isCameraRunning || sensor.isStarting { stopSensor() }
    }

    private func sensorFailed(_ message: String) {
        let key = memoryAPIKey ?? CredentialStore.read() ?? ""
        errorMessage = key.isEmpty ? message : message.replacingOccurrences(of: key, with: "[redacted]")
        interrupt()
        if phase == .calibrating { phase = .interrupted }
        sensor.lastSDKError = errorMessage
        if mayEnterApp { openCamera() }
    }

    func clearHistory() {
        do { try store?.deleteHistory(); records = []; lastResult = nil }
        catch { errorMessage = "Could not delete history: \(error.localizedDescription)" }
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "afterburn-recovery-history.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(records).write(to: url, options: .atomic)
        } catch { errorMessage = "Could not export history: \(error.localizedDescription)" }
    }

    func shutdown() { interrupt(); stopSensor(); timer?.invalidate() }

    private func monotonicNow() -> Double { ProcessInfo.processInfo.systemUptime }
    private func elapsedTime() -> Double {
        accumulated + (isPaused ? 0 : max(0, monotonicNow() - phaseStarted))
    }

    private func tick() {
        now = monotonicNow()
        if phase.isActive {
            let totalPhaseTime = monotonicNow() - phaseStarted
            if phase == .working || hasStableMeasurementStarted {
                elapsed = elapsedTime()
                engine.checkFreshness(at: now)

                // AUTOMATED TIME-BASED PROGRESSION:
                // 30s Normal Baseline -> 60s Exercise (SDK off) -> 60s Recovery (SDK on) -> Results
                if phase == .calibrating && elapsed >= Self.normalDuration {
                    completeBaselineAndAdvance()
                } else if phase == .working && elapsed >= Self.exerciseDuration {
                    finishExerciseAndStartRecovery()
                } else if phase == .recovering && elapsed >= Self.recoveryDuration {
                    finishRecovery(outcome: .observed)
                }
            } else {
                elapsed = 0
            }

            // HARD SAFETY TIMEOUT:
            // Under NO circumstance allow the SmartSpectra SDK to run past the allotted budget,
            // even if frames dropped, lighting changed, or stable signal was delayed.
            if phase == .calibrating && totalPhaseTime >= (Self.normalDuration + 10.0) {
                completeBaselineAndAdvance()
            } else if phase == .recovering && totalPhaseTime >= (Self.recoveryDuration + 10.0) {
                finishRecovery(outcome: .observed)
            }
        }
    }
}
