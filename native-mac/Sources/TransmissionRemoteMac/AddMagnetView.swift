import SwiftUI

struct AddMagnetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Magnet Link") {
                    TextField("magnet:?", text: $appModel.magnetLinkDraft, axis: .vertical)
                        .lineLimit(3...6)
                }

                if case .failed(let message) = appModel.connectionState {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    appModel.magnetLinkDraft = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await appModel.addMagnetLink()
                        if !appModel.isAddTorrentPresented {
                            dismiss()
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.magnetLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 240)
    }
}

#Preview {
    AddMagnetView()
        .environment(AppModel())
}
