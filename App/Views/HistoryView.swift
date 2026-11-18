import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRecord: SetRecord?

    private var records: [SetRecord] { model.records }
    private var observed: [SetRecord] { records.filter { $0.outcome == .observed } }
    private var average: Double? {
        observed.isEmpty ? nil : observed.reduce(0) { $0 + $1.recoverySeconds } / Double(observed.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // Top Header with Export button
                PageHeader(
                    title: "Get to know your recovery.",
                    subtitle: "A record of your sets and the moments in between."
                ) {
                    Button {
                        model.exportHistory()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.records.isEmpty)
                }

                // Summary Statistics Grid (Responsive)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 360), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                    StatCard(title: "Sets recorded", value: "\(records.count)", symbol: "checklist", tint: AppColors.brandTeal)
                    StatCard(title: "Observed intervals", value: "\(observed.count)", symbol: "waveform.path.ecg", tint: AppColors.brandTeal)
                    StatCard(title: "Average observed interval", value: average.map(TimeText.duration) ?? "—", symbol: "clock", tint: AppColors.brandOrange)
                }

                // Observations Section
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Your observations")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.ink)

                    if records.isEmpty {
                        Panel(padding: AppSpacing.xxl) {
                            VStack(spacing: AppSpacing.lg) {
                                EmptyState(
                                    symbol: "chart.xyaxis.line",
                                    title: "Your story starts with a set.",
                                    detail: "Complete a camera-based session to record your first recovery observation."
                                )
                                Button("Go to workout") {
                                    model.section = .workout
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.brandTeal)
                                .controlSize(.regular)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(records) { record in
                                HistoryRecordRow(record: record) {
                                    selectedRecord = record
                                }
                            }
                        }
                    }
                }

                // Disclaimer footnote
                Text("These intervals include sensor warm-up and confirmation time. They are observations of pulse, not measures of muscle recovery or fitness clearance.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
            }
            .padding(AppSpacing.xxl)
            .frame(maxWidth: 1050, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
        }
    }
}

// MARK: - Dedicated History Record Row
private struct HistoryRecordRow: View {
    let record: SetRecord
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
                HStack(spacing: AppSpacing.md) {
                    // Thumbnail if snapshot available, else waveform icon
                    if let data = record.peakSnapshotData ?? record.restedSnapshotData,
                       let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipped()
                            .cornerRadius(AppRadius.sm)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.brandTeal)
                            .frame(width: 44, height: 44)
                            .background(AppColors.brandTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(record.exerciseName)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.ink)

                        HStack(spacing: AppSpacing.xs) {
                            Text(record.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            if let g = record.gender, let a = record.age {
                                Text("·")
                                Text("\(g), \(a) yrs")
                            }
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                    }

                    Spacer()

                    if let peak = record.peakPulseBPM, peak >= 100 {
                        Pill(
                            title: "Peak \(Int(peak.rounded())) BPM",
                            color: AppColors.brandOrange,
                            symbol: "bolt.heart.fill"
                        )
                    }

                    Pill(
                        title: record.outcome.label,
                        color: record.outcome == .observed ? AppColors.brandTeal : AppColors.secondary,
                        symbol: record.outcome == .observed ? "checkmark.circle.fill" : "info.circle"
                    )

                    VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                        Text(TimeText.duration(record.recoverySeconds))
                            .font(AppTypography.metric(size: 20))
                            .foregroundStyle(AppColors.ink)
                            .monospacedDigit()
                        Text("recovery")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.secondary)
                    }
                    .frame(minWidth: 80, alignment: .trailing)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.secondary.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(.tactile(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.exerciseName), \(record.outcome.label), duration \(TimeText.duration(record.recoverySeconds))")
    }
}

// MARK: - Dedicated Record Detail View
struct RecordDetailView: View {
    let record: SetRecord
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                PageHeader(
                    title: record.exerciseName,
                    subtitle: "\(record.gender ?? "User"), Age \(record.age ?? 28) · \(record.date.formatted(date: .abbreviated, time: .shortened))"
                ) {
                    Pill(
                        title: record.outcome.label,
                        color: record.outcome == .observed ? AppColors.brandTeal : AppColors.secondary,
                        symbol: record.outcome == .observed ? "checkmark.circle.fill" : "info.circle"
                    )
                }

