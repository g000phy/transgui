import SwiftUI
import TransmissionRPC

struct TorrentInspector: View {
    let torrent: Torrent?
    let details: TorrentDetails?
    let isLoading: Bool
    @State private var selectedTab: InspectorTab = .info

    var body: some View {
        Group {
            if let torrent {
                VStack(spacing: 0) {
                    Picker("Inspector Section", selection: $selectedTab) {
                        ForEach(InspectorTab.allCases) { tab in
                            Text(tab.title)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    selectedContent(for: torrent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Details")
            } else {
                ContentUnavailableView("No Torrent Selected", systemImage: "tray")
            }
        }
    }

    @ViewBuilder
    private func selectedContent(for torrent: Torrent) -> some View {
        switch selectedTab {
        case .info:
            TorrentOverviewView(torrent: torrent, details: details, isLoading: isLoading)
        case .files:
            TorrentFilesView(details: details)
        case .trackers:
            TorrentTrackersView(details: details)
        case .peers:
            TorrentPeersView(details: details)
        }
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case info
    case files
    case trackers
    case peers

    var id: Self { self }

    var title: String {
        switch self {
        case .info:
            "Info"
        case .files:
            "Files"
        case .trackers:
            "Trackers"
        case .peers:
            "Peers"
        }
    }
}

private struct TorrentOverviewView: View {
    @Environment(AppModel.self) private var appModel

    let torrent: Torrent
    let details: TorrentDetails?
    let isLoading: Bool

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Name", value: torrent.name)
                LabeledContent("Status", value: torrent.status.displayName)
                LabeledContent("Progress", value: torrent.percentDone.formatted(.percent.precision(.fractionLength(0))))
                LabeledContent("Size", value: ByteFormat.fileSize(torrent.totalSize))

                if let downloadDir = details?.downloadDir {
                    LabeledContent("Location", value: downloadDir)
                }

                if let leftUntilDone = details?.leftUntilDone {
                    LabeledContent("Remaining", value: ByteFormat.fileSize(leftUntilDone))
                }
            }

            Section("Transfer") {
                LabeledContent("Download", value: ByteFormat.transferRate(torrent.rateDownload))
                LabeledContent("Upload", value: ByteFormat.transferRate(torrent.rateUpload))

                if let downloadedEver = details?.downloadedEver {
                    LabeledContent("Downloaded", value: ByteFormat.fileSize(downloadedEver))
                }

                if let uploadedEver = details?.uploadedEver {
                    LabeledContent("Uploaded", value: ByteFormat.fileSize(uploadedEver))
                }
            }

            if let details {
                Section("Priority") {
                    Picker("Bandwidth", selection: priorityBinding(for: details)) {
                        ForEach(BandwidthPriority.allCases) { priority in
                            Text(priority.title)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Peers") {
                    LabeledContent("Connected", value: (details.peersConnected ?? 0).formatted())
                    LabeledContent("Downloading from us", value: (details.peersGettingFromUs ?? 0).formatted())
                    LabeledContent("Uploading to us", value: (details.peersSendingToUs ?? 0).formatted())
                }

                Section("Dates") {
                    if let addedDate = details.addedDate {
                        LabeledContent("Added", value: DateFormat.timestamp(addedDate))
                    }

                    if let activityDate = details.activityDate {
                        LabeledContent("Last activity", value: DateFormat.timestamp(activityDate))
                    }

                    if let dateCreated = details.dateCreated, dateCreated > 0 {
                        LabeledContent("Created", value: DateFormat.timestamp(dateCreated))
                    }
                }
            }

            if isLoading {
                Section {
                    ProgressView()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func priorityBinding(for details: TorrentDetails) -> Binding<BandwidthPriority> {
        Binding(
            get: {
                details.bandwidthPriority
            },
            set: { priority in
                Task {
                    await appModel.setSelectedTorrentPriority(priority)
                }
            }
        )
    }
}

private struct TorrentFilesView: View {
    @Environment(AppModel.self) private var appModel

    let details: TorrentDetails?

    var body: some View {
        if let details, !details.filesWithStats.isEmpty {
            Table(details.filesWithStats) {
                TableColumn("Name") { file in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.file.name)
                            .lineLimit(1)

                        ProgressView(value: file.progress)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }

                TableColumn("Size") { file in
                    Text(ByteFormat.fileSize(file.file.length))
                        .monospacedDigit()
                }
                .width(min: 86, ideal: 104)

                TableColumn("Wanted") { file in
                    Button {
                        Task {
                            await appModel.setTorrentFileWanted(
                                fileID: file.id,
                                wanted: !(file.stats?.wanted ?? true)
                            )
                        }
                    } label: {
                        Image(systemName: file.stats?.wanted == false ? "minus.circle" : "checkmark.circle")
                            .foregroundStyle(file.stats?.wanted == false ? Color.secondary : Color.green)
                    }
                    .buttonStyle(.plain)
                    .help(file.stats?.wanted == false ? "Download this file" : "Skip this file")
                }
                .width(70)

                TableColumn("Priority") { file in
                    let isWanted = file.stats?.wanted ?? true

                    Menu {
                        Button {
                            Task {
                                await appModel.setTorrentFileWanted(fileID: file.id, wanted: false)
                            }
                        } label: {
                            if !isWanted {
                                Label("Don't Download", systemImage: "checkmark")
                            } else {
                                Text("Don't Download")
                            }
                        }

                        Divider()

                        ForEach(FilePriority.allCases) { priority in
                            Button {
                                Task {
                                    await appModel.setTorrentFilePriority(fileID: file.id, priority: priority)
                                }
                            } label: {
                                if isWanted && file.stats?.priorityLevel == priority {
                                    Label(priority.title, systemImage: "checkmark")
                                } else {
                                    Text(priority.title)
                                }
                            }
                        }
                    } label: {
                        Text(isWanted ? file.stats?.priorityLevel.title ?? "Normal" : "Don't Download")
                    }
                    .menuStyle(.button)
                    .controlSize(.small)
                }
                .width(min: 92, ideal: 110)
            }
        } else {
            ContentUnavailableView("No Files", systemImage: "doc.on.doc")
        }
    }
}

private struct TorrentTrackersView: View {
    let details: TorrentDetails?

    var body: some View {
        let rows = details.map(TrackerDisplayRow.rows) ?? []

        if !rows.isEmpty {
            Table(rows) {
                TableColumn("Name") { row in
                    Text(row.name)
                        .lineLimit(1)
                }

                TableColumn("Status") { row in
                    Text(row.status)
                        .foregroundStyle(row.isError ? .red : .primary)
                        .lineLimit(1)
                }
                .width(min: 110, ideal: 150)

                TableColumn("Update in") { row in
                    Text(row.updateIn)
                        .monospacedDigit()
                }
                .width(min: 100, ideal: 120)

                TableColumn("Seeds") { row in
                    Text(row.seeds)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 80)
            }
        } else {
            ContentUnavailableView("No Trackers", systemImage: "antenna.radiowaves.left.and.right")
        }
    }
}

private struct TrackerDisplayRow: Identifiable {
    let id: Int
    let name: String
    let status: String
    let updateIn: String
    let seeds: String
    let isError: Bool

    static func rows(_ details: TorrentDetails) -> [TrackerDisplayRow] {
        if let trackers = details.trackers, !trackers.isEmpty {
            return trackers.enumerated().map { index, tracker in
                let stats = details.trackerStats.first { $0.id == tracker.id }
                    ?? details.trackerStats[safe: index]
                return TrackerDisplayRow(tracker: tracker, stats: stats, fallbackID: index)
            }
        }

        return details.trackerStats.enumerated().map { index, stats in
            TrackerDisplayRow(tracker: nil, stats: stats, fallbackID: index)
        }
    }

    private init(tracker: TorrentTracker?, stats: TrackerStats?, fallbackID: Int) {
        self.id = tracker?.id ?? stats?.id ?? fallbackID
        self.name = tracker?.announce ?? stats?.announce ?? stats?.host ?? "Tracker"
        self.status = Self.status(for: stats)
        self.updateIn = Self.updateIn(for: stats)
        self.seeds = Self.count(stats?.seederCount)
        self.isError = Self.isError(stats)
    }

    private static func status(for stats: TrackerStats?) -> String {
        guard let stats else {
            return ""
        }

        if stats.announceState?.isUpdating == true {
            return "Updating"
        }

        if stats.hasAnnounced == true || stats.lastAnnounceResult != nil {
            if stats.lastAnnounceSucceeded == true || stats.lastAnnounceResult == "Success" {
                return "Working"
            }

            if let result = stats.lastAnnounceResult, !result.isEmpty {
                return result
            }
        }

        return ""
    }

    private static func updateIn(for stats: TrackerStats?) -> String {
        guard let stats else {
            return ""
        }

        if stats.announceState?.isUpdating == true {
            return "Updating..."
        }

        guard let nextAnnounceTime = stats.nextAnnounceTime, nextAnnounceTime > 1 else {
            return ""
        }

        let remainingSeconds = max(0, nextAnnounceTime - Int(Date().timeIntervalSince1970))
        return DateFormat.duration(seconds: remainingSeconds)
    }

    private static func count(_ value: Int?) -> String {
        guard let value, value >= 0 else {
            return ""
        }

        return value.formatted()
    }

    private static func isError(_ stats: TrackerStats?) -> Bool {
        guard let stats else {
            return false
        }

        return stats.hasAnnounced == true
            && stats.lastAnnounceSucceeded == false
            && stats.announceState?.isUpdating != true
    }
}

private struct TorrentPeersView: View {
    let details: TorrentDetails?

    var body: some View {
        if let details, !details.peers.isEmpty {
            Table(details.peers) {
                TableColumn("Address") { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(peer.address)
                            .lineLimit(1)

                        if let clientName = peer.clientName, !clientName.isEmpty {
                            Text(clientName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }

                TableColumn("Progress") { peer in
                    Text((peer.progress ?? 0).formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }
                .width(min: 76, ideal: 90)

                TableColumn("Down") { peer in
                    Text(ByteFormat.transferRate(peer.rateToClient ?? 0))
                        .monospacedDigit()
                }
                .width(min: 86, ideal: 100)

                TableColumn("Up") { peer in
                    Text(ByteFormat.transferRate(peer.rateToPeer ?? 0))
                        .monospacedDigit()
                }
                .width(min: 86, ideal: 100)
            }
        } else {
            ContentUnavailableView("No Peers", systemImage: "person.2")
        }
    }
}

private enum DateFormat {
    static func timestamp(_ timestamp: Int) -> String {
        guard timestamp > 0 else {
            return "Never"
        }

        return Date(timeIntervalSince1970: TimeInterval(timestamp))
            .formatted(date: .abbreviated, time: .shortened)
    }

    static func duration(seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return "\(hours)h, \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m, \(seconds)s"
        }

        return "\(seconds)s"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
