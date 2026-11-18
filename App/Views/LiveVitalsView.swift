import SwiftUI
import Charts

struct LiveVitalsPanel: View {
    @Environment(AppModel.self) private var model
    var showDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Live vitals", systemImage: "waveform.path.ecg").font(.caption)
                Spacer()
                Button("All vitals", action: showDetails).font(.caption).buttonStyle(.borderless)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                ForEach([VitalKind.pulse, .breathing, .rmssd, .eda], id: \.self) { kind in
                    VitalValue(kind: kind, compact: true)
                }
            }
            Text(model.baseline.map { "Session baseline \(Int($0.rounded())) BPM" } ?? "Baseline not measured")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(20).frame(width: 310).floatingGlass()
    }
}

struct LiveVitalsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your rhythm, in view.").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("Live measurements from SmartSpectra \(model.sensor.sdkVersion)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(26)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 22) {
                        if let frame = model.sensor.frame {
                            Image(nsImage: frame).resizable().scaledToFit().frame(width: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .accessibilityLabel("Live camera framing")
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Label(model.sensor.isRunning ? "Measurement running" : "Measurement stopped",
                                  systemImage: model.sensor.isRunning ? "waveform.path.ecg" : "pause.circle")
                                .font(.headline)
                            Text(model.sensor.feedback(at: model.now)).font(.callout).fixedSize(horizontal: false, vertical: true)
                            Text("Sit still with your face and chest evenly lit. Keep the camera on a stable surface. HRV needs at least 60 seconds.")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack {
                                if model.sensor.isRunning || model.sensor.isStarting {
                                    Button("Stop measurement") { model.closeCamera() }
                                } else {
                                    PrimaryButton(title: "Start measurement", symbol: "waveform.path.ecg") { model.startBaseline() }
                                        .disabled(!model.apiKeyConfigured || model.plan.isEmpty || model.phase.isActive)
                                }
                                Text("\(Int(model.sensor.measurementElapsed(at: model.now)))s captured")
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .top)], spacing: 14) {
                        ForEach(VitalKind.allCases, id: \.self) { kind in
                            VStack(alignment: .leading, spacing: 12) {
                                VitalValue(kind: kind)
                                VitalTrace(kind: kind)
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    Text("Arterial and breathing traces use relative units. The arterial waveform is not a calibrated blood-pressure reading. EDA is a camera-derived proxy. Additional vitals stay in this live view; the recovery journal continues to use measured pulse only.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    SDKDiagnosticsView()
                }.padding(26)
            }
        }.frame(minWidth: 860, idealWidth: 1030, minHeight: 660, idealHeight: 800)
    }
}

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
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Text(kind.title).font(compact ? .caption2 : .callout).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(number).font(.system(size: compact ? 28 : 35, weight: .medium, design: .rounded))
                    .monospacedDigit().accessibilityIdentifier("vital-\(kind.rawValue)")
                if !compact || !kind.isWaveform {
                    Text(kind.unit).font(.system(size: compact ? 9 : 11)).foregroundStyle(.secondary)
                }
            }
            Text(quality).font(.system(size: compact ? 9 : 11))
                .foregroundStyle(reliable ? Color.mint : .secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

private struct VitalTrace: View {
    @Environment(AppModel.self) private var model
    let kind: VitalKind
    private var points: [VitalPoint] { model.sensor.vitals.history[kind] ?? [] }

    var body: some View {
        if points.count > 1 {
            Chart(points, id: \.seconds) { point in
                LineMark(x: .value("Time", point.seconds), y: .value(kind.title, point.value),
                         series: .value("Continuous segment", point.segment))
                    .foregroundStyle(kind == .pulse || kind == .arterial ? Color.orange : Color.teal)
            }.chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 65).accessibilityLabel("\(kind.title), measured signal history")
            Text("Measured signal · gaps stay empty").font(.system(size: 9)).foregroundStyle(.secondary)
        } else {
            RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.035)).frame(height: 65)
                .overlay(Text("Waiting for measured samples").font(.caption2).foregroundStyle(.secondary))
        }
    }
}

struct SDKDiagnosticsView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("SDK signal check", systemImage: "checklist").font(.callout.weight(.semibold))
            Text(model.sensor.hasValidation ? model.sensor.validationHint : "No validation feedback received yet.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                Text("\(model.sensor.acceptedFrames) frames accepted")
                Text("\(model.sensor.blockedFrames) blocked")
                Text("\(model.sensor.metricPackets) metric packets")
                Text("\(model.sensor.pulseSamplesReceived) pulse samples")
            }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
            Text("Processing: \(model.sensor.processingStatus)").font(.caption2).foregroundStyle(.secondary)
            if model.sensor.isRunning && model.sensor.measurementElapsed(at: model.now) >= 20 && model.sensor.pulseSamplesReceived == 0 {
                Text("No pulse samples have arrived. Use the SDK guidance above; if other vitals work, check that your API key includes cardio access. A running camera alone does not confirm pulse measurement.")
                    .font(.caption).foregroundStyle(Palette.orange).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }
}
