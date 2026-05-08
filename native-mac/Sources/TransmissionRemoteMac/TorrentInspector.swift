import SwiftUI
import TransmissionRPC

struct TorrentInspector: View {
    let torrent: Torrent?
    let details: TorrentDetails?
    let isLoading: Bool

    var body: some View {
        Group {
            if let torrent {
                TabView {
                    TorrentOverviewView(torrent: torrent, details: details, isLoading: isLoading)
                        .tabItem {
                            Label("Info", systemImage: "info.circle")
                        }

                    TorrentFilesView(details: details)
                        .tabItem {
                            Label("Files", systemImage: "doc.on.doc")
                        }

                    TorrentTrackersView(details: details)
                        .tabItem {
                            Label("Trackers", systemImage: "antenna.radiowaves.left.and.right")
                        }

                    TorrentPeersView(details: details)
                        .tabItem {
                            Label("Peers", systemImage: "person.2")
                        }
                }
                .navigationTitle("Details")
            } else {
                ContentUnavailableView("No Torrent Selected", systemImage: "tray")
            }
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
                    Menu {
                        ForEach(FilePriority.allCases) { priority in
                            Button {
                                Task {
                                    await appModel.setTorrentFilePriority(fileID: file.id, priority: priority)
                                }
                            } label: {
                                if file.stats?.priorityLevel == priority {
                                    Label(priority.title, systemImage: "checkmark")
                                } else {
                                    Text(priority.title)
                                }
                            }
                        }
                    } label: {
                        Text(file.stats?.priorityLevel.title ?? "Unknown")
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
        if let details, !details.trackerStats.isEmpty {
            Table(details.trackerStats) {
                TableColumn("Host") { tracker in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tracker.host ?? tracker.announce ?? "Tracker")
                            .lineLimit(1)

                        if let result = tracker.lastAnnounceResult, !result.isEmpty {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }

                TableColumn("Seeders") { tracker in
                    Text(trackerCount(tracker.seederCount))
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)

                TableColumn("Leechers") { tracker in
                    Text(trackerCount(tracker.leecherCount))
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)
            }
        } else {
            ContentUnavailableView("No Trackers", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    private func trackerCount(_ value: Int?) -> String {
        guard let value, value >= 0 else {
            return "Unknown"
        }
        return value.formatted()
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
}
