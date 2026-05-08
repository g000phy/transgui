import SwiftUI
import TransmissionRPC

struct TorrentTable: View {
    let torrents: [Torrent]
    @Binding var selectedTorrentID: Torrent.ID?

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

            TableColumn("Status") { torrent in
                Text(torrent.status.displayName)
                    .foregroundStyle(torrent.status == .unknown ? .secondary : .primary)
            }
            .width(min: 110, ideal: 130)

            TableColumn("Down") { torrent in
                Text(ByteFormat.transferRate(torrent.rateDownload))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)

            TableColumn("Up") { torrent in
                Text(ByteFormat.transferRate(torrent.rateUpload))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)

            TableColumn("Size") { torrent in
                Text(ByteFormat.fileSize(torrent.totalSize))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)
        }
    }
}

private extension TorrentStatus {
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
