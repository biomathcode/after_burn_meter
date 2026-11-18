import SwiftUI

struct MeasurementSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var savedFlash = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header row with flash indicator
            HStack {
                Label("Measurement & trend", systemImage: "slider.horizontal.3")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                if savedFlash {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.brandTeal)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            Text("Changes apply immediately during a live check without restarting the timer or discarding recorded data.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // ── SDK Operation Mode ─────────────────────────────────────────
            GroupBox {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Picker("Operation Mode", selection: Binding(
                        get: { model.measurementSettings.sdkOperationMode },
                        set: { newMode in
                            var s = model.measurementSettings
                            s.sdkOperationMode = newMode
                            model.updateMeasurementSettings(s)
                            flashSaved()
                        }
                    )) {
                        ForEach(SDKOperationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(model.measurementSettings.sdkOperationMode.summary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, AppSpacing.xs)
            } label: {
                Label("SDK Operation Mode", systemImage: "sparkles")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.ink)
            }

            // ── Detection thresholds ──────────────────────────────────────
            GroupBox {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    sliderControl(
                        "Signal confidence threshold",
                        note: "Readings below this confidence are excluded from trend and recovery detection.",
                        path: \.minimumConfidence,
                        range: 40...100, step: 5, unit: "%",
                        id: "confidence-threshold"
                    )
                    Divider().opacity(0.6)
                    sliderControl(
                        "Near-baseline tolerance",
                        note: "How close to baseline (± BPM) counts as recovered.",
                        path: \.toleranceBPM,
                        range: 1...20, step: 1, unit: "BPM",
                        id: "baseline-tolerance"
                    )
                }
                .padding(.vertical, AppSpacing.xs)
            } label: {
                Label("Detection thresholds", systemImage: "dial.medium")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.ink)
            }

            // ── Collection periods ────────────────────────────────────────
            GroupBox {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    stepperControl("Warm-up",                path: \.warmupSeconds,       range: 12...120, unit: "s", id: "warmup-period")
                    stepperControl("Baseline collection",    path: \.baselineSeconds,     range: 5...300, step: 5, unit: "s", id: "baseline-period")
                    stepperControl("Near-baseline evidence", path: \.confirmationSeconds, range: 1...120, unit: "s", id: "confirmation-period")
                    stepperControl("Maximum evidence gap",   path: \.maximumSampleGap,    range: 1...15, unit: "s", id: "evidence-gap")
                }
                .padding(.vertical, AppSpacing.xs)
            } label: {
                Label("Collection periods", systemImage: "timer")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.ink)
            }

            // ── Graph time window ─────────────────────────────────────────
            GroupBox {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Choose how much elapsed time the graph shows. Narrowing the window never discards data — it only adjusts the visible range and regression calculation.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TrendPeriodPicker()
                }
                .padding(.vertical, AppSpacing.xs)
            } label: {
                Label("Graph time window", systemImage: "chart.xyaxis.line")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.ink)
            }

            Text("The baseline clock runs through poor signal. Recovery accumulates valid near-baseline intervals; gaps preserve collected evidence. Linear regression summarises filtered samples at their actual elapsed times.")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Saved automatically on this Mac")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
                Spacer()
                Button("Restore defaults") {
                    model.updateMeasurementSettings(MeasurementSettings())
                    flashSaved()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onChange(of: model.measurementSettings) { _, _ in flashSaved() }
    }

    // MARK: - Slider control (threshold-style)
    @ViewBuilder
    private func sliderControl(
        _ title: String, note: String,
        path: WritableKeyPath<RecoveryPolicy, Double>,
        range: ClosedRange<Double>, step: Double = 1, unit: String, id: String
    ) -> some View {
        let binding = Binding<Double>(
            get: { model.measurementSettings.policy[keyPath: path] },
            set: { value in
                var settings = model.measurementSettings
                let snapped = (value / step).rounded() * step
                settings.policy[keyPath: path] = snapped
                model.updateMeasurementSettings(settings)
            }
        )
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("\(Int(binding.wrappedValue)) \(unit)")
                    .font(AppTypography.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.brandTeal)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            Slider(value: binding, in: range, step: step)
                .accessibilityIdentifier(id)
                .accessibilityLabel(title)
                .tint(AppColors.brandTeal)
            HStack {
                Text("\(Int(range.lowerBound))\(unit)")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
                Spacer()
                Text(note)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 240)
            }
        }
    }

    // MARK: - Stepper control (period-style)
    @ViewBuilder
    private func stepperControl(
        _ title: String,
        path: WritableKeyPath<RecoveryPolicy, Double>,
        range: ClosedRange<Double>, step: Double = 1, unit: String, id: String
    ) -> some View {
        Stepper(value: Binding(
            get: { model.measurementSettings.policy[keyPath: path] },
            set: { value in
                var settings = model.measurementSettings
                settings.policy[keyPath: path] = value
                model.updateMeasurementSettings(settings)
            }
        ), in: range, step: step) {
            HStack {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("\(Int(model.measurementSettings.policy[keyPath: path])) \(unit)")
                    .font(AppTypography.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.brandTeal)
                    .frame(minWidth: 70, alignment: .trailing)
            }
        }
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
    }

    private func flashSaved() {
        guard !savedFlash else { return }
        withAnimation(AppAnimation.springSnappy) { savedFlash = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(AppAnimation.smooth) { savedFlash = false }
        }
    }
}

