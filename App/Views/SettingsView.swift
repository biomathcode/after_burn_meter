import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDelete = false
    @State private var confirmRevoke = false
    @State private var showPrivacy = false
    @State private var showVitals = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                PageHeader(
                    title: "Make yourself at home.",
                    subtitle: "Preferences, sensor diagnostics, and local data controls."
                )

                Panel {
                    MeasurementSettingsView()
                }

                SensorSettingsSection(onShowVitals: { showVitals = true })

                CredentialSettingsSection()

                PrivacySettingsSection(
                    onShowPrivacy: { showPrivacy = true },
                    onConfirmRevoke: { confirmRevoke = true },
                    onConfirmDelete: { confirmDelete = true }
                )

                AboutSettingsSection()
            }
            .padding(AppSpacing.xxl)
            .frame(maxWidth: 1050, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyNoticeView()
        }
        .sheet(isPresented: $showVitals) {
            LiveVitalsView().environment(model)
        }
        .confirmationDialog("Delete all recovery history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all history", role: .destructive) {
                model.clearHistory()
            }
        } message: {
            Text("This deletes saved observations from this Mac. Export a copy first if you want to keep them.")
        }
        .confirmationDialog("Withdraw camera consent?", isPresented: $confirmRevoke, titleVisibility: .visible) {
            Button("Withdraw consent", role: .destructive) {
                model.revokeConsent()
            }
        } message: {
            Text("Capture stops immediately and the consent screen returns. Your saved history remains until you delete it.")
        }
    }
}

// MARK: - Sensor Settings Section Subview
private struct SensorSettingsSection: View {
    @Environment(AppModel.self) private var model
    let onShowVitals: () -> Void

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Camera & sensor", systemImage: "camera")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)

                statusRow("SmartSpectra SDK", value: model.sensor.sdkVersion, good: true)
                statusRow("API key", value: model.apiKeyConfigured ? "Configured" : "Not configured", good: model.apiKeyConfigured)
                statusRow("Apple Development signing", value: model.sensor.hasSigning ? "Available" : "Setup required", good: model.sensor.hasSigning)

                if !model.sensor.hasSigning {
                    Text("Camera preview is available in this development build. Start a baseline to test SmartSpectra; any SDK authentication or Keychain error will be shown here.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineSpacing(3)
                }

                Divider().opacity(0.6)

                HStack(spacing: AppSpacing.md) {
                    Picker("Camera", selection: Bindable(model.sensor).selectedCameraID) {
                        Text("System default").tag("")
                        ForEach(model.sensor.cameras, id: \.identifier) { camera in
                            Text(camera.name).tag(camera.identifier)
                        }
                    }
                    .frame(maxWidth: 400)
                    .accessibilityLabel("Select Camera")

                    Button("Refresh") {
                        model.sensor.refreshCameras()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .disabled(model.phase.isActive)

                HStack(spacing: AppSpacing.sm) {
                    PrimaryButton(
                        title: model.sensor.isCameraRunning ? "Close camera" : "Open camera",
                        symbol: "camera",
                        tint: AppColors.brandTeal
                    ) {
                        if model.sensor.isCameraRunning {
                            model.closeCamera()
                        } else {
                            model.openCamera()
                        }
                    }
                    .disabled(model.sensor.isStarting)

                    Button("Test SmartSpectra") {
                        model.startBaseline()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.phase.isActive || model.plan.isEmpty || !model.apiKeyConfigured)

                    Button("All vitals", action: onShowVitals)
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                    Text(model.sensor.status)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }

                if let image = model.sensor.frame {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(AppColors.borderHighlight.opacity(0.3), lineWidth: 1)
                        )
                }

                if let error = model.sensor.lastSDKError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.brandOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SDKDiagnosticsView()

                Text("Open camera previews locally. Test SmartSpectra starts pulse, breathing, HRV, waveforms, and EDA Proxy processing. Audio is not requested.")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusRow(_ label: String, value: String, good: Bool) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.secondary)
            Spacer()
            Pill(
                title: value,
                color: good ? AppColors.brandTeal : AppColors.brandOrange,
                symbol: good ? "checkmark.circle.fill" : "exclamationmark.circle"
            )
        }
    }
}

