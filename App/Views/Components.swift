import SwiftUI
import Charts

// MARK: - Legacy Palette Bridge (Backed by dynamic AppColors tokens)
public enum Palette {
    public static let ink = AppColors.ink
    public static let secondary = AppColors.secondary
    public static let background = AppColors.background
    public static let sidebar = AppColors.secondaryBackground
    public static let line = AppColors.border
    public static let teal = AppColors.brandTeal
    public static let orange = AppColors.brandOrange
    public static let camera = AppColors.cameraSlate
}

// MARK: - Reusable Page Header
public struct PageHeader<Actions: View>: View {
    public let title: String
    public var subtitle: String? = nil
    @ViewBuilder public var actions: Actions

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                headerText
                Spacer(minLength: AppSpacing.sm)
                actions
            }
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                headerText
                actions
            }
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.ink)
                .tracking(-0.3)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Unified Panel / Card Container
public struct Panel<Content: View>: View {
    public var padding: CGFloat = AppSpacing.lg
    public var cornerRadius: CGFloat = AppRadius.lg
    @ViewBuilder public var content: Content

    public init(padding: CGFloat = AppSpacing.lg, cornerRadius: CGFloat = AppRadius.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.cardSurface)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Reusable Stat / Metric Card
public struct StatCard: View {
    public let title: String
    public let value: String
    public var symbol: String? = nil
    public var tint: Color = AppColors.brandTeal

    public init(title: String, value: String, symbol: String? = nil, tint: Color = AppColors.brandTeal) {
        self.title = title
        self.value = value
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        Panel(padding: AppSpacing.md, cornerRadius: AppRadius.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let symbol {
                    HStack {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 28, height: 28)
                            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))
                        Spacer()
                    }
                }
                Text(value)
                    .font(AppTypography.metric(size: 26))
                    .foregroundStyle(AppColors.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Accessible Pill / Badge
public struct Pill: View {
    public let title: String
    public var color: Color = AppColors.brandTeal
    public var symbol: String? = nil

    public init(title: String, color: Color = AppColors.brandTeal, symbol: String? = nil) {
        self.title = title
        self.color = color
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
        }
        .font(AppTypography.microMedium)
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.xs + 2)
        .padding(.vertical, AppSpacing.xxs + 1)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Primary Action Button
public struct PrimaryButton: View {
    public let title: String
    public var symbol = "arrow.right"
    public var tint: Color = AppColors.ink
    public var action: () -> Void

    public init(title: String, symbol: String = "arrow.right", tint: Color = AppColors.ink, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        if #available(macOS 26, *) {
            button
                .buttonStyle(.glassProminent)
                .tint(tint)
                .controlSize(.large)
                .buttonStyle(.tactile(scale: 0.97))
        } else {
            button
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .controlSize(.large)
                .buttonStyle(.tactile(scale: 0.97))
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(AppTypography.bodyMedium)
                .frame(minHeight: 28)
                .padding(.horizontal, AppSpacing.xs)
        }
    }
}

// MARK: - Empty State Pattern
public struct EmptyState: View {
    public let symbol: String
    public let title: String
    public let detail: String