// MARK: - Trend period chip picker
struct TrendPeriodPicker: View {
    @Environment(AppModel.self) private var model
    @State private var customText = ""
    @FocusState private var customFocused: Bool

    private var current: TrendPeriodPreset { model.measurementSettings.trendPeriodPreset }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(TrendPeriodPreset.allCases, id: \.self) { preset in
                    periodChip(preset)
                }
            }
            if current == .custom {
                HStack(spacing: AppSpacing.xs) {
                    TextField("Seconds (10–300)", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                        .focused($customFocused)
                        .onSubmit { applyCustom() }
                        .accessibilityIdentifier("trend-period-custom")
                        .accessibilityLabel("Custom seconds")

                    Button("Apply") { applyCustom() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(parsedCustom == nil)

                    Text("Current: \(Int(model.measurementSettings.trendWindowSeconds))s")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
                .onAppear {
                    customText = "\(Int(model.measurementSettings.trendWindowSeconds))"
                    customFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private func periodChip(_ preset: TrendPeriodPreset) -> some View {
        let selected = current == preset
        Button {
            if preset == .custom {
                applyPreset(preset, seconds: model.measurementSettings.trendWindowSeconds)
            } else if let s = preset.seconds {
                applyPreset(preset, seconds: s)
            }
        } label: {
            Text(preset.rawValue)
                .font(AppTypography.captionMedium)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs + 2)
                .background(
                    selected ? AppColors.brandTeal.opacity(0.18) : AppColors.subtleFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? AppColors.brandTeal.opacity(0.35) : AppColors.border, lineWidth: 1)
                )
                .foregroundStyle(selected ? AppColors.brandTeal : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .buttonStyle(.tactile(scale: 0.96))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var parsedCustom: Double? {
        guard let v = Double(customText.trimmingCharacters(in: .whitespaces)),
              v >= 10, v <= 300 else { return nil }
        return v
    }

    private func applyCustom() {
        guard let v = parsedCustom else { return }
        applyPreset(.custom, seconds: v)
    }

    private func applyPreset(_ preset: TrendPeriodPreset, seconds: Double) {
        var settings = model.measurementSettings
        settings.trendWindowSeconds = seconds
        settings.trendPeriodPreset = preset
        model.updateMeasurementSettings(settings)
    }
}

// MARK: - Measurement Settings Sheet Container
struct MeasurementSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                MeasurementSettingsView()
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.ink)
                    .controlSize(.regular)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(AppSpacing.xxl)
        }
        .frame(minWidth: 540, idealWidth: 600)
        .frame(minHeight: 520)
        .background(AppColors.background)
    }
}
