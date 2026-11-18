import SwiftUI

struct ImmersiveStage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSetup = false
    @State private var showVitals = false
    @State private var showMeasurementSettings = false
    @State private var showEndConfirmation = false
    @State private var celebrating = false
    @State private var celebrationID = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cameraBackground

                // Silhouette Guide Overlay:
                // Sourced from Health Icons person outline aesthetic.
                // Outlined, transparent fill with subtle alpha stroke.
                // Visible during baseline check, recovery, and idle to guide user framing.
                if model.sensor.isCameraRunning && model.phase != .working {
                    CameraGuideSilhouette(
                        isValid: model.sensor.validationOK,
                        isStableMeasuring: model.hasStableMeasurementStarted,
                        hint: model.sensor.validationHint
                    )
                }

                VStack(spacing: AppSpacing.lg) {
                    if !model.isStageFocused {
                        Color.clear.frame(height: 84)
                    }

                    ImmersiveTopBar(
                        onShowSettings: { showMeasurementSettings = true },
                        onShowSetup: { showSetup = true },
                        onShowVitals: { showVitals = true }
                    )

                    // Snapshot toast notification
                    if let banner = model.snapshotBanner {
                        SnapshotBannerView(banner: banner)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    // Main Center Stage content based on phase
                    if model.phase == .idle {
                        SessionSetupCard()
                    } else if model.phase == .result, let result = model.lastResult {
                        ScrollView {
                            EndSessionView(record: result)
                                .padding(.vertical, AppSpacing.sm)
                        }
                        .frame(maxHeight: geometry.size.height * 0.65)
                    } else {
                        if model.sensor.frame == nil && model.phase != .working {
                            ImmersiveCameraGuidance()
                        }

                        Spacer(minLength: AppSpacing.sm)

                        if (model.phase == .calibrating || model.phase == .recovering),
                           !model.samples.isEmpty {
                            LivePulseStagePanel()
                        } else if model.phase == .working {
                            ExerciseStagePanel()
                        } else if model.phase == .ready {
                            ReadyStageCard()
                        }
                    }

                    Spacer(minLength: AppSpacing.sm)

                    if celebrating {
                        Label("Session complete! Metrics recorded.", systemImage: "checkmark.seal.fill")
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(.white)
                            .padding(AppSpacing.md)
                            .floatingGlass(radius: AppRadius.lg)
                            .transition(.opacity)
                    }

                    ImmersiveControlDock(onEndSessionRequested: {
                        showEndConfirmation = true
                    })
                }
                .padding(model.isStageFocused ? AppSpacing.xxl : AppSpacing.xl)

                if celebrating && !reduceMotion {
                    ConfettiOverlay()
                        .id(celebrationID)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .onAppear {
            if model.mayEnterApp && !model.sensor.isCameraRunning {
                model.openCamera()
            }
        }
        .sheet(isPresented: $showSetup) {
            WorkoutSetupView().environment(model)
        }
        .sheet(isPresented: $showVitals) {
            LiveVitalsView().environment(model)
        }
        .sheet(isPresented: $showMeasurementSettings) {
            MeasurementSettingsSheet().environment(model)
        }
        .confirmationDialog("End this session?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                model.interrupt()
                model.resetSession()
            }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Session stops. Progress in this set will be concluded.")
        }
        .onChange(of: model.phase) { old, new in
            if old == .recovering && new == .result {
                celebrationID = UUID()
                celebrating = true
            }
        }
        .task(id: celebrationID) {
            guard celebrating else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            celebrating = false
        }
    }

    private var cameraBackground: some View {
        ZStack {
            AppColors.cameraSlate
            if model.phase == .working {
                // Dim camera during exercise since SDK is paused
                Color.black.opacity(0.85)
            } else if let frame = model.sensor.frame {
                GeometryReader { geometry in
                    Image(nsImage: frame)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
        }
    }
}

// MARK: - Snapshot Toast Banner
private struct SnapshotBannerView: View {
    let banner: String
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "camera.shutter.button.fill")
                .foregroundStyle(AppColors.brandOrange)
            Text(banner)
                .font(AppTypography.captionMedium)
                .foregroundStyle(.white)
            if let thumb = model.peakSnapshot ?? model.restedSnapshot {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .floatingGlass(radius: AppRadius.pill)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Initial Session Setup Card
private struct SessionSetupCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassGroup {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    HealthIconView("person", size: 28, color: AppColors.brandTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automated Recovery Session")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(.white)
                        Text("1-Click flow: 30s Normal Check → 60s Exercise (SDK off) → 60s Afterburn Recovery")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                }

                Divider().opacity(0.3)

                // Demographics: Gender and Age
                HStack(alignment: .top, spacing: AppSpacing.xl) {
                    // Gender selection
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Gender")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(.white.opacity(0.85))
                        HStack(spacing: AppSpacing.xxs) {
                            ForEach(["Male", "Female", "Other", "Prefer not to say"], id: \.self) { g in
                                let selected = model.userGender == g
                                Button {
                                    model.userGender = g
                                } label: {
                                    Text(g)
                                        .font(AppTypography.captionMedium)
                                        .padding(.horizontal, AppSpacing.xs + 3)
                                        .padding(.vertical, AppSpacing.xxs + 2)
                                        .background(
                                            selected ? AppColors.brandTeal : Color.white.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selected ? AppColors.cameraSlate : .white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .buttonStyle(.tactile(scale: 0.96))
                            }
                        }
                    }

                    // Age selector
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Age")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(.white.opacity(0.85))
                        HStack(spacing: AppSpacing.xs) {
                            Button {
                                if model.userAge > 10 { model.userAge -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .buttonStyle(.plain)

                            Text("\(model.userAge) yrs")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .frame(minWidth: 54, alignment: .center)

                            Button {
                                if model.userAge < 100 { model.userAge += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                }

                // Exercise Selection
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Exercise to be performed")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(.white.opacity(0.85))

                    // Preset chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(model.quickExercises, id: \.self) { ex in
                                let selected = model.exerciseName == ex
                                Button {
                                    model.exerciseName = ex
                                } label: {
                                    Text(ex)
                                        .font(AppTypography.captionMedium)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, AppSpacing.xxs + 3)
                                        .background(
                                            selected ? AppColors.brandOrange : Color.white.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selected ? .white : .white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .buttonStyle(.tactile(scale: 0.96))
                            }
                        }
                    }

                    // Custom text input
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "pencil.line")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 13))
                        TextField("Or enter custom exercise name...", text: Bindable(model).exerciseName)
                            .textFieldStyle(.plain)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                }

                // CTA Row
                HStack {
                    if !model.apiKeyConfigured {
                        Text("Add SmartSpectra key in Settings to measure pulse")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.brandOrange)
                    } else {
                        Text("Camera active · Automated 30s → 60s → 60s workflow")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer()

                    PrimaryButton(
                        title: "Start Automated Session",
                        symbol: "play.circle.fill",
                        tint: AppColors.brandOrange
                    ) {
                        if !model.apiKeyConfigured {
                            model.section = .settings
                        } else {
                            model.startBaseline()
                        }
                    }
                    .disabled(model.exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 580)
            .floatingGlass(radius: AppRadius.xl)
        }
    }
}

// MARK: - Ready Stage Card
private struct ReadyStageCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassGroup {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.brandMint)

                Text("Normal Baseline: \(Int(model.baseline ?? 0)) BPM · \(Int(model.baselineBreathing ?? 16)) breaths/min")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(.white)

                Text("Your 30-second resting baseline is complete. Exercise set will now run for 1 minute. The SDK is paused during exercise.")
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)

                PrimaryButton(
                    title: "Start \(model.exerciseName) Set (1 Min)",
                    symbol: "bolt.fill",
                    tint: AppColors.brandOrange
                ) {
                    model.startExercise()
                }
            }
            .padding(AppSpacing.xl)
            .floatingGlass(radius: AppRadius.xl)
        }
    }
}

