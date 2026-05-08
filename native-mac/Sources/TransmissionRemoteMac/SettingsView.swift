import SwiftUI

struct SettingsView: View {
    @State private var defaultStatus = DefaultAppManager.currentStatus()
    @State private var lastActionMessage: String?

    var body: some View {
        Form {
            Section("Default Apps") {
                LabeledContent("Magnet links") {
                    DefaultStatusLabel(isDefault: defaultStatus.isMagnetDefault)
                }

                LabeledContent("Torrent files") {
                    DefaultStatusLabel(isDefault: defaultStatus.isTorrentDefault)
                }

                Button {
                    defaultStatus = DefaultAppManager.makeDefault()
                    lastActionMessage = defaultStatus.isFullyDefault
                        ? "Transmission Remote Mac is now the default app."
                        : "macOS did not confirm all default app changes."
                } label: {
                    Label("Make Default", systemImage: "checkmark.circle")
                }

                if let lastActionMessage {
                    Text(lastActionMessage)
                        .font(.callout)
                        .foregroundStyle(defaultStatus.isFullyDefault ? .green : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .onAppear {
            defaultStatus = DefaultAppManager.currentStatus()
        }
    }
}

private struct DefaultStatusLabel: View {
    let isDefault: Bool

    var body: some View {
        Label(
            isDefault ? "Default" : "Not Default",
            systemImage: isDefault ? "checkmark.circle.fill" : "minus.circle"
        )
        .foregroundStyle(isDefault ? .green : .secondary)
    }
}

#Preview {
    SettingsView()
}

