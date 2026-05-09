import SwiftUI
import TransmissionRPC
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isTorrentFileImporterPresented = false

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
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: .infinity)
        } detail: {
            VSplitView {
                TorrentTable(
                    torrents: appModel.visibleTorrents,
                    selectedTorrentID: $appModel.selectedTorrentID,
                    canRunTorrentCommand: appModel.isConnected,
                    start: { id in Task { await appModel.startTorrent(id: id) } },
                    forceStart: { id in Task { await appModel.forceStartTorrent(id: id) } },
                    stop: { id in Task { await appModel.stopTorrent(id: id) } },
                    remove: { id, deleteLocalData in
                        appModel.requestRemoveTorrent(id: id, deleteLocalData: deleteLocalData)
                    },
                    setPriority: { id, priority in
                        Task { await appModel.setTorrentPriority(id: id, priority: priority) }
                    },
                    reannounce: { id in Task { await appModel.reannounceTorrent(id: id) } },
                    verify: { id in Task { await appModel.verifyTorrent(id: id) } }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 260)

                TorrentInspector(
                    torrent: appModel.selectedTorrent,
                    details: appModel.selectedTorrentDetails,
                    isLoading: appModel.isLoadingTorrentDetails
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 220, idealHeight: 320)
            }
            .navigationTitle(appModel.selectedFilter.title)
            .navigationSplitViewColumnWidth(min: 760, ideal: 1_240, max: .infinity)
        }
        .task(id: appModel.selectedTorrentID) {
            await appModel.loadSelectedTorrentDetails()
        }
        .task {
            await appModel.connectToSavedProfileIfAvailable()
            await appModel.runAutoRefreshLoop()
        }
        .onOpenURL { url in
            Task {
                await appModel.handleIncomingURL(url)
            }
        }
        .searchable(text: $appModel.searchText, placement: .toolbar)
        .background(WindowIconInstaller().frame(width: 0, height: 0))
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
        .sheet(isPresented: $appModel.isSpeedSettingsPresented) {
            SpeedSettingsView(draft: appModel.speedLimits)
                .environment(appModel)
        }
        .fileImporter(
            isPresented: $isTorrentFileImporterPresented,
            allowedContentTypes: [.torrentFile],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    await appModel.addTorrentFile(at: url)
                }
            }
        }
        .confirmationDialog(
            appModel.pendingRemoval?.title ?? "Remove Torrent",
            isPresented: Binding(
                get: { appModel.pendingRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.pendingRemoval = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingRemoval = appModel.pendingRemoval {
                Button(pendingRemoval.actionTitle, role: .destructive) {
                    Task { await appModel.removeTorrents(for: pendingRemoval) }
                }
            }

            Button("Cancel", role: .cancel) {
                appModel.pendingRemoval = nil
            }
        } message: {
            if let pendingRemoval = appModel.pendingRemoval {
                Text(pendingRemoval.message)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appModel.isConnectionSettingsPresented = true
                } label: {
                    ConnectionToolbarLabel(state: appModel.connectionState)
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

                Menu {
                    Button {
                        appModel.isAddTorrentPresented = true
                    } label: {
                        Label("Magnet Link", systemImage: "link")
                    }

                    Button {
                        isTorrentFileImporterPresented = true
                    } label: {
                        Label("Torrent File", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.button)
                .help("Add magnet link or torrent file")
                .disabled(!appModel.isConnected)

                Button {
                    Task { await appModel.refreshSessionSettings() }
                    appModel.isSpeedSettingsPresented = true
                } label: {
                    Label("Speed Limits", systemImage: "gauge.with.dots.needle.67percent")
                }
                .help("Configure global speed limits")
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
                    appModel.requestRemoveSelectedTorrent()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove selected torrent")
                .disabled(!appModel.canRunTorrentCommand)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}

private struct ConnectionToolbarLabel: View {
    let state: ConnectionState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "network")
                .font(.title3)
                .frame(width: 24, height: 24)

            Image(systemName: badgeSystemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badgeColor)
                .background(.background, in: Circle())
                .offset(x: 2, y: 2)
        }
        .accessibilityLabel("Connection")
        .accessibilityValue(accessibilityValue)
    }

    private var badgeSystemImage: String {
        switch state {
        case .connected:
            "checkmark.circle.fill"
        case .failed:
            "xmark.circle.fill"
        case .connecting:
            "ellipsis.circle.fill"
        case .disconnected:
            "circle.fill"
        }
    }

    private var badgeColor: Color {
        switch state {
        case .connected:
            .green
        case .failed:
            .red
        case .connecting:
            .secondary
        case .disconnected:
            .secondary
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .connected(let serverName):
            "Connected to \(serverName)"
        case .failed(let message):
            "Connection error: \(message)"
        case .connecting:
            "Connecting"
        case .disconnected:
            "Disconnected"
        }
    }
}

private extension UTType {
    static let torrentFile = UTType(filenameExtension: "torrent") ?? .data
}
