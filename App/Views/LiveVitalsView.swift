import SwiftUI
import Charts

// MARK: - Compact Live Vitals Stage Floating Panel
struct LiveVitalsPanel: View {
    @Environment(AppModel.self) private var model
    var showDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label("Live vitals", systemImage: "waveform.path.ecg")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.secondary)
                Spacer()
                Button("All vitals", action: showDetails)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.brandTeal)
                    .buttonStyle(.borderless)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: AppSpacing.md) {
                ForEach([VitalKind.pulse, .breathing, .rmssd, .eda], id: \.self) { kind in
                    VitalValue(kind: kind, compact: true)
                }
            }

            Text(model.baseline.map { "Session baseline \(Int($0.rounded())) BPM" } ?? "Baseline not measured")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.secondary)
        }
        .padding(AppSpacing.md)
        .frame(width: 310)
        .floatingGlass(radius: AppRadius.xl)
    }
}

// MARK: - Full Live Vitals Sheet
struct LiveVitalsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                PageHeader(
                    title: "Your rhythm, in view.",
                    subtitle: "Live measurements from SmartSpectra \(model.sensor.sdkVersion)"
                )
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .tint(AppColors.ink)
                .controlSize(.regular)
            }
            .padding(AppSpacing.xl)

            Divider().opacity(0.6)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Camera Framing & Session Status
                    HStack(alignment: .top, spacing: AppSpacing.xl) {
                        if let frame = model.sensor.frame {
                            Image(nsImage: frame)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 280)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                        .strokeBorder(AppColors.borderHighlight.opacity(0.3), lineWidth: 1)
                                )
                                .accessibilityLabel("Live camera framing")
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Label(
                                model.sensor.isRunning ? "Measurement running" : "Measurement stopped",
                                systemImage: model.sensor.isRunning ? "waveform.path.ecg" : "pause.circle"
                            )
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(model.sensor.isRunning ? AppColors.brandTeal : AppColors.secondary)

                            Text(model.sensor.feedback(at: model.now))
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Sit still with your face and chest evenly lit. Keep the camera on a stable surface. HRV needs at least 60 seconds.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondary)

                            HStack(spacing: AppSpacing.md) {
                                if model.sensor.isRunning || model.sensor.isStarting {
                                    Button("Stop measurement") {
                                        model.closeCamera()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                } else {
                                    PrimaryButton(title: "Start measurement", symbol: "waveform.path.ecg", tint: AppColors.brandTeal) {
                                        model.startBaseline()
                                    }
                                    .disabled(!model.apiKeyConfigured || model.plan.isEmpty || model.phase.isActive)
                                }

                                Text("\(Int(model.sensor.measurementElapsed(at: model.now)))s captured")
                                    .font(AppTypography.captionMedium)
                                    .monospacedDigit()
                                    .foregroundStyle(AppColors.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Recorded Pulse Chart Panel
                    Panel(padding: AppSpacing.md, cornerRadius: AppRadius.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text("Pulse over recorded time")
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.ink)
                                Spacer()
                                Text("\(Int(model.measurementSettings.trendWindowSeconds))s window")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondary)
                            }

                            PulseChart(
                                samples: model.samples,
                                baseline: model.baseline,
                                policy: model.engine.policy,
                                originTime: model.pulseChartOrigin,
                                windowSeconds: model.measurementSettings.trendWindowSeconds,
                                endTime: model.sensor.isRunning ? model.now : nil
                            )
                        }
                    }

                    // Detailed Vitals Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 360), alignment: .top)], spacing: AppSpacing.md) {
                        ForEach(VitalKind.allCases, id: \.self) { kind in
                            Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    VitalValue(kind: kind)
                                    VitalTrace(kind: kind)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // Clinical & Regulatory Disclaimer
                    Text("Arterial and breathing traces use relative units. The arterial waveform is not a calibrated blood-pressure reading. EDA is a camera-derived proxy. Additional vitals stay in this live view; the recovery journal continues to use measured pulse only.")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    SDKDiagnosticsView()
                }
                .padding(AppSpacing.xl)
            }
        }
        .frame(minWidth: 860, idealWidth: 1040, minHeight: 680, idealHeight: 820)
        .background(AppColors.background)
    }
}

