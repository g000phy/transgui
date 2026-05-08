import SwiftUI

struct AddMagnetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Magnet Link")
                    .font(.title3.weight(.semibold))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.35))

                    TextEditor(text: $appModel.magnetLinkDraft)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(minHeight: 112, maxHeight: 112)
                        .onChange(of: appModel.magnetLinkDraft) {
                            appModel.addMagnetErrorMessage = nil
                        }

                    if appModel.magnetLinkDraft.isEmpty {
                        Text("Paste link")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

                if let message = appModel.addMagnetErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)

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
                        let didAdd = await appModel.addMagnetLink()
                        if didAdd {
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
        .frame(width: 620, height: 280)
        .onAppear {
            appModel.addMagnetErrorMessage = nil
        }
    }
}

#Preview {
    AddMagnetView()
        .environment(AppModel())
}
