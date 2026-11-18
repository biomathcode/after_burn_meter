import SwiftUI

struct WorkoutSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PlannedExercise?
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make this session yours.").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("Your camera, movements, and pace in one place.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Camera", selection: Bindable(model.sensor).selectedCameraID) {
                Text("System default").tag("")
                ForEach(model.sensor.cameras, id: \.identifier) { Text($0.name).tag($0.identifier) }
            }
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(model.plan) { item in
                        if let exercise = model.exercises.first(where: { $0.id == item.exerciseID }) {
                            HStack(spacing: 14) {
                                Image(systemName: exercise.symbol).font(.title2).foregroundStyle(Palette.teal).frame(width: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.displayName).font(.headline)
                                    Text("\(item.sets) sets  /  \(item.repetitions) reps  /  \(item.targetSeconds)s target")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Use") {
                                    if let index = model.plan.firstIndex(where: { $0.id == item.id }) { model.selectPlanItem(index) }
                                }
                                Button("Edit") { editing = item }
                            }.padding(15).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }.frame(maxHeight: 330)
            HStack {
                Button { model.section = .exercises; dismiss() } label: { Label("Add movement", systemImage: "plus") }
                Spacer()
                if model.apiKeyConfigured && !model.plan.isEmpty {
                    PrimaryButton(title: "Measure baseline", symbol: "camera") { dismiss(); model.startBaseline() }
                } else {
                    PrimaryButton(title: "Configure live sensor", symbol: "camera") { model.section = .settings; dismiss() }
                }
            }
        }.padding(30).frame(width: 650)
        .sheet(item: $editing) { PlanEditor(item: $0).environment(model) }
        .task { model.sensor.refreshCameras() }
    }
}

struct AnalysisSummaryView: View {
    let record: SetRecord
    private var analysis: RecoveryAnalysis { RecoveryAnalysis(record: record) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Measured recovery analysis", systemImage: "chart.xyaxis.line").font(.headline)
            HStack(spacing: 28) {
                metric("Median pulse", analysis.medianPulse.map { "\(Int($0.rounded())) BPM" } ?? "—")
                metric("Peak valid pulse", analysis.peakPulse.map { "\(Int($0.rounded())) BPM" } ?? "—")
                metric("Signal coverage", "\(Int((analysis.signalCoverage * 100).rounded()))%")
                metric("Valid samples", "\(analysis.validSampleCount) / \(analysis.totalSampleCount)")
            }
            Text(analysis.observedReturn
                 ? "A sustained return near your session baseline was observed. The interval includes warm-up and confirmation time."
                 : "A sustained return near baseline was not confirmed in this interval. Missing or excluded readings do not establish recovery.")
                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}