    public init(symbol: String, title: String, detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(AppColors.brandTeal)
                .frame(width: 72, height: 72)
                .background(AppColors.brandTeal.opacity(0.08), in: Circle())
            VStack(spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .lineSpacing(2)
            }
        }
        .padding(AppSpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pulse Chart
public struct PulseChart: View {
    public var samples: [PulseSample]
    public var baseline: Double?
    public var policy: RecoveryPolicy
    public var originTime: Double? = nil
    public var windowSeconds: Double? = nil
    public var endTime: Double? = nil
    public var showPeriodPicker: Bool = false

    @Environment(AppModel.self) private var model

    public init(
        samples: [PulseSample],
        baseline: Double? = nil,
        policy: RecoveryPolicy,
        originTime: Double? = nil,
        windowSeconds: Double? = nil,
        endTime: Double? = nil,
        showPeriodPicker: Bool = false
    ) {
        self.samples = samples
        self.baseline = baseline
        self.policy = policy
        self.originTime = originTime
        self.windowSeconds = windowSeconds
        self.endTime = endTime
        self.showPeriodPicker = showPeriodPicker
    }

    private var origin: Double { originTime ?? samples.first?.seconds ?? 0 }
    private var ending: Double { endTime ?? samples.last?.seconds ?? origin }
    private var effectiveWindow: Double? {
        showPeriodPicker ? model.measurementSettings.trendWindowSeconds : windowSeconds
    }
    private var visible: [PulseSample] {
        samples.filter { sample in
            sample.seconds.isFinite && sample.bpm.isFinite &&
            (effectiveWindow.map { window in sample.seconds >= ending - window } ?? true)
        }
    }
    private var trend: PulseRegression? { PulseRegression(samples: visible, policy: policy) }
    private var domain: ClosedRange<Double> {
        let values = visible.map(\.bpm) + (baseline.map { [$0] } ?? [])
        return max(35, (values.min() ?? 60) - 10)...max(100, (values.max() ?? 90) + 10)
    }
    private var trendColor: Color {
        guard let r2 = trend?.rSquared else { return .pink }
        return r2 >= 0.5 ? AppColors.brandTeal : AppColors.brandOrange
    }

    public var body: some View {
        if visible.isEmpty {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AppColors.secondary)
                Text("Your pulse trend will appear here.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Period picker strip
                if showPeriodPicker {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(TrendPeriodPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                            inlinePeriodChip(preset)
                        }
                        Spacer()
                        if let w = effectiveWindow {
                            Text("Last \(Int(w))s")
                                .font(AppTypography.microMedium)
                                .foregroundStyle(AppColors.secondary)
                        }
                    }
                }

                Chart {
                    if let baseline {
                        RuleMark(y: .value("Baseline", baseline))
                            .foregroundStyle(AppColors.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Baseline \(Int(baseline.rounded()))")
                                    .font(AppTypography.microMedium)
                                    .foregroundStyle(AppColors.secondary)
                            }
                    }
                    ForEach(visible) { sample in
                        PointMark(x: .value("Seconds", sample.seconds - origin), y: .value("Pulse", sample.bpm))
                            .symbolSize(12)
                            .foregroundStyle(policy.accepts(sample) ? AppColors.brandTeal : AppColors.brandOrange.opacity(0.7))
                    }
                    if let trend {
                        ForEach([trend.start, trend.end], id: \.self) { seconds in
                            LineMark(x: .value("Seconds", seconds - origin),
                                     y: .value("Fitted pulse", trend.value(at: seconds)))
                                .foregroundStyle(trendColor)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                    }
                }
                .chartXScale(domain: max(0, effectiveWindow.map { ending - $0 - origin } ?? 0)...max(1, ending - origin))
                .chartYScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text("\(Int(seconds))s").font(AppTypography.micro)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel().font(AppTypography.micro)
                    }
                }
                .frame(height: 136)
                .accessibilityLabel("Recorded pulse in beats per minute over elapsed seconds, with a linear regression trend")

                // Regression summary footer
                if let trend {
                    HStack(spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.xxs) {
                            Circle().fill(trendColor).frame(width: 7, height: 7)
                            Text("Linear fit")
                        }
                        Text("·")
                        Text("\(trend.sampleCount) filtered readings")
                        Text("·")
                        Text(String(format: "%+.1f BPM/min", trend.slope * 60))
                            .foregroundStyle(trend.slope < 0 ? AppColors.brandTeal : AppColors.brandOrange)
                        Text("·")
                        Text(String(format: "R² %.2f", trend.rSquared))
                            .foregroundStyle(trendColor)
                    }
                    .font(AppTypography.microMedium)
                    .foregroundStyle(AppColors.secondary)
                } else {
                    Text("Recorded points · the fit needs two filtered readings at different times")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func inlinePeriodChip(_ preset: TrendPeriodPreset) -> some View {
        let currentPreset = model.measurementSettings.trendPeriodPreset
        let selected = currentPreset == preset
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
                    selected ? AppColors.brandTeal.opacity(0.18) : AppColors.subtleFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? AppColors.brandTeal.opacity(0.35) : AppColors.border, lineWidth: 0.8)
                )
                .foregroundStyle(selected ? AppColors.brandTeal : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .buttonStyle(.tactile(scale: 0.95))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Dual Photo Snapshots Card
public struct SessionSnapshotsCard: View {
    public let peakImage: NSImage?
    public let peakBPM: Double?
    public let restedImage: NSImage?
    public let restedBPM: Double?

    public init(peakImage: NSImage?, peakBPM: Double?, restedImage: NSImage?, restedBPM: Double?) {
        self.peakImage = peakImage
        self.peakBPM = peakBPM
        self.restedImage = restedImage
        self.restedBPM = restedBPM
    }

    public var body: some View {
        HStack(spacing: AppSpacing.md) {
            snapshotTile(
                title: "Peak Pulse Snapshot",
                subtitle: ">100 BPM peak effort",
                badge: (peakBPM.map { "\(Int($0.rounded())) BPM" }) ?? ">100 BPM",
                badgeColor: AppColors.brandOrange,
                symbol: "bolt.heart.fill",
                image: peakImage
            )

            snapshotTile(
                title: "Rested Normal Snapshot",
                subtitle: "Return to normal baseline",
                badge: (restedBPM.map { "\(Int($0.rounded())) BPM" }) ?? "Normal baseline",
                badgeColor: AppColors.brandMint,
                symbol: "heart.circle.fill",
                image: restedImage
            )
        }
    }

    @ViewBuilder
    private func snapshotTile(
        title: String,
        subtitle: String,
        badge: String,
        badgeColor: Color,
        symbol: String,
        image: NSImage?
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(AppRadius.md)
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.subtleFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .overlay {
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: "camera.metering.none")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(AppColors.secondary)
                                Text("No snapshot")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondary)
                            }
                        }
                }