// MARK: - Credential Settings Section Subview
private struct CredentialSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var key = ""
    @State private var keySaved = false

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("SmartSpectra credential", systemImage: "key")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)

                Text("Store a personal development key in macOS Keychain. The app never includes a key in its bundled resources.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)

                HStack(spacing: AppSpacing.sm) {
                    SecureField("Paste API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 480)
                        .accessibilityIdentifier("api-key")
                        .accessibilityLabel("SmartSpectra API Key")

                    Button("Save to Keychain") {
                        model.configureKey(key)
                        if model.errorMessage == nil {
                            key = ""
                            keySaved = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.brandTeal)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.phase.isActive)
                }

                HStack {
                    if keySaved {
                        Label("Saved in Keychain", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.brandTeal)
                    }
                    Spacer()
                    Button("Forget key", role: .destructive) {
                        model.removeKey()
                        keySaved = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!model.apiKeyConfigured || model.phase.isActive)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Privacy Settings Section Subview
private struct PrivacySettingsSection: View {
    @Environment(AppModel.self) private var model
    let onShowPrivacy: () -> Void
    let onConfirmRevoke: () -> Void
    let onConfirmDelete: () -> Void

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Privacy & your data", systemImage: "hand.raised")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)

                Text(model.consent.map { "Consent accepted \($0.acceptedAt.formatted(date: .abbreviated, time: .shortened)). Notice version \($0.version)." }
                     ?? "Camera consent has not been given.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)

                HStack(spacing: AppSpacing.sm) {
                    Button("Review privacy notice", action: onShowPrivacy)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                    Button(
                        model.consent == nil ? "Review camera consent" : "Withdraw consent",
                        role: model.consent == nil ? nil : .destructive,
                        action: onConfirmRevoke
                    )
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Spacer()
                }

                Divider().opacity(0.6)

                HStack {
                    Text("\(model.records.count) saved set observations")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondary)
                    Spacer()
                    Button("Export history") {
                        model.exportHistory()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.records.isEmpty)

                    Button("Delete all history", role: .destructive, action: onConfirmDelete)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(model.records.isEmpty || model.phase.isActive)
                }

                Text("History is stored locally with SwiftData. SDK telemetry is disabled. No raw camera recordings are saved by Afterburn.")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - About Prototype Section Subview
private struct AboutSettingsSection: View {
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("About this prototype", systemImage: "info.circle")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)

                Text("Afterburn \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development") • macOS 14+ • Apple Silicon")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)

                Text("Pulse-based recovery is experimental. The pulse range remains 40–110 BPM. Confidence, time periods, and baseline tolerance are configurable above. The clock continues through signal gaps, and the graph fits recorded readings over elapsed time. These are prototype settings, not medical thresholds.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(3)

                HStack(spacing: AppSpacing.lg) {
                    Link("SDK documentation", destination: URL(string: "https://github.com/Presage-Security/SmartSpectra")!)
                    Link("Exercise catalogue", destination: URL(string: "https://github.com/hasaneyldrm/exercises-dataset")!)
                }
                .font(AppTypography.caption)

                Text("Exercise metadata and instructions © Hasan Emir Yıldırım, MIT licence. Gym Visual images and GIFs are not included. SmartSpectra is proprietary software governed by Presage’s terms; bundled third-party notices are included with the app.")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Privacy Notice Sheet
private struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PageHeader(
                title: "Your privacy in Afterburn",
                subtitle: "Notice version \(ConsentRecord.currentVersion)"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("You can open a local camera preview; capture is also used during baseline and seated recovery checks. Afterburn does not record video or request audio. SmartSpectra computes pulse, breathing, HRV, relative arterial and breathing waveforms, and EDA Proxy on-device. It requires authenticated network access and may perform device-related service requests. Additional vitals are displayed in memory; the recovery journal stores pulse observations only.")
                    Text("SDK diagnostic telemetry is disabled. Afterburn does not register an Insights callback or request LLM analysis. The SDK’s independent network behaviour has not been audited; the app does not promise a completely offline or zero-egress measurement.")
                    Text("Your routine and derived pulse/recovery observations are stored on this Mac. Settings provides export, deletion, and consent withdrawal. Withdrawing consent stops capture and does not delete history automatically.")
                    Text("Pulse recovery is an experimental wellness observation. It does not measure calorie afterburn, muscle healing, or readiness to exercise. It is not for diagnosis, treatment, or safety decisions.")
                    Link("Presage privacy policy", destination: URL(string: "https://api.physiology.presagetech.com/privacypolicy")!)
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondary)
                .lineSpacing(4)
            }
            .frame(maxHeight: 380)

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
        .padding(AppSpacing.xxl)
        .frame(minWidth: 540, idealWidth: 600)
        .background(AppColors.background)
    }
}