// MARK: - Exercise Set Stage Panel (SDK paused during workout)
private struct ExerciseStagePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassGroup {
            VStack(spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.brandOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Label("Exercise in Progress (1 Minute)", systemImage: "bolt.fill")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.brandOrange)
                        Text(model.exerciseName)
                            .font(AppTypography.metric(size: 32))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Time Remaining")
                            .font(AppTypography.micro)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(TimeText.clock(max(0, 60.0 - model.elapsed)))
                            .font(AppTypography.metric(size: 32))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }

                // Progress bar
                ProgressView(value: min(1.0, model.elapsed / 60.0))
                    .tint(AppColors.brandOrange)

                HStack {
                    Text("SDK measurement is paused during exercise to prevent motion errors and save sensor credits. Recovery will automatically start at 00:00.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.75))

                    Spacer()

                    Button {
                        model.finishExerciseAndStartRecovery()
                    } label: {
                        Label("Finish Exercise Early", systemImage: "arrow.right.circle.fill")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.brandOrange)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 620)
            .floatingGlass(radius: AppRadius.xxl)
        }
    }
}

// MARK: - End Session View (Afterburn Time, Pulse Recovery, Calories & Dual Photos)
private struct EndSessionView: View {
    let record: SetRecord
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassGroup {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppColors.brandMint)
                            Text("Session Complete & Recorded")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(.white)
                        }

                        Text("\(record.exerciseName) · \(record.gender ?? "User"), Age \(record.age ?? 26) · \(record.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Spacer()

                    Pill(
                        title: record.outcome.label,
                        color: record.outcome == .observed ? AppColors.brandMint : AppColors.brandOrange,
                        symbol: record.outcome == .observed ? "checkmark.circle.fill" : "info.circle"
                    )
                }

                Divider().opacity(0.3)

                // 3 Hero Recovery Metrics: Afterburn Time, Pulse Recovery, and Calories
                HStack(spacing: AppSpacing.md) {
                    heroCard(
                        title: "Afterburn Time",
                        subtitle: "Breath recovery to \(Int(record.baselineBreathing ?? 16)) bpm",
                        value: "\(Int(record.breathRecoverySeconds ?? record.recoverySeconds))s",
                        symbol: "wind",
                        tint: AppColors.brandTeal
                    )

                    heroCard(
                        title: "Pulse Recovery",
                        subtitle: "Return to baseline \(Int(record.baselineBPM)) BPM",
                        value: "\(Int(record.pulseRecoverySeconds ?? record.recoverySeconds))s",
                        symbol: "heart.fill",
                        tint: AppColors.brandMint
                    )

                    heroCard(
                        title: "Calories Burned",
                        subtitle: "EPOC afterburn: \(String(format: "%.1f", record.epocCalories ?? 0)) kcal",
                        value: "\(String(format: "%.1f", record.caloriesBurned ?? 0)) kcal",
                        symbol: "flame.fill",
                        tint: AppColors.brandOrange
                    )
                }

                Divider().opacity(0.3)

                // Dual Snapshots: Peak (>100 BPM) and Rested Normal
                SessionSnapshotsCard(
                    peakImage: record.peakSnapshotData.flatMap { NSImage(data: $0) } ?? model.peakSnapshot,
                    peakBPM: record.peakPulseBPM ?? (model.peakSnapshotPulse > 0 ? model.peakSnapshotPulse : nil),
                    restedImage: record.restedSnapshotData.flatMap { NSImage(data: $0) } ?? model.restedSnapshot,
                    restedBPM: record.finalBPM ?? record.baselineBPM
                )

                Divider().opacity(0.3)

                // Session Multi-Phase Graph
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Session Pulse Timeline", systemImage: "chart.xyaxis.line")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(.white.opacity(0.85))

                    SessionMultiPhasePulseChart(record: record)
                }

                Divider().opacity(0.3)

                // Detailed Session Statistics
                HStack(spacing: AppSpacing.lg) {
                    statPill(label: "Normal Pulse", value: "\(Int(record.baselineBPM.rounded())) BPM", color: AppColors.brandTeal)
                    statPill(label: "Normal Breath", value: "\(Int(record.baselineBreathing ?? 16)) bpm", color: AppColors.brandTeal)
                    statPill(label: "Peak Pulse", value: (record.peakPulseBPM.map { "\(Int($0.rounded())) BPM" }) ?? "—", color: AppColors.brandOrange)
                    statPill(label: "Work Duration", value: TimeText.duration(record.workSeconds), color: .white)
                    statPill(label: "Recovery Duration", value: TimeText.duration(record.recoverySeconds), color: AppColors.brandMint)
                }

                Divider().opacity(0.3)

                // Action Row
                HStack {
                    Button {
                        model.section = .history
                    } label: {
                        Label("View in Journal", systemImage: "clock.arrow.circlepath")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    PrimaryButton(
                        title: "Start Next Exercise Session",
                        symbol: "arrow.clockwise",
                        tint: AppColors.brandOrange
                    ) {
                        model.resetSession()
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 680)
            .floatingGlass(radius: AppRadius.xxl)
        }
    }

    private func heroCard(title: String, subtitle: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppTypography.microMedium)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(value)
                .font(AppTypography.metric(size: 26))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(subtitle)
                .font(AppTypography.micro)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(AppTypography.metric(size: 16))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Immersive Top Bar Subview
