import SwiftUI
import TransmissionRPC

struct SpeedSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SpeedLimits

    init(draft: SpeedLimits) {
        self._draft = State(initialValue: draft)
    }

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Normal Limits") {
                    Toggle("Limit download speed", isOn: $draft.isDownloadLimitEnabled)
                    Stepper(value: $draft.downloadLimitKBps, in: 1...1_000_000, step: 50) {
                        LabeledContent("Download", value: speedLabel(draft.downloadLimitKBps))
                    }
                    .disabled(!draft.isDownloadLimitEnabled)

                    Toggle("Limit upload speed", isOn: $draft.isUploadLimitEnabled)
                    Stepper(value: $draft.uploadLimitKBps, in: 1...1_000_000, step: 50) {
                        LabeledContent("Upload", value: speedLabel(draft.uploadLimitKBps))
                    }
                    .disabled(!draft.isUploadLimitEnabled)
                }

                Section("Alternative Limits") {
                    Toggle("Use alternative limits", isOn: $draft.isAltSpeedEnabled)

                    Stepper(value: $draft.altDownloadLimitKBps, in: 1...1_000_000, step: 50) {
                        LabeledContent("Download", value: speedLabel(draft.altDownloadLimitKBps))
                    }

                    Stepper(value: $draft.altUploadLimitKBps, in: 1...1_000_000, step: 50) {
                        LabeledContent("Upload", value: speedLabel(draft.altUploadLimitKBps))
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await appModel.applySpeedLimits(draft)
                        if !appModel.isSpeedSettingsPresented {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Apply")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 520)
    }

    private func speedLabel(_ kilobytesPerSecond: Int) -> String {
        ByteFormat.transferRate(Int64(kilobytesPerSecond) * 1_000)
    }
}

#Preview {
    SpeedSettingsView(
        draft: SpeedLimits(
            downloadLimitKBps: 100,
            isDownloadLimitEnabled: false,
            uploadLimitKBps: 100,
            isUploadLimitEnabled: false,
            altDownloadLimitKBps: 50,
            altUploadLimitKBps: 50,
            isAltSpeedEnabled: false
        )
    )
    .environment(AppModel())
}
