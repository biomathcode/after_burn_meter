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
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Get to know your recovery.").font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("A record of your sets and the moments in between.")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Button { model.exportHistory() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.bordered).disabled(model.records.isEmpty)
                }
                HStack(spacing: 16) {
                    statistic("Sets recorded", value: "\(records.count)", symbol: "checklist")
                    statistic("Observed intervals", value: "\(observed.count)", symbol: "waveform.path.ecg")
                    statistic("Average observed interval", value: average.map(TimeText.duration) ?? "—", symbol: "clock")
                }
                HStack {
                    Text("Your observations").font(.system(size: 16, weight: .semibold))
                    Spacer()

                }
                if records.isEmpty {
                    Panel {
                        VStack {
                            EmptyState(symbol: "chart.xyaxis.line", title: "Your story starts with a set.",
                                detail: "Complete a camera-based session to record your first recovery observation.")
                            Button("Go to workout") { model.section = .workout }.buttonStyle(.bordered)
                        }.frame(maxWidth: .infinity).padding(.bottom, 24)
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            Button { selectedRecord = record } label: {
                                Panel(padding: 18) {
                                    HStack(spacing: 15) {
                                        Image(systemName: "waveform.path.ecg").font(.system(size: 22)).foregroundStyle(Palette.teal)
                                            .frame(width: 43, height: 43).background(Palette.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(record.exerciseName).font(.system(size: 14, weight: .medium))
                                            Text("\(record.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))  /  Set \(record.setNumber)")
                                                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                        }
                                        Spacer()
                                        Pill(title: record.outcome.label, color: record.outcome == .observed ? Palette.teal : Palette.secondary)
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(TimeText.duration(record.recoverySeconds)).font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit()
                                            Text("recorded interval").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                        }.frame(width: 105, alignment: .trailing)
                                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text("These intervals include sensor warm-up and confirmation time. They are observations of pulse, not measures of muscle recovery or fitness clearance.")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
            }.padding(30)
        }
        .sheet(item: $selectedRecord) { RecordDetailView(record: $0) }
    }

    private func statistic(_ title: String, value: String, symbol: String) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(Palette.teal)
                Text(value).font(.system(size: 33, weight: .medium, design: .rounded)).monospacedDigit()
                Text(title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecordDetailView: View {
    let record: SetRecord
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text(record.exerciseName).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer()
            }
            HStack(spacing: 26) {
                detail("Set", "\(record.setNumber)")
                detail("Repetitions", "\(record.repetitions)")
                detail("Work", TimeText.duration(record.workSeconds))
                detail("Recorded interval", TimeText.duration(record.recoverySeconds))
            }
            Divider()
            PulseChart(samples: record.samples, baseline: record.baselineBPM, policy: record.policy)
            AnalysisSummaryView(record: record)
            Pill(title: record.outcome.label, color: record.outcome == .observed ? Palette.teal : Palette.secondary)
            Text("Session baseline: \(Int(record.baselineBPM.rounded())) BPM. Qualification required \(Int(record.policy.confirmationSeconds)) valid seconds within \(Int(record.policy.toleranceBPM)) BPM of baseline.")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(4)
            if record.hadMeasurementGaps {
                Label("Measurement gaps occurred. The interval includes time without a usable signal.", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12)).foregroundStyle(Palette.orange)
            }
            Text("Recorded with SmartSpectra \(record.sdkVersion). The return to baseline is approximate because pulse is averaged over a measurement window.")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Palette.ink) }
        }.padding(30).frame(width: 640).foregroundStyle(Palette.ink).background(Palette.background)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Text(value).font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}