private struct ImmersiveTopBar: View {
    @Environment(AppModel.self) private var model
    let onShowSettings: () -> Void
    let onShowSetup: () -> Void
    let onShowVitals: () -> Void

    var body: some View {
        GlassGroup {
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                // Exercise and session status
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label(
                        model.phase == .calibrating ? "Normal Baseline Check (30s)" :
                        model.phase == .working ? "Exercise Set (60s)" :
                        model.phase == .recovering ? "Afterburn Recovery (60s)" :
                        model.phase == .result ? "Session Recorded" : "Workout Stage",
                        systemImage: model.phase == .working ? "bolt.fill" : "waveform.path.ecg"
                    )
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(.white.opacity(0.75))

                    Text(model.exerciseName.isEmpty ? "Exercise Session" : model.exerciseName)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(model.userGender)  ·  Age \(model.userAge)  ·  Automated 30s / 1m / 1m")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
                .padding(AppSpacing.md)
                .floatingGlass(radius: AppRadius.lg)

                Spacer()

                // Actions and Live Vitals Panel
                VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.xs) {
                        GlassIconButton(title: "Measurement settings", symbol: "gearshape", action: onShowSettings)

                        GlassIconButton(
                            title: model.sensor.isCameraRunning ? "Close camera" : "Open camera",
                            symbol: model.sensor.isCameraRunning ? "video.slash" : "video"
                        ) {
                            if model.sensor.isCameraRunning {
                                model.closeCamera()
                            } else {
                                model.openCamera()
                            }
                        }
                        .disabled(model.sensor.isStarting)

                        GlassIconButton(title: "Session setup", symbol: "slider.horizontal.3", action: onShowSetup)
                            .disabled(!model.isEditingAllowed)

                        GlassIconButton(
                            title: model.isStageFocused ? "Exit full screen" : "Full screen camera",
                            symbol: model.isStageFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                        ) {
                            model.isStageFocused.toggle()
                            NSApp.keyWindow?.toggleFullScreen(nil)
                        }
                    }

                    LiveVitalsPanel(showDetails: onShowVitals)
                }
            }
        }
    }
}

