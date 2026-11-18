import SwiftUI

struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @State private var agrees = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Label("Afterburn", systemImage: "flame.fill")
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "figure.cooldown")
                    .font(.system(size: 108, weight: .ultraLight)).foregroundStyle(Color.white.opacity(0.85))
                Text("A better rhythm.\nOne set at a time.")
                    .font(.system(size: 37, weight: .medium, design: .rounded)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Time your effort. Observe your recovery.\nBuild a routine that belongs to you.")
                    .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.7)).lineSpacing(5)
                Spacer()
                Text("Built for your Mac.").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(44).frame(width: 400).frame(maxHeight: .infinity)
            .background(Palette.camera)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Pill(title: "Before your first session", symbol: "hand.raised")
                    Text("Your camera.\nYour choice.")
                        .font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                    Text("Please review how Afterburn uses your camera and vital estimates. We remember your choice for this version of the notice.")
                        .font(.system(size: 14)).foregroundStyle(Palette.secondary).lineSpacing(4)

                    consentRow("camera", "Camera during checks", "You can open a local camera preview, then use it for baseline and seated recovery measurements. Afterburn does not save camera video or photos. Camera capture stops during your exercise set.")
                    consentRow("network", "Vitals stay on your device", "SmartSpectra estimates pulse, breathing, HRV, relative arterial and breathing waveforms, and EDA Proxy on your Mac. The additional vitals are shown live in memory. Presage receives authentication and device-related service requests. Diagnostic reporting and AI analysis are off.")
                    consentRow("internaldrive", "A journal on this Mac", "Your exercise routine and derived pulse/recovery history are saved locally. You can export or delete history and withdraw consent in Settings.")
                    consentRow("heart.text.clipboard", "An estimate, not a clearance", "This prototype observes pulse returning near a session baseline. It does not measure calorie afterburn, muscle healing, or readiness to exercise, and is not for diagnosis or treatment.")
                    HStack(spacing: 18) {
                        Link("Presage privacy policy", destination: URL(string: "https://api.physiology.presagetech.com/privacypolicy")!)
                        Link("SDK limitations", destination: URL(string: "https://github.com/Presage-Security/SmartSpectra/blob/main/docs/model-cards-and-limitations.md")!)
                    }.font(.system(size: 11))
                    Divider()
                    Toggle("I agree to camera-based vital processing and local storage as described above.", isOn: $agrees)
                        .toggleStyle(.checkbox).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        PrimaryButton(title: "Agree and continue", action: model.acceptConsent)
                            .disabled(!agrees).keyboardShortcut(.defaultAction)
                    }
                    Text("Notice version 2 adds the live vitals view. Acceptance is remembered until the notice changes or you withdraw consent. The macOS camera permission is separate.")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                .padding(44).frame(maxWidth: 650, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
        }
        .frame(minWidth: 1000, minHeight: 730)
    }

    private func consentRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Palette.teal)
                .frame(width: 27, height: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

