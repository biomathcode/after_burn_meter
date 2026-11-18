import SwiftUI

struct WorkoutSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PageHeader(
                title: "Session Configuration",
                subtitle: "Set up your participant demographics, exercise, and camera device."
            ) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            // Camera selector
            Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.brandTeal)
                        .frame(width: 36, height: 36)
                        .background(AppColors.brandTeal.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Camera Device")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.ink)
                        Text(model.sensor.isCameraRunning ? "Camera stream running" : "Camera off")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                    }

                    Spacer()

                    Picker("Camera", selection: Bindable(model.sensor).selectedCameraID) {
                        Text("System default").tag("")
                        ForEach(model.sensor.cameras, id: \.identifier) { camera in
                            Text(camera.name).tag(camera.identifier)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Select Camera")
                }
            }

            // Participant Demographics
            Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Participant Demographics")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.ink)

                    HStack(spacing: AppSpacing.xl) {
                        // Gender
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Gender")
                                .font(AppTypography.captionMedium)
                                .foregroundStyle(AppColors.secondary)

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
                                                selected ? AppColors.brandTeal.opacity(0.18) : AppColors.subtleFill,
                                                in: Capsule()
                                            )
                                            .overlay(
                                                Capsule().stroke(selected ? AppColors.brandTeal : AppColors.border, lineWidth: 1)
                                            )
                                            .foregroundStyle(selected ? AppColors.brandTeal : AppColors.ink)
                                    }
                                    .buttonStyle(.plain)
                                    .buttonStyle(.tactile(scale: 0.96))
                                }
                            }
                        }

                        Divider().frame(height: 40)

                        // Age
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Age")
                                .font(AppTypography.captionMedium)
                                .foregroundStyle(AppColors.secondary)

                            HStack(spacing: AppSpacing.xs) {
                                Button {
                                    if model.userAge > 10 { model.userAge -= 1 }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(AppColors.ink)
                                }
                                .buttonStyle(.plain)

                                Text("\(model.userAge) yrs")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.ink)
                                    .monospacedDigit()
                                    .frame(minWidth: 50, alignment: .center)

                                Button {
                                    if model.userAge < 100 { model.userAge += 1 }
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(AppColors.ink)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Exercise Selection
            Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Exercise to be performed")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.ink)

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
                                            selected ? AppColors.brandOrange.opacity(0.18) : AppColors.subtleFill,
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().stroke(selected ? AppColors.brandOrange : AppColors.border, lineWidth: 1)
                                        )
                                        .foregroundStyle(selected ? AppColors.brandOrange : AppColors.ink)
                                }
                                .buttonStyle(.plain)
                                .buttonStyle(.tactile(scale: 0.96))
                            }
                        }
                    }

                    TextField("Or enter custom exercise name...", text: Bindable(model).exerciseName)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.body)
                }
            }

            Spacer(minLength: AppSpacing.sm)

            // Bottom action row
            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                if model.apiKeyConfigured {
                    PrimaryButton(title: "Begin 1-Min Normal Check", symbol: "camera", tint: AppColors.brandOrange) {
                        dismiss()
                        model.startBaseline()
                    }
                } else {
                    PrimaryButton(title: "Configure SmartSpectra Key", symbol: "gearshape", tint: AppColors.brandTeal) {
                        model.section = .settings
                        dismiss()
                    }
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(minWidth: 620, idealWidth: 680)
        .background(AppColors.background)
        .task {
            model.sensor.refreshCameras()
        }
    }
}

// MARK: - Analysis Summary Subview
struct AnalysisSummaryView: View {
    let record: SetRecord
    private var analysis: RecoveryAnalysis { RecoveryAnalysis(record: record) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Measured recovery analysis", systemImage: "chart.xyaxis.line")
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: AppSpacing.md)], spacing: AppSpacing.sm) {
                metric("Median pulse", analysis.medianPulse.map { "\(Int($0.rounded())) BPM" } ?? "—")
                metric("Peak valid pulse", analysis.peakPulse.map { "\(Int($0.rounded())) BPM" } ?? "—")
                metric("Signal coverage", "\(Int((analysis.signalCoverage * 100).rounded()))%")
                metric("Valid samples", "\(analysis.validSampleCount) / \(analysis.totalSampleCount)")
            }

            Text(analysis.observedReturn
                 ? "A sustained return near your session baseline was observed. The interval includes warm-up and confirmation time."
                 : "A sustained return near baseline was not confirmed in this interval. Missing or excluded readings do not establish recovery.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .lineSpacing(2)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .lineLimit(1)
            Text(value)
                .font(AppTypography.metric(size: 18))
                .foregroundStyle(AppColors.ink)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