// MARK: - Camera Guidance Subview
private struct ImmersiveCameraGuidance: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if model.sensor.isStarting {
                ProgressView().controlSize(.large)
            } else {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(model.sensor.isStarting ? model.sensor.status : "Align in the camera guide.")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.white)

            Text("Face camera in even lighting. Normal baseline calibration begins once steady.")
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)
        .padding(AppSpacing.lg)
    }
}

// MARK: - Live Pulse Stage Panel Subview
private struct LivePulseStagePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Label(
                    model.phase == .calibrating ? "Normal Baseline Check (30s)" : "Afterburn Recovery Trend",
                    systemImage: "waveform.path.ecg"
                )
                .font(AppTypography.captionMedium)
                .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if let breath = model.latestBreathingRate {
                    Text("\(Int(breath.rounded())) bpm")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.brandTeal)
                        .padding(.trailing, AppSpacing.sm)
                }

                if let current = model.latestSample, model.readingIsValid {
                    Text("\(Int(current.bpm.rounded())) BPM")
                        .font(AppTypography.captionMedium)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.brandMint)
                }
            }

            PulseChart(
                samples: model.samples,
                baseline: model.baseline,
                policy: model.measurementSettings.policy,
                originTime: model.pulseChartOrigin,
                endTime: model.now,
                showPeriodPicker: true
            )
        }
        .padding(AppSpacing.md)
        .floatingGlass(radius: AppRadius.lg)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
    }
}