                // Solid badge overlay
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(badge)
                        .font(AppTypography.microMedium)
                        .monospacedDigit()
                }
                .foregroundStyle(badgeColor)
                .padding(.horizontal, AppSpacing.xs + 2)
                .padding(.vertical, AppSpacing.xxs + 1)
                .background(AppColors.cameraSlate.opacity(0.88), in: Capsule())
                .padding(AppSpacing.sm)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.ink)
                Text(subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Multi-Phase Session Pulse Chart
public struct SessionMultiPhasePulseChart: View {
    public let record: SetRecord

    public init(record: SetRecord) {
        self.record = record
    }

    private struct ChartPoint: Identifiable {
        let id: UUID
        let elapsed: Double
        let bpm: Double
        let phase: String
    }

    private var chartData: [ChartPoint] {
        var points: [ChartPoint] = []
        let origin = record.captureStartedAt ?? record.baselineSamples?.first?.seconds ?? record.samples.first?.seconds ?? 0

        if let baseline = record.baselineSamples, !baseline.isEmpty {
            for s in baseline {
                points.append(ChartPoint(id: s.id, elapsed: max(0, s.seconds - origin), bpm: s.bpm, phase: "Normal Baseline"))
            }
        }
        if let exercise = record.exerciseSamples, !exercise.isEmpty {
            for s in exercise {
                points.append(ChartPoint(id: s.id, elapsed: max(0, s.seconds - origin), bpm: s.bpm, phase: "Exercise"))
            }
        }
        for s in record.samples {
            points.append(ChartPoint(id: s.id, elapsed: max(0, s.seconds - origin), bpm: s.bpm, phase: "Afterburn Recovery"))
        }

        return points.sorted(by: { $0.elapsed < $1.elapsed })
    }

    private var domain: ClosedRange<Double> {
        let values = chartData.map(\.bpm) + [record.baselineBPM]
        return max(35, (values.min() ?? 55) - 8)...max(110, (values.max() ?? 95) + 10)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Legend
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.brandTeal).frame(width: 7, height: 7)
                    Text("Normal Baseline").font(AppTypography.microMedium).foregroundStyle(AppColors.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.brandOrange).frame(width: 7, height: 7)
                    Text("Exercise").font(AppTypography.microMedium).foregroundStyle(AppColors.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.brandMint).frame(width: 7, height: 7)
                    Text("Afterburn Recovery").font(AppTypography.microMedium).foregroundStyle(AppColors.secondary)
                }
                Spacer()
                Text("Baseline: \(Int(record.baselineBPM.rounded())) BPM")
                    .font(AppTypography.microMedium)
                    .foregroundStyle(AppColors.secondary)
            }

            if chartData.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(AppColors.secondary)
                    Text("No pulse data points recorded for this session.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart {
                    // Baseline reference line
                    RuleMark(y: .value("Baseline", record.baselineBPM))
                        .foregroundStyle(AppColors.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(Int(record.baselineBPM.rounded())) BPM")
                                .font(AppTypography.microMedium)
                                .foregroundStyle(AppColors.secondary)
                        }

                    ForEach(chartData) { pt in
                        PointMark(
                            x: .value("Elapsed", pt.elapsed),
                            y: .value("Pulse", pt.bpm)
                        )
                        .symbolSize(14)
                        .foregroundStyle(by: .value("Phase", pt.phase))
                    }
                }
                .chartForegroundStyleScale([
                    "Normal Baseline": AppColors.brandTeal,
                    "Exercise": AppColors.brandOrange,
                    "Afterburn Recovery": AppColors.brandMint
                ])
                .chartYScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel {
                            if let sec = value.as(Double.self) {
                                Text("\(Int(sec))s").font(AppTypography.micro)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel().font(AppTypography.micro)
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Full session pulse chart across 1-min baseline, exercise, and afterburn recovery")
            }
        }
    }
}
