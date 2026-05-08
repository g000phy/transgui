import SwiftUI

struct AddMagnetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Magnet Link")
                    .font(.title3.weight(.semibold))

                TextField("Paste link", text: $appModel.magnetLinkDraft)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .onSubmit {
                        submit()
                    }
                    .onChange(of: appModel.magnetLinkDraft) {
                        appModel.addMagnetErrorMessage = nil
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
                    submit()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.magnetLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding()
        }
        .frame(width: 620, height: 180)
        .onAppear {
            appModel.addMagnetErrorMessage = nil
        }
    }

    private func submit() {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        Task {
            let didAdd = await appModel.addMagnetLink()
            isSubmitting = false
            if didAdd {
                dismiss()
            }
        }
    }
}

#Preview {
    AddMagnetView()
        .environment(AppModel())
}
