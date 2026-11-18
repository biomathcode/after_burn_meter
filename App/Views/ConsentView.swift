import SwiftUI

struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @State private var agrees = false

    var body: some View {
        HStack(spacing: 0) {
            // Left Hero Column
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.brandOrange)
                    Text("Afterburn")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "figure.cooldown")
                    .font(.system(size: 96, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.85))

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("A better rhythm.\nOne set at a time.")
                        .font(AppTypography.hero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Time your effort. Observe your recovery.\nBuild a routine that belongs to you.")
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineSpacing(4)
                }

                Spacer()

                Text("Built for your Mac.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(AppSpacing.xxxl)
            .frame(width: 380)
            .frame(maxHeight: .infinity)
            .background(AppColors.cameraSlate)

            // Right Consent Content Column
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Pill(title: "Before your first session", color: AppColors.brandTeal, symbol: "hand.raised")

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Your camera.\nYour choice.")
                            .font(AppTypography.hero)
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Please review how Afterburn uses your camera and vital estimates. We remember your choice for this version of the notice.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.secondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        consentRow(
                            "camera",
                            "Camera during checks",
                            "You can open a local camera preview, then use it for baseline and seated recovery measurements. Afterburn does not save camera video or photos. Camera capture stops during your exercise set."
                        )
                        consentRow(
                            "network",
                            "Vitals stay on your device",
                            "SmartSpectra estimates pulse, breathing, HRV, relative arterial and breathing waveforms, and EDA Proxy on your Mac. The additional vitals are shown live in memory. Presage receives authentication and device-related service requests. Diagnostic reporting and AI analysis are off."
                        )
                        consentRow(
                            "internaldrive",
                            "A journal on this Mac",
                            "Your exercise routine and derived pulse/recovery history are saved locally. You can export or delete history and withdraw consent in Settings."
                        )
                        consentRow(
                            "heart.text.clipboard",
                            "An estimate, not a clearance",
                            "This prototype observes pulse returning near a session baseline. It does not measure calorie afterburn, muscle healing, or readiness to exercise, and is not for diagnosis or treatment."
                        )
                    }

                    HStack(spacing: AppSpacing.lg) {
                        Link("Presage privacy policy", destination: URL(string: "https://api.physiology.presagetech.com/privacypolicy")!)
                        Link("SDK limitations", destination: URL(string: "https://github.com/Presage-Security/SmartSpectra/blob/main/docs/model-cards-and-limitations.md")!)
                    }
                    .font(AppTypography.caption)

                    Divider().opacity(0.6)

                    Toggle("I agree to camera-based vital processing and local storage as described above.", isOn: $agrees)
                        .toggleStyle(.checkbox)
                        .font(AppTypography.bodyMedium)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(title: "Agree and continue", symbol: "checkmark", tint: AppColors.brandTeal, action: model.acceptConsent)
                        .disabled(!agrees)
                        .keyboardShortcut(.defaultAction)

                    Text("Notice version 2 adds the live vitals view. Acceptance is remembered until the notice changes or you withdraw consent. The macOS camera permission is separate.")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.secondary)
                        .lineSpacing(2)
                }
                .padding(AppSpacing.xxxl)
                .frame(maxWidth: 680, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .frame(minWidth: 980, minHeight: 700)
    }

    private func consentRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.brandTeal)
                .frame(width: 32, height: 32)
                .background(AppColors.brandTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
