import SwiftUI
import Charts

enum Palette {
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(red: 0.92, green: 0.94, blue: 0.96)
    static let line = Color(red: 0.86, green: 0.89, blue: 0.91)
    static let teal = Color(red: 0.07, green: 0.42, blue: 0.40)
    static let orange = Color(red: 0.76, green: 0.30, blue: 0.13)
    static let camera = Color(red: 0.12, green: 0.19, blue: 0.24)
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line.opacity(0.65)))
    }
}

struct Pill: View {
    let title: String
    var color: Color = Palette.teal
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.08), in: Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    var tint: Color = Palette.ink
    var action: () -> Void
    var body: some View {
        if #available(macOS 26, *) {
            button.buttonStyle(.glassProminent).tint(tint).controlSize(.large)
        } else {
            button.buttonStyle(.borderedProminent).tint(tint).controlSize(.large)
        }
    }
    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(minHeight: 30).padding(.horizontal, 10)
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Palette.teal)
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(detail).font(.callout).foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 390)
        }
        .padding(40).frame(maxWidth: .infinity)
    }
}

struct PulseChart: View {
    var samples: [PulseSample]
    var baseline: Double?
    var policy: RecoveryPolicy
    private var origin: Double { samples.first?.seconds ?? 0 }
    private var domain: ClosedRange<Double> {
        let values = samples.map(\.bpm).filter(\.isFinite) + (baseline.map { [$0] } ?? [])
        return max(35, (values.min() ?? 60) - 10)...max(100, (values.max() ?? 90) + 10)
    }
    var body: some View {
        if samples.isEmpty {
            VStack(spacing: 9) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 30, weight: .light))
                Text("Your pulse trend will appear here.").font(.system(size: 12))
            }
            .foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart {
                if let baseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(Palette.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Baseline \(Int(baseline.rounded()))")
                                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                }
                ForEach(samples.filter { $0.bpm.isFinite }) { sample in
                    PointMark(x: .value("Seconds", sample.seconds - origin), y: .value("Pulse", sample.bpm))
                        .symbolSize(10)
                        .foregroundStyle(policy.accepts(sample) ? Palette.teal : Palette.orange.opacity(0.65))
                }
            }
            .chartYScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(Palette.line.opacity(0.4))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) { Text("\(Int(seconds))s").font(.system(size: 10)) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Palette.line.opacity(0.45))
                    AxisValueLabel().font(.system(size: 10))
                }
            }
            .frame(height: 132)
            .accessibilityLabel("Pulse trend in beats per minute; baseline is shown as a dashed line")
        }
    }
}

