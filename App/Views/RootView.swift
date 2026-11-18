import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.mayEnterApp {
                ZStack(alignment: .top) {
                    if model.section == .workout {
                        ImmersiveStage()
                    } else {
                        ZStack {
                            AppColors.background.ignoresSafeArea()
                            page
                                .padding(.top, 84)
                        }
                    }

                    if !model.isStageFocused {
                        navigation
                            .padding(.top, AppSpacing.lg)
                            .padding(.horizontal, AppSpacing.xl)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(minWidth: 980, minHeight: 700)
                .preferredColorScheme(model.section == .workout ? .dark : nil)
            } else {
                ConsentView()
            }
        }
        .tint(AppColors.brandTeal)
        .alert("Something needs attention", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            model.isStageFocused = false
        }
    }

    @ViewBuilder
    private var page: some View {
        switch model.section {
        case .workout:
            ImmersiveStage()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }

    private var navigation: some View {
        GlassGroup {
            HStack(spacing: AppSpacing.md) {
                // Brand mark
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.brandOrange)
                    Text("Afterburn")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.ink)
                }

                Spacer(minLength: AppSpacing.md)

                // Navigation segmented pills
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(AppSection.allCases) { section in
                        let isSelected = model.section == section
                        Button {
                            withAnimation(reduceMotion ? nil : AppAnimation.springSnappy) {
                                model.section = section
                            }
                        } label: {
                            Label(
                                section == .workout ? "Train" :
                                section == .history ? "Journal" : "Settings",
                                systemImage: section.symbol
                            )
                            .font(isSelected ? AppTypography.calloutMedium : AppTypography.callout)
                            .foregroundStyle(isSelected ? AppColors.ink : AppColors.secondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                isSelected ? AppColors.ink.opacity(0.09) : Color.clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? AppColors.borderHighlight.opacity(0.3) : Color.clear, lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .buttonStyle(.tactile(scale: 0.96))
                        .accessibilityIdentifier("nav-\(section.rawValue)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(3)
                .background(AppColors.subtleFill, in: Capsule())

                Spacer(minLength: AppSpacing.md)

                // Camera live indicator
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(model.sensor.isCameraRunning ? AppColors.brandMint : AppColors.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(model.sensor.isCameraRunning ? "Camera live" : "Camera off")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs + 2)
            .floatingGlass(radius: AppRadius.xxl)
        }
    }
}
