import AppKit
import Foundation
import Observation
import TransmissionRPC
import UserNotifications

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
    var isSpeedSettingsPresented = false
    var pendingRemoval: TorrentRemovalRequest?
    var magnetLinkDraft = ""
    var addMagnetErrorMessage: String?
    var torrents: [Torrent] = Torrent.previewData
    var selectedTorrentDetails: TorrentDetails?
    var isLoadingTorrentDetails = false
    var speedLimits = SpeedLimits(
        downloadLimitKBps: 100,
        isDownloadLimitEnabled: false,
        uploadLimitKBps: 100,
        isUploadLimitEnabled: false,
        altDownloadLimitKBps: 50,
        altUploadLimitKBps: 50,
        isAltSpeedEnabled: false
    )
    private var knownCompletedTorrentIDs: Set<Torrent.ID> = []

    private var rpcClient: TransmissionRPCClient?
    private let profileStore: ConnectionProfileStore
    private let credentialStore: KeychainCredentialStore
    private let notificationCenter: UNUserNotificationCenter

    init(
        profileStore: ConnectionProfileStore = .live,
        credentialStore: KeychainCredentialStore = .live,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.profileStore = profileStore
        self.credentialStore = credentialStore
        self.notificationCenter = notificationCenter
        self.connectionProfile = profileStore.load()
        requestNotificationPermission()
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
        isConnected && selectedTorrentID != nil
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
        guard hasSavedConnection, connectionProfile.automaticallyConnect, !isConnected else {
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
            username: draft.username,
            automaticallyConnect: draft.automaticallyConnect
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
            speedLimits = SpeedLimits(session: session)
            torrents = torrentList.torrents
            knownCompletedTorrentIDs = Set(torrents.filter(\.isFinished).map(\.id))
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
            let refreshedTorrents = try await rpcClient.torrentGet().torrents
            notifyCompletedTorrentsIfNeeded(refreshedTorrents)
            torrents = refreshedTorrents
            if let selectedTorrentID, !torrents.contains(where: { $0.id == selectedTorrentID }) {
                self.selectedTorrentID = torrents.first?.id
            }
            await loadSelectedTorrentDetails()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func refreshSessionSettings() async {
        guard let rpcClient else {
            return
        }

        do {
            speedLimits = SpeedLimits(session: try await rpcClient.sessionGet())
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func applySpeedLimits(_ draft: SpeedLimits) async {
        guard let rpcClient else {
            isConnectionSettingsPresented = true
            return
        }

        do {
            try await rpcClient.sessionSet(speedLimits: draft)
            speedLimits = draft
            isSpeedSettingsPresented = false
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
        guard let selectedTorrentID else {
            return
        }

        await startTorrent(id: selectedTorrentID)
    }

    func startTorrent(id: Torrent.ID) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.startTorrent(ids: [id])
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func forceStartTorrent(id: Torrent.ID) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.forceStartTorrent(ids: [id])
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func stopSelectedTorrent() async {
        guard let selectedTorrentID else {
            return
        }

        await stopTorrent(id: selectedTorrentID)
    }

    func stopTorrent(id: Torrent.ID) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.stopTorrent(ids: [id])
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func reannounceTorrent(id: Torrent.ID) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.reannounceTorrent(ids: [id])
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func verifyTorrent(id: Torrent.ID) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.verifyTorrent(ids: [id])
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    @discardableResult
    func addMagnetLink() async -> Bool {
        let magnetLink = magnetLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return await addMagnet(magnetLink)
    }

    @discardableResult
    func addMagnet(_ magnetLink: String) async -> Bool {
        addMagnetErrorMessage = nil

        guard let rpcClient else {
            magnetLinkDraft = magnetLink
            isConnectionSettingsPresented = true
            return false
        }

        guard !magnetLink.isEmpty else {
            return false
        }

        guard let normalizedMagnetLink = MagnetLinkValidator.normalized(magnetLink) else {
            addMagnetErrorMessage = "Link not recognized. Check the link."
            return false
        }

        do {
            _ = try await rpcClient.addMagnet(normalizedMagnetLink)
            magnetLinkDraft = ""
            isAddTorrentPresented = false
            await refreshTorrents()
            return true
        } catch {
            addMagnetErrorMessage = error.localizedDescription
            return false
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

    func handleIncomingURL(_ url: URL) async {
        if url.scheme == "magnet" {
            await addMagnet(url.absoluteString)
            return
        }

        if url.isFileURL && url.pathExtension.localizedCaseInsensitiveCompare("torrent") == .orderedSame {
            await addTorrentFile(at: url)
        }
    }

    func requestRemoveSelectedTorrent(deleteLocalData: Bool = false) {
        guard let selectedTorrentID else {
            return
        }

        requestRemoveTorrent(id: selectedTorrentID, deleteLocalData: deleteLocalData)
    }

    func requestRemoveTorrent(id: Torrent.ID, deleteLocalData: Bool) {
        let torrentName = torrents.first { $0.id == id }?.name
        selectedTorrentID = id
        pendingRemoval = TorrentRemovalRequest(
            torrentIDs: [id],
            torrentName: torrentName,
            deleteLocalData: deleteLocalData
        )
    }

    func removeTorrents(for pendingRemoval: TorrentRemovalRequest) async {
        await removeTorrents(
            ids: pendingRemoval.torrentIDs,
            deleteLocalData: pendingRemoval.deleteLocalData
        )
        if self.pendingRemoval == pendingRemoval {
            self.pendingRemoval = nil
        }
    }

    private func removeTorrents(ids: [Torrent.ID], deleteLocalData: Bool) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.stopTorrent(ids: ids)
            try await rpcClient.removeTorrent(ids: ids, deleteLocalData: deleteLocalData)
            if let selectedTorrentID, ids.contains(selectedTorrentID) {
                self.selectedTorrentID = nil
            }
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func setSelectedTorrentPriority(_ priority: BandwidthPriority) async {
        guard let selectedTorrentID else {
            return
        }

        await setTorrentPriority(id: selectedTorrentID, priority: priority)
    }

    func setTorrentPriority(id: Torrent.ID, priority: BandwidthPriority) async {
        guard let rpcClient else {
            return
        }

        do {
            try await rpcClient.setTorrentPriority(id: id, priority: priority)
            selectedTorrentID = id
            await refreshTorrents()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func setTorrentFileWanted(fileID: Int, wanted: Bool) async {
        guard let selectedTorrentID, let rpcClient else {
            return
        }

        do {
            try await rpcClient.setFileWanted(torrentID: selectedTorrentID, fileIDs: [fileID], wanted: wanted)
            await loadSelectedTorrentDetails()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func setTorrentFilePriority(fileID: Int, priority: FilePriority) async {
        guard let selectedTorrentID, let rpcClient else {
            return
        }

        do {
            try await rpcClient.setFileWanted(torrentID: selectedTorrentID, fileIDs: [fileID], wanted: true)
            try await rpcClient.setFilePriority(torrentID: selectedTorrentID, fileIDs: [fileID], priority: priority)
            await loadSelectedTorrentDetails()
        } catch {
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    private func notifyCompletedTorrentsIfNeeded(_ refreshedTorrents: [Torrent]) {
        let completedTorrents = refreshedTorrents.filter(\.isFinished)
        let completedIDs = Set(completedTorrents.map(\.id))
        defer { knownCompletedTorrentIDs = completedIDs }

        guard NSApplication.shared.isActive == false else {
            return
        }

        let newlyCompletedTorrents = completedTorrents.filter { torrent in
            !knownCompletedTorrentIDs.contains(torrent.id)
        }

        for torrent in newlyCompletedTorrents {
            sendCompletionNotification(for: torrent)
        }
    }

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

    private func sendCompletionNotification(for torrent: Torrent) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = torrent.name
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "torrent-completed-\(torrent.id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request)
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(serverName: String)
    case failed(message: String)
}

enum MagnetLinkValidator {
    static func normalized(_ rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedValue = trimmedValue
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined()

        let candidates = [
            collapsedValue,
            "magnet:?\(collapsedValue.trimmingPrefix("?"))",
            "magnet:?xt=urn:btih:\(collapsedValue)"
        ]

        for candidate in candidates where isValid(candidate) {
            return candidate
        }

        return nil
    }

    private static func isValid(_ rawValue: String) -> Bool {
        guard
            let components = URLComponents(string: rawValue),
            components.scheme?.localizedCaseInsensitiveCompare("magnet") == .orderedSame,
            let queryItems = components.queryItems
        else {
            return false
        }

        return queryItems.contains { item in
            item.name.localizedCaseInsensitiveCompare("xt") == .orderedSame
                && item.value.map(isValidExactTopic) == true
        }
    }

    private static func isValidExactTopic(_ value: String) -> Bool {
        let lowercasedValue = value.lowercased()

        if lowercasedValue.hasPrefix("urn:btih:") {
            let hash = String(lowercasedValue.dropFirst("urn:btih:".count))
            return isHex(hash, length: 40) || isBase32(hash, length: 32)
        }

        if lowercasedValue.hasPrefix("urn:btmh:") {
            let hash = String(lowercasedValue.dropFirst("urn:btmh:".count))
            return hash.count >= 68 && hash.allSatisfy(\.isHexDigit)
        }

        return false
    }

    private static func isHex(_ value: String, length: Int) -> Bool {
        value.count == length && value.allSatisfy(\.isHexDigit)
    }

    private static func isBase32(_ value: String, length: Int) -> Bool {
        let alphabet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz234567")
        return value.count == length
            && value.unicodeScalars.allSatisfy { alphabet.contains($0) }
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

struct TorrentRemovalRequest: Identifiable, Equatable {
    let id = UUID()
    let torrentIDs: [Torrent.ID]
    let torrentName: String?
    let deleteLocalData: Bool

    var title: String {
        deleteLocalData ? "Remove Torrent and Data" : "Remove Torrent"
    }

    var actionTitle: String {
        deleteLocalData ? "Remove and delete data" : "Remove from list"
    }

    var message: String {
        let name = torrentName ?? "Selected torrent"
        if deleteLocalData {
            return "\(name)\n\nTorrent and downloaded data will be removed."
        }

        return "\(name)\n\nDownloaded data will remain untouched in its folder."
    }
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
