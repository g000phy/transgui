import SwiftUI
import TransmissionRPC

struct TorrentTable: View {
    let torrents: [Torrent]
    @Binding var selectedTorrentID: Torrent.ID?
    let canRunTorrentCommand: Bool
    let start: (Torrent.ID) -> Void
    let forceStart: (Torrent.ID) -> Void
    let stop: (Torrent.ID) -> Void
    let remove: (Torrent.ID, Bool) -> Void
    let setPriority: (Torrent.ID, BandwidthPriority) -> Void
    let reannounce: (Torrent.ID) -> Void
    let verify: (Torrent.ID) -> Void

    var body: some View {
        Table(torrents, selection: $selectedTorrentID) {
            TableColumn("Name") { torrent in
                VStack(alignment: .leading, spacing: 6) {
                    Text(torrent.name)
                        .lineLimit(1)

                    ProgressView(value: torrent.percentDone)
                        .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .width(min: 180, ideal: 220, max: .infinity)

            TableColumn("Status") { torrent in
                Text(torrent.status.displayName)
                    .foregroundStyle(torrent.status == .unknown ? .secondary : .primary)
            }
            .width(min: 110, ideal: 120, max: .infinity)

            TableColumn("Down") { torrent in
                Text(ByteFormat.transferRate(torrent.rateDownload))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 100, max: .infinity)

            TableColumn("Up") { torrent in
                Text(ByteFormat.transferRate(torrent.rateUpload))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 100, max: .infinity)

            TableColumn("Size") { torrent in
                Text(ByteFormat.fileSize(torrent.totalSize))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 100, max: .infinity)
        }
        .contextMenu(forSelectionType: Torrent.ID.self) { selection in
            TorrentContextMenu(
                torrentID: selection.first ?? selectedTorrentID,
                canRunTorrentCommand: canRunTorrentCommand,
                start: start,
                forceStart: forceStart,
                stop: stop,
                remove: remove,
                setPriority: setPriority,
                reannounce: reannounce,
                verify: verify
            )
        }
    }
}

private struct TorrentContextMenu: View {
    let torrentID: Torrent.ID?
    let canRunTorrentCommand: Bool
    let start: (Torrent.ID) -> Void
    let forceStart: (Torrent.ID) -> Void
    let stop: (Torrent.ID) -> Void
    let remove: (Torrent.ID, Bool) -> Void
    let setPriority: (Torrent.ID, BandwidthPriority) -> Void
    let reannounce: (Torrent.ID) -> Void
    let verify: (Torrent.ID) -> Void

    private var canRun: Bool {
        canRunTorrentCommand && torrentID != nil
    }

    var body: some View {
        Button {
            run(start)
        } label: {
            Label("Start", systemImage: "play.circle")
        }
        .disabled(!canRun)

        Button {
            run(forceStart)
        } label: {
            Label("Force Start", systemImage: "play.circle.fill")
        }
        .disabled(!canRun)

        Button {
            run(stop)
        } label: {
            Label("Stop", systemImage: "pause.circle")
        }
        .disabled(!canRun)

        Divider()

        Button(role: .destructive) {
            run { remove($0, false) }
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .disabled(!canRun)

        Button(role: .destructive) {
            run { remove($0, true) }
        } label: {
            Label("Remove Torrent and Data", systemImage: "trash.fill")
        }
        .disabled(!canRun)

        Divider()

        Menu {
            ForEach(BandwidthPriority.allCases) { priority in
                Button {
                    run { setPriority($0, priority) }
                } label: {
                    Label(priority.title, systemImage: priority.systemImage)
                }
            }
        } label: {
            Label("Priority", systemImage: "arrow.up.arrow.down.circle")
        }
        .disabled(!canRun)

        Divider()

        Button {
            run(reannounce)
        } label: {
            Label("Reannounce", systemImage: "antenna.radiowaves.left.and.right")
        }
        .disabled(!canRun)

        Button {
            run(verify)
        } label: {
            Label("Verify", systemImage: "checkmark.seal")
        }
        .disabled(!canRun)
    }

    private func run(_ action: (Torrent.ID) -> Void) {
        guard let torrentID else {
            return
        }

        action(torrentID)
    }
}

private extension BandwidthPriority {
    var systemImage: String {
        switch self {
        case .low:
            "arrow.down.circle"
        case .normal:
            "minus.circle"
        case .high:
            "arrow.up.circle"
        }
    }
}

extension TorrentStatus {
    var displayName: String {
        switch self {
        case .stopped:
            "Stopped"
        case .checkWait:
            "Waiting check"
        case .check:
            "Checking"
        case .downloadWait:
            "Queued"
        case .download:
            "Downloading"
        case .seedWait:
            "Waiting seed"
        case .seed:
            "Seeding"
        case .unknown:
            "Unknown"
        }
    }
}

enum ByteFormat {
    static func fileSize(_ byteCount: Int64) -> String {
        fileFormatter.string(fromByteCount: byteCount)
    }

    static func transferRate(_ byteCount: Int64) -> String {
        "\(fileFormatter.string(fromByteCount: byteCount))/s"
    }

    private static var fileFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }
}
