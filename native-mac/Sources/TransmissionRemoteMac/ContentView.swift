import SwiftUI
import TransmissionRPC

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $appModel.selectedFilter) {
                Section("Torrents") {
                    ForEach(TorrentFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            TorrentTable(
                torrents: appModel.visibleTorrents,
                selectedTorrentID: $appModel.selectedTorrentID
            )
            .navigationTitle(appModel.selectedFilter.title)
            .navigationSplitViewColumnWidth(min: 520, ideal: 640, max: 760)
        } detail: {
            TorrentInspector(torrent: appModel.selectedTorrent)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
        }
        .searchable(text: $appModel.searchText, placement: .toolbar)
        .sheet(isPresented: $appModel.isConnectionSettingsPresented) {
            ConnectionSettingsView(
                draft: ConnectionDraft(
                    profile: appModel.connectionProfile,
                    password: appModel.savedPassword()
                )
            )
            .environment(appModel)
        }
        .sheet(isPresented: $appModel.isAddTorrentPresented) {
            AddMagnetView()
                .environment(appModel)
        }
        .confirmationDialog(
            "Remove Torrent",
            isPresented: $appModel.isRemoveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove from list", role: .destructive) {
                Task { await appModel.removeSelectedTorrent(deleteLocalData: false) }
            }

            Button("Remove and delete data", role: .destructive) {
                Task { await appModel.removeSelectedTorrent(deleteLocalData: true) }
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            if let selectedTorrent = appModel.selectedTorrent {
                Text(selectedTorrent.name)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appModel.isConnectionSettingsPresented = true
                } label: {
                    Label("Connect", systemImage: "network")
                }
                .help("Configure Transmission connection")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await appModel.refreshTorrents() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh torrent list")

                Button {
                    appModel.isAddTorrentPresented = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add magnet link or torrent file")
                .disabled(!appModel.isConnected)

                Button {
                    Task { await appModel.startSelectedTorrent() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Start selected torrent")
                .disabled(!appModel.canRunTorrentCommand)

                Button {
                    Task { await appModel.stopSelectedTorrent() }
                } label: {
                    Label("Stop", systemImage: "pause.fill")
                }
                .help("Stop selected torrent")
                .disabled(!appModel.canRunTorrentCommand)

                Button(role: .destructive) {
                    appModel.isRemoveConfirmationPresented = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove selected torrent")
                .disabled(!appModel.canRunTorrentCommand)
            }

            ToolbarItem(placement: .status) {
                ConnectionStatusView(state: appModel.connectionState)
            }
        }
    }
}

private struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        switch state {
        case .disconnected:
            Label("Disconnected", systemImage: "bolt.slash")
                .foregroundStyle(.secondary)
        case .connecting:
            Label("Connecting", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .connected(let serverName):
            Label(serverName, systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .failed:
            Label("Connection failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
