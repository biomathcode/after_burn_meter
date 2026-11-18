import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if model.mayEnterApp {
                ZStack(alignment: .top) {
                    if model.section == .workout { ImmersiveStage() }
                    else {
                        ZStack {
                            Palette.background
                            LinearGradient(colors: [Palette.teal.opacity(0.08), .clear, .blue.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            page.padding(.top, 94)
                        }
                    }
                    if !model.isStageFocused { navigation.padding(.top, 30).padding(.horizontal, 24) }
                }
                .frame(minWidth: 980, minHeight: 700)
                .preferredColorScheme(model.section == .workout ? .dark : nil)
            } else { ConsentView() }
        }
        .tint(Palette.teal)
        .alert("Something needs attention", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in model.isStageFocused = false }
    }
    @ViewBuilder private var page: some View {
        switch model.section {
        case .workout: ImmersiveStage()
        case .exercises: ExerciseLibraryView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }
    private var navigation: some View {
        GlassGroup {
            HStack(spacing: 18) {
                Label("Afterburn", systemImage: "flame.fill").font(.system(size: 19, weight: .semibold, design: .rounded))
                Spacer(minLength: 15)
                HStack(spacing: 4) {
                    ForEach(AppSection.allCases) { section in
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { model.section = section }
                        } label: {
                            Label(section == .workout ? "Train" : section == .exercises ? "Exercises" : section == .history ? "Journal" : "Settings", systemImage: section.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(model.section == section ? Color.primary.opacity(0.1) : .clear, in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("nav-\(section.rawValue)")
                    }
                }
                Spacer(minLength: 15)
                Label(model.sensor.isCameraRunning ? "Camera live" : "Camera off", systemImage: model.sensor.isCameraRunning ? "video.fill" : "video.slash")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(10).padding(.horizontal, 10).floatingGlass(radius: 26)
        }
    }
}
