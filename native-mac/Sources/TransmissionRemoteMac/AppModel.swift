import Foundation
import Observation
import TransmissionRPC

@Observable
final class AppModel {
    var selectedFilter: TorrentFilter = .all
    var selectedTorrentID: Torrent.ID?
    var searchText = ""
    var connectionState: ConnectionState = .disconnected
    var torrents: [Torrent] = Torrent.previewData

    var visibleTorrents: [Torrent] {
        torrents.filter { torrent in
            selectedFilter.includes(torrent)
                && (searchText.isEmpty || torrent.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var selectedTorrent: Torrent? {
        torrents.first { $0.id == selectedTorrentID }
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
