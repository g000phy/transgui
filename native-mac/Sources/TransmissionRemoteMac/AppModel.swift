import Foundation
import Observation
import TransmissionRPC

@MainActor
@Observable
final class AppModel {
    var selectedFilter: TorrentFilter = .all
    var selectedTorrentID: Torrent.ID?
    var searchText = ""
    var connectionState: ConnectionState = .disconnected
    var connectionProfile: ConnectionProfile
    var isConnectionSettingsPresented = false
    var isAddTorrentPresented = false
    var isRemoveConfirmationPresented = false
    var magnetLinkDraft = ""
    var torrents: [Torrent] = Torrent.previewData
    var selectedTorrentDetails: TorrentDetails?
    var isLoadingTorrentDetails = false

    private var rpcClient: TransmissionRPCClient?
    private let profileStore: ConnectionProfileStore
    private let credentialStore: KeychainCredentialStore

    init(
        profileStore: ConnectionProfileStore = .live,
        credentialStore: KeychainCredentialStore = .live
    ) {
        self.profileStore = profileStore
        self.credentialStore = credentialStore
        self.connectionProfile = profileStore.load()
    }

    var visibleTorrents: [Torrent] {
        torrents.filter { torrent in
            selectedFilter.includes(torrent)
                && (searchText.isEmpty || torrent.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var selectedTorrent: Torrent? {
        torrents.first { $0.id == selectedTorrentID }
    }

    var canRunTorrentCommand: Bool {
        rpcClient != nil && selectedTorrentID != nil
    }

    var hasSavedConnection: Bool {
        connectionProfile != .empty
    }

    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }

    func savedPassword() -> String {
        guard !connectionProfile.username.isEmpty else {
            return ""
        }

        return (try? credentialStore.password(for: connectionProfile.keychainAccount)) ?? ""
    }

    func connectToSavedProfileIfAvailable() async {
        guard hasSavedConnection, !isConnected else {
            return
        }

        await connect(
            using: ConnectionDraft(
                profile: connectionProfile,
                password: savedPassword()
            )
        )
    }

    func runAutoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))

            guard isConnected else {
                continue
            }

            await refreshTorrents(presentConnectionSettings: false)
        }
    }

    func connect(using draft: ConnectionDraft) async {
        guard let rpcURL = URL(string: draft.rpcURLString), rpcURL.scheme != nil, rpcURL.host != nil else {
            connectionState = .failed(message: "Enter a valid RPC URL")
            return
        }

        let profile = ConnectionProfile(
            rpcURLString: draft.rpcURLString,
            username: draft.username
        )

        connectionState = .connecting
        connectionProfile = profile

        do {
            try profileStore.save(profile)
            if !profile.username.isEmpty || !draft.password.isEmpty {
                try credentialStore.savePassword(draft.password, for: profile.keychainAccount)
            }

            let server = TransmissionServer(
                rpcURL: rpcURL,
                username: profile.username.nilIfEmpty,
                password: draft.password.nilIfEmpty
            )
            let client = TransmissionRPCClient(server: server)
            let session = try await client.sessionGet()
            let torrentList = try await client.torrentGet()

            rpcClient = client
            torrents = torrentList.torrents
            selectedTorrentDetails = nil
            selectedTorrentID = torrents.first?.id
            connectionState = .connected(serverName: session.version ?? rpcURL.host ?? "Transmission")
            await loadSelectedTorrentDetails()
        } catch {
            rpcClient = nil
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func refreshTorrents(presentConnectionSettings: Bool = true) async {
        guard let rpcClient else {
            if presentConnectionSettings {
                isConnectionSettingsPresented = true
            }
            return
        }

        do {
            torrents = try await rpcClient.torrentGet().torrents
            if let selectedTorrentID, !torrents.contains(where: { $0.id == selectedTorrentID }) {
                self.selectedTorrentID = torrents.first?.id
            }
            await loadSelectedTorrentDetails()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func loadSelectedTorrentDetails() async {
        guard let selectedTorrentID, let rpcClient else {
            selectedTorrentDetails = nil
            return
        }

        isLoadingTorrentDetails = true
        defer { isLoadingTorrentDetails = false }

        do {
            selectedTorrentDetails = try await rpcClient.torrentDetails(id: selectedTorrentID)
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func startSelectedTorrent() async {
        guard let selectedTorrentID, let rpcClient else {
            return
        }

        do {
            try await rpcClient.startTorrent(ids: [selectedTorrentID])
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func stopSelectedTorrent() async {
        guard let selectedTorrentID, let rpcClient else {
            return
        }

        do {
            try await rpcClient.stopTorrent(ids: [selectedTorrentID])
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func addMagnetLink() async {
        guard let rpcClient else {
            isConnectionSettingsPresented = true
            return
        }

        let magnetLink = magnetLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !magnetLink.isEmpty else {
            return
        }

        do {
            _ = try await rpcClient.addMagnet(magnetLink)
            magnetLinkDraft = ""
            isAddTorrentPresented = false
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func addTorrentFile(at url: URL) async {
        guard let rpcClient else {
            isConnectionSettingsPresented = true
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            _ = try await rpcClient.addTorrentFile(data: data)
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func removeSelectedTorrent(deleteLocalData: Bool = false) async {
        guard let selectedTorrentID, let rpcClient else {
            return
        }

        do {
            try await rpcClient.removeTorrent(ids: [selectedTorrentID], deleteLocalData: deleteLocalData)
            self.selectedTorrentID = nil
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(serverName: String)
    case failed(message: String)
}

enum TorrentFilter: String, CaseIterable, Identifiable {
    case all
    case downloading
    case completed
    case active
    case stopped
    case error

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All"
        case .downloading:
            "Downloading"
        case .completed:
            "Completed"
        case .active:
            "Active"
        case .stopped:
            "Stopped"
        case .error:
            "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "tray.full"
        case .downloading:
            "arrow.down.circle"
        case .completed:
            "checkmark.circle"
        case .active:
            "bolt.circle"
        case .stopped:
            "pause.circle"
        case .error:
            "exclamationmark.triangle"
        }
    }

    func includes(_ torrent: Torrent) -> Bool {
        switch self {
        case .all:
            true
        case .downloading:
            torrent.status == .download || torrent.status == .downloadWait
        case .completed:
            torrent.isFinished
        case .active:
            torrent.rateDownload > 0 || torrent.rateUpload > 0
        case .stopped:
            torrent.status == .stopped
        case .error:
            (torrent.error ?? 0) != 0
        }
    }
}

extension Torrent {
    static let previewData: [Torrent] = [
        Torrent(
            id: 1,
            name: "Ubuntu 26.04 Desktop ARM64",
            status: .download,
            percentDone: 0.42,
            totalSize: 5_200_000_000,
            rateDownload: 12_400_000,
            rateUpload: 380_000,
            eta: 940,
            error: 0,
            errorString: ""
        ),
        Torrent(
            id: 2,
            name: "Archive backup",
            status: .seed,
            percentDone: 1,
            totalSize: 24_000_000_000,
            rateDownload: 0,
            rateUpload: 1_200_000,
            eta: -1,
            error: 0,
            errorString: ""
        ),
        Torrent(
            id: 3,
            name: "Test magnet item",
            status: .stopped,
            percentDone: 0.07,
            totalSize: 1_700_000_000,
            rateDownload: 0,
            rateUpload: 0,
            eta: -1,
            error: 0,
            errorString: ""
        )
    ]
}
