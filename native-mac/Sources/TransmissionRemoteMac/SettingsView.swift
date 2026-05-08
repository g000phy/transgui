import SwiftUI

struct SettingsView: View {
    @AppStorage(TorrentTableColumnPreferences.storageKey)
    private var encodedColumnPreferences = TorrentTableColumnPreferences.defaultValue.encoded

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

            Section("Torrent List Columns") {
                TorrentTableColumnSettingsEditor(encodedPreferences: $encodedColumnPreferences)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480)
        .onAppear {
            defaultStatus = DefaultAppManager.currentStatus()
        }
    }
}

private struct TorrentTableColumnSettingsEditor: View {
    @Binding var encodedPreferences: String

    private var preferences: TorrentTableColumnPreferences {
        get {
            TorrentTableColumnPreferences(encoded: encodedPreferences)
        }
        nonmutating set {
            encodedPreferences = newValue.encoded
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(preferences.order) { column in
                HStack(spacing: 8) {
                    Toggle(column.title, isOn: visibilityBinding(for: column))
                        .disabled(!canToggleOff(column))

                    Spacer()

                    Button {
                        moveUp(column)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(preferences.order.first == column)
                    .help("Move Up")

                    Button {
                        moveDown(column)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(preferences.order.last == column)
                    .help("Move Down")
                }
            }

            HStack {
                Spacer()

                Button("Reset") {
                    var updated = preferences
                    updated.reset()
                    preferences = updated
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func visibilityBinding(for column: TorrentTableColumn) -> Binding<Bool> {
        Binding {
            !preferences.hidden.contains(column)
        } set: { isVisible in
            var updated = preferences
            updated.setVisible(isVisible, for: column)
            preferences = updated
        }
    }

    private func canToggleOff(_ column: TorrentTableColumn) -> Bool {
        preferences.hidden.contains(column) || preferences.visibleColumns.count > 1
    }

    private func moveUp(_ column: TorrentTableColumn) {
        var updated = preferences
        updated.moveUp(column)
        preferences = updated
    }

    private func moveDown(_ column: TorrentTableColumn) {
        var updated = preferences
        updated.moveDown(column)
        preferences = updated
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
