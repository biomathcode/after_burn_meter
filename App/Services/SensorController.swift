import AppKit
import AVFoundation
import Observation

@MainActor @Observable
final class SensorController {
    var frame: NSImage?
    var status = "Camera off"
    var validationHint = "Sit facing the camera in even light."
    var validationOK = false
    var isRunning = false
    var isPreviewing = false
    var isCameraRunning: Bool { isPreviewing || isRunning }
    var lastSDKError: String?
    var vitals = LiveVitals()
    var acceptedFrames = 0
    var blockedFrames = 0
    var metricPackets = 0
    var pulseSamplesReceived = 0
    var hasValidation = false
    var processingStatus = "Not started"
    var measurementStarted: Double?
    var onCameraFailure: ((String) -> Void)?
    var isStarting = false
    var cameras: [ABCamera] = []
    var selectedCameraID = ""
    var onSample: ((PulseSample) -> Void)?
    var onBreathingSample: ((Double, Double, Double) -> Void)?
    var onInvalidation: (() -> Void)?
    var onFailure: ((String) -> Void)?
    @ObservationIgnored private let bridge = ABSensor()
    @ObservationIgnored private let previewCapture = CameraPreviewCapture()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var metricClock = MetricClock()

    var sdkVersion: String { ABSensor.version() }
    var hasSigning: Bool { ABSensor.hasDevelopmentSignature() }

    func measurementElapsed(at now: Double) -> Double { measurementStarted.map { max(0, now - $0) } ?? 0 }

    func feedback(at now: Double) -> String {
        if isStarting { return "Starting the camera and authenticating SmartSpectra…" }
        if isPreviewing { return "Camera preview is live. Start a measurement for pulse and other vitals." }
        guard isRunning else { return "Open your camera to check framing, then start a measurement." }
        if hasValidation && !validationOK { return validationHint }
        if measurementElapsed(at: now) > 20 && pulseSamplesReceived == 0 {
            return "No pulse samples yet. Open All vitals to check accepted frames and SDK feedback."
        }
        if metricPackets == 0 { return "Camera is live. Waiting for the first SDK metric packet." }
        return validationHint
    }

    init() {
        bridge.onFrame = { [weak self] image in
            MainActor.assumeIsolated { self?.frame = image }
        }
        bridge.onValidation = { [weak self] code, hint in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hasValidation = true
                self.validationOK = code == 0
                self.validationHint = hint.isEmpty ? "Hold still and face the camera." : hint
                if code != 0 { self.onInvalidation?() }
            }
        }
        bridge.onState = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.status = state; self.isRunning = true; self.isStarting = false
                if self.measurementStarted == nil { self.measurementStarted = ProcessInfo.processInfo.systemUptime }
            }
        }
        bridge.onProcessing = { [weak self] state in
            MainActor.assumeIsolated { self?.processingStatus = state }
        }
        bridge.onDiagnostics = { [weak self] accepted, blocked, packets in
            MainActor.assumeIsolated {
                self?.acceptedFrames = Int(accepted); self?.blockedFrames = Int(blocked)
                self?.metricPackets = max(self?.metricPackets ?? 0, Int(packets))
            }
        }
        bridge.onMetrics = { [weak self] readings, timestamp in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.metricPackets += 1
                let now = ProcessInfo.processInfo.systemUptime
                let wallTime = Date().timeIntervalSince1970
                for reading in readings {
                    guard let kind = VitalKind(rawValue: reading.kind) else { continue }
                    let measuredAt = self.metricClock.seconds(for: reading.timestamp,
                        callback: timestamp, uptime: now, wallTime: wallTime)
                    let added = self.vitals.append(kind, value: reading.value,
                        confidence: reading.confidence?.doubleValue, stable: reading.stable, seconds: measuredAt)
                    if kind == .breathing, added {
                        self.onBreathingSample?(reading.value, reading.confidence?.doubleValue ?? 0, measuredAt)
                    }
                    guard kind == .pulse, added else { continue }
                    self.pulseSamplesReceived += 1
                    guard now - measuredAt <= 3, measuredAt <= now + 0.5 else {
                        self.onInvalidation?(); continue
                    }
                    self.onSample?(PulseSample(seconds: measuredAt, bpm: reading.value,
                        confidence: reading.confidence?.doubleValue ?? 0,
                        stable: reading.stable, validationOK: self.validationOK))
                }
            }
        }
        bridge.onError = { [weak self] message in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.lastSDKError = message
                self.stop()
                self.onFailure?(message)
            }
        }
    }

    func refreshCameras() {
        guard !isCameraRunning && !isStarting else { return }
        cameras = CameraPreviewCapture.cameras()
    }

    func start(apiKey: String) async {
        guard !Task.isCancelled else { return }
        // If the SmartSpectra SDK is already running in this continuous session, preserve it!
        if isRunning && !isStarting && !isPreviewing {
            return
        }
        stop()
        vitals = LiveVitals(); metricClock = MetricClock()
        acceptedFrames = 0; blockedFrames = 0; metricPackets = 0; pulseSamplesReceived = 0
        hasValidation = false; validationHint = "Waiting for the SDK’s framing and lighting check."
        processingStatus = "Starting"
        guard !apiKey.isEmpty else {
            onFailure?("Add your SmartSpectra API key in Settings, or launch with scripts/run.py to load the development .env file.")
            return
        }
        let token = generation
        isStarting = true; status = "Requesting camera"
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard token == generation, !Task.isCancelled else { return }
        guard allowed else {
            isStarting = false; status = "Camera access needed"
            onFailure?("Allow Afterburn in System Settings → Privacy & Security → Camera, then try again.")
            return
        }
        await previewCapture.stopAndWait()
        await stopSDKAndWait()
        guard token == generation, !Task.isCancelled else { return }
        lastSDKError = nil
        status = "Starting SmartSpectra"
        bridge.start(withAPIKey: apiKey, cameraID: selectedCameraID.isEmpty ? nil : selectedCameraID)
    }

    func startCameraPreview() async {
        if isCameraRunning { return }
        stop()
        let token = generation
        isStarting = true; status = "Requesting camera"
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard token == generation, !Task.isCancelled else { return }
        guard allowed else {
            isStarting = false; status = "Camera permission needed"
            onCameraFailure?("Allow Afterburn in System Settings → Privacy & Security → Camera.")
            return
        }
        await stopSDKAndWait()
        guard token == generation, !Task.isCancelled else { return }
        do {
            try await previewCapture.start(cameraID: selectedCameraID) { [weak self] image in
                MainActor.assumeIsolated {
                    guard let self, self.generation == token else { return }
                    self.frame = image
                }
            }
            guard token == generation, !Task.isCancelled else { previewCapture.stop(); return }
            isStarting = false; isPreviewing = true
            status = "Camera preview"
            validationHint = "Camera is working. Start a baseline to test SmartSpectra."
        } catch {
            guard token == generation else { return }
            isStarting = false; status = "Camera unavailable"
            onCameraFailure?(error.localizedDescription)
        }
    }

    private func stopSDKAndWait() async {
        await withCheckedContinuation { continuation in
            bridge.stop { continuation.resume() }
        }
    }

    func stop() {
        generation += 1
        bridge.stop()
        previewCapture.stop()
        isPreviewing = false
        frame = nil; measurementStarted = nil
        isRunning = false; isStarting = false; validationOK = false
        status = "Camera off"
    }
}

