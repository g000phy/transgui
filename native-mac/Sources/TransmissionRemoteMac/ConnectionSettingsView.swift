import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ConnectionDraft

    init(draft: ConnectionDraft) {
        self._draft = State(initialValue: draft)
    }

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Server") {
                    TextField("RPC URL", text: $draft.rpcURLString)
                        .textContentType(.URL)

                    TextField("Username", text: $draft.username)
                        .textContentType(.username)

                    SecureField("Password", text: $draft.password)
                        .textContentType(.password)

                    Toggle("Connect automatically on launch", isOn: $draft.automaticallyConnect)
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
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await appModel.connect(using: draft)
                        if case .connected = appModel.connectionState {
                            dismiss()
                        }
                    }
                } label: {
                    if case .connecting = appModel.connectionState {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.rpcURLString.isEmpty || appModel.connectionState == .connecting)
            }
            .padding()
        }
        .frame(width: 460, height: 300)
    }
}

#Preview {
    ConnectionSettingsView(
        draft: ConnectionDraft(
            profile: .empty,
            password: ""
        )
    )
    .environment(AppModel())
}