// MARK: - Immersive Control Dock Subview
private struct ImmersiveControlDock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onEndSessionRequested: () -> Void

    var body: some View {
        GlassGroup {
            VStack(spacing: AppSpacing.md) {
                // Responsive top row: Timer, Coaching, Actions
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xl) {
                        timer
                        Spacer(minLength: AppSpacing.md)
                        coaching
                        actions
                    }
                    HStack(spacing: AppSpacing.md) {
                        timer
                        Spacer()
                        actions
                    }
                }

                // Quick threshold & period controls during active measurement
                if model.phase == .calibrating || model.phase == .recovering {
                    Divider().opacity(0.3)
                    quickAdjustStrip
                }

                // Progress Bar
                if model.phase == .calibrating || model.phase == .working || model.phase == .recovering {
                    ProgressView(
                        value: model.phase == .calibrating
                            ? min(1.0, model.elapsed / AppModel.normalDuration)
                            : (model.phase == .working ? min(1.0, model.elapsed / AppModel.exerciseDuration) : min(1.0, model.elapsed / AppModel.recoveryDuration))
                    )
                    .tint(model.phase == .working ? AppColors.brandOrange : AppColors.brandMint)
                    .accessibilityLabel("Measurement progress")
                }

                // Signal status footer
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: (model.phase == .working || model.readingIsValid) ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle((model.phase == .working || model.readingIsValid) ? AppColors.brandMint : AppColors.brandOrange)
                    Text(signalText)
                        .lineLimit(2)
                    Spacer()
                    if model.phase.isActive || model.baseline != nil {
                        Button("End session", action: onEndSessionRequested)
                            .buttonStyle(.borderless)
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.brandOrange)
                    }
                }
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(AppSpacing.lg)
            .floatingGlass(radius: AppRadius.xxl)
        }
    }

    private var timer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timerLabel)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(timerText)
                .font(AppTypography.metric(size: 56))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : AppAnimation.springSnappy, value: timerText)
                .accessibilityIdentifier("workout-timer")
        }
    }

    private var coaching: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(coachingTitle)
                .font(AppTypography.cardTitle)
                .foregroundStyle(.white)

            Text(coachingDetail)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 340, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.sm) {
            if model.phase == .working {
                GlassIconButton(
                    title: model.isPaused ? "Resume set" : "Pause set",
                    symbol: model.isPaused ? "play.fill" : "pause.fill",
                    action: model.togglePause
                )
            }

            PrimaryButton(
                title: actionTitle,
                symbol: model.phase == .working ? "checkmark" : (model.phase == .result ? "arrow.clockwise" : "arrow.right"),
                tint: AppColors.brandOrange
            ) {
                if !model.sensor.isCameraRunning && (model.phase == .idle || model.phase == .interrupted) {
                    model.openCamera()
                } else if !model.apiKeyConfigured {
                    model.section = .settings
                } else if !model.resultWasSaved {
                    model.retrySaveResult()
                } else {
                    model.primaryAction()
                }
            }
            .disabled(model.isPaused)
            .accessibilityIdentifier("workout-primary")
        }
    }

    private var quickAdjustStrip: some View {
        HStack(spacing: AppSpacing.md) {
            // Confidence threshold quick-adjust
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "dial.medium")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Confidence")
                    .font(AppTypography.microMedium)
                    .foregroundStyle(.white.opacity(0.8))
                Stepper("", value: Binding(
                    get: { model.measurementSettings.policy.minimumConfidence },
                    set: { v in
                        var s = model.measurementSettings
                        s.policy.minimumConfidence = v
                        model.updateMeasurementSettings(s)
                    }
                ), in: 40...100, step: 5)
                .labelsHidden()
                .accessibilityLabel("Minimum confidence threshold")

                Text("\(Int(model.measurementSettings.policy.minimumConfidence))%")
                    .font(AppTypography.captionMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.brandTeal)
            }

            Divider().frame(height: 16).opacity(0.4)

            // Tolerance quick-adjust
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "scope")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Tolerance")
                    .font(AppTypography.microMedium)
                    .foregroundStyle(.white.opacity(0.8))
                Stepper("", value: Binding(
                    get: { model.measurementSettings.policy.toleranceBPM },
                    set: { v in
                        var s = model.measurementSettings
                        s.policy.toleranceBPM = v
                        model.updateMeasurementSettings(s)
                    }
                ), in: 1...20, step: 1)
                .labelsHidden()
                .accessibilityLabel("Baseline tolerance BPM")

                Text("±\(Int(model.measurementSettings.policy.toleranceBPM)) BPM")
                    .font(AppTypography.captionMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.brandTeal)
            }

            Spacer()

            // Period quick-pick chips
            HStack(spacing: AppSpacing.xxs) {
                ForEach(TrendPeriodPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    let selected = model.measurementSettings.trendPeriodPreset == preset
                    Button {
                        if let s = preset.seconds {
                            var settings = model.measurementSettings
                            settings.trendWindowSeconds = s
                            settings.trendPeriodPreset = preset
                            model.updateMeasurementSettings(settings)
                        }
                    } label: {
                        Text(preset.rawValue)
                            .font(AppTypography.microMedium)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(
                                selected ? AppColors.brandTeal.opacity(0.25) : Color.white.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(selected ? AppColors.brandTeal : .white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .buttonStyle(.tactile(scale: 0.95))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var timerLabel: String {
        switch model.phase {
        case .idle: return "Automated Session"
        case .calibrating: return model.hasStableMeasurementStarted ? "Normal Check Countdown (30s)" : "Aligning Silhouette"
        case .ready: return "Normal Baseline Ready"
        case .working: return "Exercise Set Remaining (60s)"
        case .recovering: return "Afterburn Recovery (60s)"
        case .result: return "Session Completed"
        default: return "Your time"
        }
    }

    private var timerText: String {
        switch model.phase {
        case .idle, .interrupted: return "00:30"
        case .calibrating:
            if !model.hasStableMeasurementStarted {
                return "00:30"
            }
            return TimeText.clock(max(0, AppModel.normalDuration - model.elapsed))
        case .ready: return "01:00"
        case .working: return TimeText.clock(max(0, AppModel.exerciseDuration - model.elapsed))
        case .recovering:
            return TimeText.clock(max(0, AppModel.recoveryDuration - model.elapsed))
        case .result:
            return TimeText.clock(model.lastResult?.recoverySeconds ?? model.elapsed)
        default: return TimeText.clock(model.elapsed)
        }
    }

    private var coachingTitle: String {
        switch model.phase {
        case .idle: return "One click, fully automated."
        case .calibrating: return model.hasStableMeasurementStarted ? "Measuring Normal Baseline (30s)" : "Align in Silhouette"
        case .ready: return "Ready for exercise set."
        case .working: return "Exercise Set: \(model.exerciseName)"
        case .recovering: return "Measuring Afterburn & Recovery"
        case .result: return "Session complete."
        default: return "Your pace, measured."
        }
    }

    private var coachingDetail: String {
        switch model.phase {
        case .idle:
            return "Automated 30s normal baseline → 60s exercise (SDK paused) → 60s recovery. Tap Start to begin."
        case .calibrating:
            if !model.hasStableMeasurementStarted {
                return "Align face & chest inside silhouette. 30-second countdown will start once steady."
            }
            return "Hold still. Calibrating resting pulse and breathing rate (\(Int(min(30, model.elapsed)))/30s)."
        case .ready:
            return "Normal baseline confirmed at \(Int(model.baseline ?? 0)) BPM. Exercise set starts automatically."
        case .working:
            return "SDK paused to prevent motion errors. Give this set your best effort! Advances automatically at 00:00."
        case .recovering:
            return "Sit facing camera. Measuring breath recovery time (Afterburn), pulse recovery, and energy burned."
        case .result:
            return "Afterburn time, pulse recovery, and calories recorded in Journal. Tap Start Next Session to continue."
        default:
            return "Continuous camera session active."
        }
    }

    private var actionTitle: String {
        if !model.sensor.isCameraRunning && (model.phase == .idle || model.phase == .interrupted) { return "Open camera" }
        if !model.apiKeyConfigured { return "Add SmartSpectra key" }
        if !model.resultWasSaved { return "Retry saving" }
        return model.primaryTitle
    }

    private var signalText: String {
        if model.phase == .working {
            return "Exercise set in progress · SDK paused for movement · 60s timer active"
        }
        if model.sensor.isStarting || !model.sensor.isRunning || !model.sensor.validationOK {
            return model.sensor.feedback(at: model.now)
        }
        if !model.hasFreshSample {
            return "Waiting for fresh measured pulse. Keep still and face camera."
        }
        if !model.hasStableMeasurementStarted && (model.phase == .calibrating || model.phase == .recovering) {
            return "Align head & chest in silhouette. Timer begins automatically once reading stabilizes."
        }
        return model.readingIsValid
            ? "Stable signal. \(Int(model.latestSample?.confidence ?? 0))% confidence."
            : model.sensor.validationHint
    }
}

// MARK: - Confetti Overlay
private struct ConfettiOverlay: View {
    @State private var falling = false

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<44, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill([AppColors.brandOrange, Color.pink, AppColors.brandMint, Color.yellow, Color.cyan][index % 5])
                    .frame(width: 6, height: 11)
                    .rotationEffect(.degrees(falling ? Double(index * 37) : 0))
                    .position(
                        x: geometry.size.width * CGFloat((index * 23) % 100) / 100,
                        y: falling ? geometry.size.height + 30 : -30
                    )
                    .opacity(falling ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.4).delay(Double(index % 8) * 0.06),
                        value: falling
                    )
            }
        }
        .onAppear {
            falling = true
        }
        .accessibilityHidden(true)
    }
}
