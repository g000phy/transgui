import SwiftUI
import TransmissionRPC

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView {
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
        } detail: {
            TorrentInspector(torrent: appModel.selectedTorrent)
        }
        .searchable(text: $appModel.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add magnet link or torrent file")

                Button {
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Start selected torrent")

                Button {
                } label: {
                    Label("Stop", systemImage: "pause.fill")
                }
                .help("Stop selected torrent")

                Button(role: .destructive) {
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove selected torrent")
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