                // 3 Hero Recovery Metrics: Afterburn Time, Pulse Recovery, and Calories
                HStack(spacing: AppSpacing.md) {
                    heroCard(
                        title: "Afterburn Time",
                        subtitle: "Breath recovery to baseline",
                        value: "\(Int(record.breathRecoverySeconds ?? record.recoverySeconds))s",
                        symbol: "wind",
                        tint: AppColors.brandTeal
                    )

                    heroCard(
                        title: "Pulse Recovery",
                        subtitle: "Return to resting heart rate",
                        value: "\(Int(record.pulseRecoverySeconds ?? record.recoverySeconds))s",
                        symbol: "heart.fill",
                        tint: AppColors.brandMint
                    )

                    heroCard(
                        title: "Calories Burned",
                        subtitle: "Active + EPOC afterburn",
                        value: (record.caloriesBurned.map { "\(String(format: "%.1f", $0)) kcal" }) ?? "—",
                        symbol: "flame.fill",
                        tint: AppColors.brandOrange
                    )
                }

                // Key metric badges
                HStack(spacing: AppSpacing.md) {
                    detailMetric("Normal Pulse", "\(Int(record.baselineBPM.rounded())) BPM")
                    detailMetric("Normal Breath", record.baselineBreathing.map { "\(Int($0.rounded())) bpm" } ?? "—")
                    detailMetric("Peak Pulse", (record.peakPulseBPM.map { "\(Int($0.rounded())) BPM" }) ?? "—")
                    detailMetric("Work Duration", TimeText.duration(record.workSeconds))
                    detailMetric("Recovery Duration", TimeText.duration(record.recoverySeconds))
                }
                .padding(AppSpacing.md)
                .background(AppColors.subtleFill, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                Divider().opacity(0.6)

                // Dual Snapshots: Peak (>100 BPM) and Rested
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Automated Photo Snapshots")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.ink)

                    SessionSnapshotsCard(
                        peakImage: record.peakSnapshotData.flatMap { NSImage(data: $0) },
                        peakBPM: record.peakPulseBPM,
                        restedImage: record.restedSnapshotData.flatMap { NSImage(data: $0) },
                        restedBPM: record.finalBPM ?? record.baselineBPM
                    )
                }

                Divider().opacity(0.6)

                // Multi-Phase Pulse Chart
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Session Pulse Timeline")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.ink)

                    SessionMultiPhasePulseChart(record: record)
                }

                Divider().opacity(0.6)

                // Summary
                AnalysisSummaryView(record: record)

                // Explanatory footnotes
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("1-Minute session baseline: \(Int(record.baselineBPM.rounded())) BPM. Qualification required \(Int(record.policy.confirmationSeconds)) \(record.policy.algorithmVersion >= 2 ? "accumulated" : "continuous") valid seconds within \(Int(record.policy.toleranceBPM)) BPM of baseline, at \(Int(record.policy.minimumConfidence))% confidence.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineSpacing(3)

                    if record.hadMeasurementGaps {
                        Label("Measurement gaps occurred. The interval includes time without a usable signal.", systemImage: "exclamationmark.circle")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.brandOrange)
                    }

                    Text("Recorded with SmartSpectra \(record.sdkVersion). The return to baseline is approximate because pulse is averaged over a measurement window.")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.secondary)
                        .lineSpacing(2)
                }

                Spacer(minLength: AppSpacing.sm)

                // Footer action
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.ink)
                    .controlSize(.regular)
                }
            }
            .padding(AppSpacing.xl)
            .frame(minWidth: 620, idealWidth: 700)
            .foregroundStyle(AppColors.ink)
        }
        .background(AppColors.background)
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
            Text(value)
                .font(AppTypography.metric(size: 16))
                .foregroundStyle(AppColors.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroCard(title: String, subtitle: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppTypography.microMedium)
                    .foregroundStyle(AppColors.ink)
            }
            Text(value)
                .font(AppTypography.metric(size: 24))
                .foregroundStyle(AppColors.ink)
                .monospacedDigit()
            Text(subtitle)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.secondary)
                .lineLimit(1)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.subtleFill, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }
}