// MARK: - Vital Value Display
private struct VitalValue: View {
    @Environment(AppModel.self) private var model
    let kind: VitalKind
    var compact = false

    private var elapsed: Double { model.sensor.measurementElapsed(at: model.now) }
    private var reliable: Bool {
        model.sensor.isRunning && model.sensor.vitals.isReliable(kind, at: model.now,
            elapsed: elapsed, validationOK: model.sensor.validationOK)
    }
    private var point: VitalPoint? { model.sensor.vitals.fresh(kind, at: model.now) }
    private var quality: String {
        guard model.sensor.isRunning else { return "During camera checks" }
        if elapsed < kind.warmupSeconds { return "Collecting · \(Int(ceil(kind.warmupSeconds - elapsed)))s" }
        guard let point else {
            return model.sensor.vitals.history[kind] == nil ? "Not reported yet" : "Signal paused"
        }
        if !kind.acceptsValue(point.value) { return "Outside supported range" }
        if !model.sensor.validationOK { return "Adjust framing or light" }
        if !point.stable { return "Signal settling" }
        if let confidence = point.confidence {
            return "\(Int(confidence.rounded()))% confidence"
        }
        return reliable ? "Stable signal" : "Signal settling"
    }
    private var number: String {
        guard reliable, let point else { return "—" }
        if kind.isWaveform { return String(format: "%+.3f", point.value) }
        return String(format: kind == .breathing ? "%.1f" : "%.0f", point.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : AppSpacing.xxs) {
            Text(kind.title)
                .font(compact ? AppTypography.microMedium : AppTypography.captionMedium)
                .foregroundStyle(AppColors.secondary)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                Text(number)
                    .font(AppTypography.metric(size: compact ? 26 : 34))
                    .foregroundStyle(AppColors.ink)
                    .monospacedDigit()
                    .accessibilityIdentifier("vital-\(kind.rawValue)")

                if !compact || !kind.isWaveform {
                    Text(kind.unit)
                        .font(AppTypography.microMedium)
                        .foregroundStyle(AppColors.secondary)
                }
            }

            Text(quality)
                .font(AppTypography.micro)
                .foregroundStyle(reliable ? AppColors.brandMint : AppColors.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Vital Trace Line Graph
private struct VitalTrace: View {
    @Environment(AppModel.self) private var model
    let kind: VitalKind
    private var points: [VitalPoint] { model.sensor.vitals.history[kind] ?? [] }

    var body: some View {
        if points.count > 1 {
            Chart(points, id: \.seconds) { point in
                LineMark(
                    x: .value("Time", point.seconds),
                    y: .value(kind.title, point.value),
                    series: .value("Continuous segment", point.segment)
                )
                .foregroundStyle(kind == .pulse || kind == .arterial ? AppColors.brandOrange : AppColors.brandTeal)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 60)
            .accessibilityLabel("\(kind.title), measured signal history")

            Text("Measured signal · gaps stay empty")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.secondary)
        } else {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(AppColors.subtleFill)
                .frame(height: 60)
                .overlay(
                    Text("Waiting for measured samples")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.secondary)
                )
        }
    }
}

// MARK: - SDK Diagnostics Subview
struct SDKDiagnosticsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("SDK signal check", systemImage: "checklist")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.ink)

                Text(model.sensor.hasValidation ? model.sensor.validationHint : "No validation feedback received yet.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.lg) {
                    Text("\(model.sensor.acceptedFrames) frames accepted")
                    Text("\(model.sensor.blockedFrames) blocked")
                    Text("\(model.sensor.metricPackets) metric packets")
                    Text("\(model.sensor.pulseSamplesReceived) pulse samples")
                }
                .font(AppTypography.microMedium)
                .monospacedDigit()
                .foregroundStyle(AppColors.secondary)

                Text("Processing: \(model.sensor.processingStatus)")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)

                if model.sensor.isRunning && model.sensor.measurementElapsed(at: model.now) >= 20 && model.sensor.pulseSamplesReceived == 0 {
                    Text("No pulse samples have arrived. Use the SDK guidance above; if other vitals work, check that your API key includes cardio access. A running camera alone does not confirm pulse measurement.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.brandOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
