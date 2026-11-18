import SwiftUI

struct ImmersiveStage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSetup = false
    @State private var showVitals = false
    @State private var showEndConfirmation = false
    @State private var celebrating = false
    @State private var celebrationID = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                camera
                LinearGradient(colors: [.clear, .black.opacity(0.12), .black.opacity(0.68)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
                VStack(spacing: 18) {
                    if !model.isStageFocused { Color.clear.frame(height: 93) }
                    topControls
                    Spacer(minLength: 12)
                    if model.sensor.frame == nil { cameraGuidance }
                    Spacer(minLength: 12)
                    if celebrating {
                        Label("Set complete. Nice work!", systemImage: "checkmark.seal.fill")
                            .font(.headline).padding(14).floatingGlass().transition(.opacity)
                    }
                    if model.phase == .result, let result = model.lastResult { resultSummary(result) }
                    controlDock
                }.padding(model.isStageFocused ? 28 : 24)
                if celebrating && !reduceMotion { ConfettiOverlay().id(celebrationID).allowsHitTesting(false) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .sheet(isPresented: $showSetup) { WorkoutSetupView().environment(model) }
        .sheet(isPresented: $showVitals) { LiveVitalsView().environment(model) }
        .confirmationDialog("End this session?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End session", role: .destructive) { model.interrupt(); model.resetSession() }
            Button("Keep training", role: .cancel) {}
        } message: { Text("Capture stops. A recovery in progress is saved as interrupted.") }
        .onChange(of: model.phase) { old, new in
            if old == .working && new == .recovering { celebrationID = UUID(); celebrating = true }
        }
        .task(id: celebrationID) {
            guard celebrating else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            celebrating = false
        }
    }
    private var camera: some View {
        ZStack {
            Color(red: 0.055, green: 0.10, blue: 0.16)
            if let frame = model.sensor.frame {
                GeometryReader { geometry in
                    Image(nsImage: frame).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
            } else {
                RadialGradient(colors: [.teal.opacity(0.18), .clear], center: .topLeading, startRadius: 20, endRadius: 650)
                RadialGradient(colors: [.blue.opacity(0.2), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 600)
            }
        }
    }
    private var topControls: some View {
        GlassGroup {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Label(model.phase == .working ? "Exercise in progress" : "Your session", systemImage: model.phase == .working ? "bolt.fill" : "waveform.path.ecg")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(model.currentExercise?.displayName ?? "Plan your first movement")
                        .font(.system(size: 22, weight: .semibold, design: .rounded)).lineLimit(2)
                    if let item = model.currentItem {
                        Text("Set \(model.setNumber) of \(item.sets)   /   \(item.repetitions) reps   /   \(item.targetSeconds)s target")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }.padding(20).floatingGlass()
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 10) {
                        GlassIconButton(title: model.sensor.isCameraRunning ? "Close camera" : "Open camera", symbol: model.sensor.isCameraRunning ? "video.slash" : "video") {
                            if model.sensor.isCameraRunning { model.closeCamera() } else { model.openCamera() }
                        }.disabled(model.sensor.isStarting)
                        GlassIconButton(title: "Edit session", symbol: "slider.horizontal.3") { showSetup = true }.disabled(!model.isEditingAllowed)
                        GlassIconButton(title: model.isStageFocused ? "Exit full screen" : "Full screen camera", symbol: model.isStageFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                            model.isStageFocused.toggle(); NSApp.keyWindow?.toggleFullScreen(nil)
                        }
                    }
                    LiveVitalsPanel { showVitals = true }
                }
            }
        }
    }
    private var cameraGuidance: some View {
        VStack(spacing: 14) {
            if model.sensor.isStarting { ProgressView().controlSize(.large) }
            else {
                Image(systemName: model.phase == .working ? "figure.strengthtraining.functional" : "person.crop.rectangle")
                    .font(.system(size: 72, weight: .ultraLight)).foregroundStyle(.white.opacity(0.65))
            }
            Text(model.sensor.isStarting ? model.sensor.status : model.phase == .working ? "One rep at a time." : "Your camera is your recovery window.")
                .font(.system(size: 24, weight: .medium, design: .rounded))
            Text(model.phase == .working ? "Camera off during your set. Finish whenever you’re ready." : "Face the camera in even light. Live pulse appears after warm-up.")
                .font(.callout).foregroundStyle(.white.opacity(0.65))
        }.foregroundStyle(.white).multilineTextAlignment(.center).padding()
    }
    private var controlDock: some View {
        GlassGroup {
            VStack(spacing: 15) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 30) { timer; Spacer(minLength: 20); coaching; actions }
                    HStack(spacing: 24) { timer; Spacer(); actions }
                }
                if model.phase == .calibrating || model.phase == .recovering {
                    ProgressView(value: model.phase == .calibrating ? min(1, model.engine.baselineProgress / 30) : min(1, model.engine.confirmationProgress / 15))
                        .tint(.mint).accessibilityLabel("Valid signal progress")
                }
                HStack(spacing: 9) {
                    Image(systemName: model.readingIsValid ? "checkmark.circle.fill" : "info.circle")
                    Text(signalText).lineLimit(2)
                    Spacer()
                    if model.phase.isActive || model.baseline != nil {
                        Button("End session") { showEndConfirmation = true }.buttonStyle(.borderless)
                    }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(24).floatingGlass(radius: 30)
        }
    }
    private var timer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.phase == .calibrating ? "Valid baseline time remaining" : model.phase == .working ? "Exercise elapsed" : model.phase == .recovering ? "Since your set ended" : "Your time")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text(timerText).font(.system(size: 60, weight: .medium, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText()).animation(reduceMotion ? nil : .smooth(duration: 0.22), value: timerText)
                .accessibilityIdentifier("workout-timer")
        }
    }
    private var coaching: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.phase == .working ? "Make this set yours." : model.phase == .recovering ? "Let your rhythm settle." : "Your pace, measured.").font(.headline)
            Text(model.phase == .recovering ? "Hold still. We need 15 valid seconds near baseline." : "\(model.plan.reduce(0) { $0 + $1.sets }) sets in your session. You control the next move.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: 290, alignment: .leading)
    }
    private var actions: some View {
        HStack(spacing: 10) {
            if model.phase == .working {
                GlassIconButton(title: model.isPaused ? "Resume set" : "Pause set", symbol: model.isPaused ? "play.fill" : "pause.fill", action: model.togglePause)
            }
            PrimaryButton(title: actionTitle, symbol: model.phase == .working ? "checkmark" : "arrow.right", tint: .orange) {
                if model.plan.isEmpty { model.section = .exercises }
                else if !model.sensor.isCameraRunning && (model.phase == .idle || model.phase == .interrupted) { model.openCamera() }
                else if !model.apiKeyConfigured { model.section = .settings }
                else if !model.resultWasSaved { model.retrySaveResult() }
                else { model.primaryAction() }
            }.disabled(model.isPaused).accessibilityIdentifier("workout-primary")
        }
    }
    private func resultSummary(_ record: SetRecord) -> some View {
        let analysis = RecoveryAnalysis(record: record)
        return HStack(spacing: 25) {
            Label(model.resultWasSaved ? "Set recorded" : "Save needs retry", systemImage: "checkmark.circle")
            Text("\(TimeText.duration(record.recoverySeconds)) observed")
            Text("\(Int((analysis.signalCoverage * 100).rounded()))% signal coverage")
            Text(record.outcome.label).foregroundStyle(.secondary)
        }.font(.system(size: 12)).padding(18).floatingGlass()
    }
    private var actionTitle: String {
        if model.plan.isEmpty { return "Choose exercises" }
        if !model.sensor.isCameraRunning && (model.phase == .idle || model.phase == .interrupted) { return "Open camera" }
        if !model.apiKeyConfigured { return "Add SmartSpectra key" }
        if !model.resultWasSaved { return "Retry saving" }
        return model.primaryTitle
    }
    private var timerText: String {
        switch model.phase {
        case .idle, .interrupted: TimeText.clock(30)
        case .calibrating: TimeText.clock(ceil(max(0, 30 - model.engine.baselineProgress)))
        case .ready: TimeText.clock(Double(model.currentItem?.targetSeconds ?? 45))
        case .finished: "Done"
        default: TimeText.clock(model.elapsed)
        }
    }
    private var signalText: String {
        if model.phase == .working { return "Camera off during exercise. Pulse recovery is a wellness observation, not exercise clearance." }
        if model.sensor.isStarting || !model.sensor.isRunning || !model.sensor.validationOK {
            return model.sensor.feedback(at: model.now)
        }
        if !model.hasFreshSample { return "Waiting for a fresh measured pulse. Keep still and face the camera." }
        if let sample = model.latestSample, !(40...110).contains(sample.bpm) { return "Outside this prototype’s supported pulse range; excluded from recovery detection." }
        return model.readingIsValid ? "Stable signal. \(Int(model.latestSample?.confidence ?? 0))% confidence." : model.sensor.validationHint
    }
}

private struct ConfettiOverlay: View {
    @State private var falling = false
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<44, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill([Color.orange, .pink, .mint, .yellow, .cyan][index % 5])
                    .frame(width: 6, height: 11).rotationEffect(.degrees(falling ? Double(index * 37) : 0))
                    .position(x: geometry.size.width * CGFloat((index * 23) % 100) / 100, y: falling ? geometry.size.height + 30 : -30)
                    .opacity(falling ? 0 : 1)
                    .animation(.easeOut(duration: 2.4).delay(Double(index % 8) * 0.06), value: falling)
            }
        }.onAppear { falling = true }.accessibilityHidden(true)
    }
}
