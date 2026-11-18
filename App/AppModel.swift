import AppKit
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case workout, exercises, history, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .workout: "Today's workout"
        case .exercises: "Exercise library"
        case .history: "Recovery journal"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .workout: "square.grid.2x2"
        case .exercises: "dumbbell"
        case .history: "chart.xyaxis.line"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum WorkoutPhase {
    case idle, calibrating, ready, working, recovering, result, finished, interrupted
    var title: String {
        switch self {
        case .idle: "Find your starting point."
        case .calibrating: "A moment to settle."
        case .ready: "Your next set awaits."
        case .working: "Make this set count."
        case .recovering: "Give yourself a moment."
        case .result: "Back near your baseline."
        case .finished: "That's your session."
        case .interrupted: "Let's reset the signal."
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
    var section: AppSection = .workout
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
    var latestSample: PulseSample?
    var samples: [PulseSample] = []
    var engine = RecoveryEngine()
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
    var canStart: Bool { currentItem != nil && mayEnterApp }
    var primaryTitle: String {
        switch phase {
        case .idle, .interrupted: "Measure baseline"
        case .calibrating: "Cancel baseline"
        case .ready: "Start set"
        case .working: "Finish set"
        case .recovering: "End recovery manually"
        case .result: "Continue"
        case .finished: "Start a new session"
        }
    }

    init() {
        defaultPreferences = .standard
        do {
            guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            exercises = try JSONDecoder().decode([Exercise].self, from: Data(contentsOf: url))
            store = try AppStore()
            records = try store?.records() ?? []
            if let saved = try store?.plan() {
                plan = saved.filter { item in exercises.contains { $0.id == item.exerciseID } }
            } else {
                let names = ["squat to overhead reach", "push-up", "dumbbell biceps curl"]
                plan = names.compactMap { name in
                    exercises.first { $0.name.lowercased() == name }.map { PlannedExercise(exerciseID: $0.id) }
                }
                if plan.isEmpty { plan = exercises.prefix(3).map { PlannedExercise(exerciseID: $0.id) } }
            }
        } catch { errorMessage = "Could not load local data: \(error.localizedDescription)" }
        if let data = defaultPreferences.data(forKey: "consent") {
            consent = try? JSONDecoder().decode(ConsentRecord.self, from: data)
        }
        memoryAPIKey = ProcessInfo.processInfo.environment["SMARTSPECTRA_API_KEY"]
        apiKeyConfigured = !(memoryAPIKey ?? CredentialStore.read() ?? "").isEmpty
        sensor.onSample = { [weak self] in self?.receive($0) }
        sensor.onInvalidation = { [weak self] in self?.engine.invalidate() }
        sensor.onFailure = { [weak self] in self?.sensorFailed($0) }
        sensor.onCameraFailure = { [weak self] in self?.errorMessage = $0 }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func acceptConsent() {
        consent = ConsentRecord()
        if let data = try? JSONEncoder().encode(consent) {
            defaultPreferences.set(data, forKey: "consent")
        }
    }

    func revokeConsent() {
        interrupt()
        stopSensor(); consent = nil
        defaultPreferences.removeObject(forKey: "consent")
        resetSession()
    }

    func configureKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try CredentialStore.save(clean)
            memoryAPIKey = clean; apiKeyConfigured = true
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
        case .idle, .interrupted: startBaseline()
        case .calibrating: stopSensor(); engine = RecoveryEngine(); phase = .idle
        case .ready: startSet()
        case .working: finishSet()
        case .recovering: finishRecovery(outcome: .endedManually)
        case .result: advance()
        case .finished: resetSession()
        }
    }

    func openCamera() {
        guard mayEnterApp, !phase.isActive else { return }
        measurementTask?.cancel()
        measurementTask = Task { await sensor.startCameraPreview() }
    }

    func closeCamera() {
        if phase.isActive { interrupt() }
        stopSensor()
    }

    func startBaseline() {
        guard mayEnterApp, !plan.isEmpty else { return }
        phase = .calibrating; phaseStarted = monotonicNow(); accumulated = 0
        elapsed = 0; latestSample = nil; samples = []; lastResult = nil
        engine.startBaseline(at: phaseStarted)
        startSensor()
    }

    private func startSensor() {
        guard consent?.isCurrent == true else { return }
        measurementTask?.cancel()
        measurementTask = Task {
            guard !Task.isCancelled, phase == .calibrating || phase == .recovering else { return }
            await sensor.start(apiKey: memoryAPIKey ?? CredentialStore.read() ?? "")
        }
    }

    private func stopSensor() {
        measurementTask?.cancel()
        measurementTask = nil
        sensor.stop()
    }

    private func startSet() {
        guard baseline != nil else { startBaseline(); return }
        stopSensor(); latestSample = nil; samples = []
        phase = .working; phaseStarted = monotonicNow()
        accumulated = 0; elapsed = 0; isPaused = false; lastResult = nil
    }

    private func finishSet() {
        workSeconds = elapsedTime()
        isPaused = false; accumulated = 0
        phase = .recovering; phaseStarted = monotonicNow()
        elapsed = 0; samples = []; latestSample = nil
        engine.startRecovery(at: phaseStarted)
        startSensor()
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
        guard isEditingAllowed else { return }
        plan.append(PlannedExercise(exerciseID: exercise.id, sets: sets,
                                    repetitions: reps, targetSeconds: seconds))
        persistPlan()
    }

    func removePlanItem(_ id: UUID) {
        guard isEditingAllowed else { return }
        plan.removeAll { $0.id == id }
        exerciseIndex = min(exerciseIndex, max(0, plan.count - 1))
        setNumber = 1; persistPlan()
    }

    func updatePlan(_ item: PlannedExercise) {
        guard isEditingAllowed, let index = plan.firstIndex(where: { $0.id == item.id }) else { return }
        plan[index] = PlannedExercise(id: item.id, exerciseID: item.exerciseID,
            sets: item.sets, repetitions: item.repetitions, targetSeconds: item.targetSeconds)
        persistPlan()
    }

    private func persistPlan() {
        do { try store?.savePlan(plan) }
        catch { errorMessage = "Could not save your workout: \(error.localizedDescription)" }
    }

    private func receive(_ sample: PulseSample) {
        guard phase == .calibrating || phase == .recovering || phase == .ready else { return }
        latestSample = sample
        if phase == .ready { return }
        samples.append(sample)
        if samples.count > 1200 { samples.removeFirst(samples.count - 1200) }
        if phase == .calibrating {
            engine.consumeBaseline(sample)
            if engine.baseline != nil {
                // Keep capture available for the longer HRV window. Starting
                // the exercise set still stops the camera immediately.
                phase = .ready; elapsed = 0
            }
        } else {
            engine.consumeRecovery(sample)
            if engine.recovered { finishRecovery(outcome: .observed) }
        }
    }

    private func finishRecovery(outcome: SetOutcome) {
        guard phase == .recovering, let item = currentItem,
              let exercise = currentExercise, let baseline else { return }
        let record = SetRecord(exerciseID: exercise.id, exerciseName: exercise.displayName,
            setNumber: setNumber, repetitions: item.repetitions, workSeconds: workSeconds,
            recoverySeconds: elapsedTime(), baselineBPM: baseline,
            finalBPM: readingIsValid ? latestSample?.bpm : nil, outcome: outcome,
            hadMeasurementGaps: engine.hadGaps,
            samples: samples, policy: engine.policy, sdkVersion: sensor.sdkVersion)
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
        stopSensor()
    }

    func retrySaveResult() {
        guard !resultWasSaved, let record = lastResult, let store else { return }
        do {
            try store.save(record)
            records.insert(record, at: 0)
            resultWasSaved = true
        } catch { errorMessage = "Could not save the observation: \(error.localizedDescription)" }
    }

    private func advance() {
        guard resultWasSaved, let item = currentItem else { return }
        if setNumber < item.sets { setNumber += 1; phase = .ready }
        else if exerciseIndex + 1 < plan.count { exerciseIndex += 1; setNumber = 1; phase = .ready }
        else { phase = .finished }
        elapsed = 0; samples = []; latestSample = nil
    }

    func resetSession() {
        stopSensor(); phase = .idle; exerciseIndex = 0; setNumber = 1
        isPaused = false; elapsed = 0; workSeconds = 0
        samples = []; latestSample = nil; lastResult = nil; engine = RecoveryEngine()
    }

    func interrupt() {
        if phase == .recovering { finishRecovery(outcome: .interrupted) }
        if phase.isActive || phase == .ready {
            stopSensor(); engine = RecoveryEngine(); phase = .interrupted
            latestSample = nil; isPaused = false
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
            elapsed = elapsedTime()
            engine.checkFreshness(at: now)
        }

    }
}
