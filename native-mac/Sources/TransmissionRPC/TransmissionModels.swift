import Foundation

public struct TransmissionSession: Decodable, Equatable, Sendable {
    public let version: String?
    public let rpcVersion: Int?
    public let downloadDirectory: String?
    public let speedLimitDown: Int?
    public let speedLimitDownEnabled: Bool?
    public let speedLimitUp: Int?
    public let speedLimitUpEnabled: Bool?
    public let altSpeedDown: Int?
    public let altSpeedUp: Int?
    public let altSpeedEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case version
        case rpcVersion = "rpc-version"
        case downloadDirectory = "download-dir"
        case speedLimitDown = "speed-limit-down"
        case speedLimitDownEnabled = "speed-limit-down-enabled"
        case speedLimitUp = "speed-limit-up"
        case speedLimitUpEnabled = "speed-limit-up-enabled"
        case altSpeedDown = "alt-speed-down"
        case altSpeedUp = "alt-speed-up"
        case altSpeedEnabled = "alt-speed-enabled"
    }
}

public struct SpeedLimits: Equatable, Sendable {
    public var downloadLimitKBps: Int
    public var isDownloadLimitEnabled: Bool
    public var uploadLimitKBps: Int
    public var isUploadLimitEnabled: Bool
    public var altDownloadLimitKBps: Int
    public var altUploadLimitKBps: Int
    public var isAltSpeedEnabled: Bool

    public init(
        downloadLimitKBps: Int,
        isDownloadLimitEnabled: Bool,
        uploadLimitKBps: Int,
        isUploadLimitEnabled: Bool,
        altDownloadLimitKBps: Int,
        altUploadLimitKBps: Int,
        isAltSpeedEnabled: Bool
    ) {
        self.downloadLimitKBps = downloadLimitKBps
        self.isDownloadLimitEnabled = isDownloadLimitEnabled
        self.uploadLimitKBps = uploadLimitKBps
        self.isUploadLimitEnabled = isUploadLimitEnabled
        self.altDownloadLimitKBps = altDownloadLimitKBps
        self.altUploadLimitKBps = altUploadLimitKBps
        self.isAltSpeedEnabled = isAltSpeedEnabled
    }

    public init(session: TransmissionSession) {
        self.init(
            downloadLimitKBps: session.speedLimitDown ?? 100,
            isDownloadLimitEnabled: session.speedLimitDownEnabled ?? false,
            uploadLimitKBps: session.speedLimitUp ?? 100,
            isUploadLimitEnabled: session.speedLimitUpEnabled ?? false,
            altDownloadLimitKBps: session.altSpeedDown ?? 50,
            altUploadLimitKBps: session.altSpeedUp ?? 50,
            isAltSpeedEnabled: session.altSpeedEnabled ?? false
        )
    }
}

public struct TorrentList: Decodable, Equatable, Sendable {
    public let torrents: [Torrent]
}

public struct Torrent: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let status: TorrentStatus
    public let percentDone: Double
    public let totalSize: Int64
    public let rateDownload: Int64
    public let rateUpload: Int64
    public let eta: Int?
    public let error: Int?
    public let errorString: String?

    public var isFinished: Bool {
        percentDone >= 1
    }

    public init(
        id: Int,
        name: String,
        status: TorrentStatus,
        percentDone: Double,
        totalSize: Int64,
        rateDownload: Int64,
        rateUpload: Int64,
        eta: Int?,
        error: Int?,
        errorString: String?
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.percentDone = percentDone
        self.totalSize = totalSize
        self.rateDownload = rateDownload
        self.rateUpload = rateUpload
        self.eta = eta
        self.error = error
        self.errorString = errorString
    }
}

public enum TorrentStatus: Int, Decodable, Equatable, Sendable {
    case stopped = 0
    case checkWait = 1
    case check = 2
    case downloadWait = 3
    case download = 4
    case seedWait = 5
    case seed = 6
    case unknown = -1

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TorrentStatus(rawValue: rawValue) ?? .unknown
    }
}

public enum TorrentField: String, Sendable {
    case activityDate
    case addedDate
    case bandwidthPriority
    case dateCreated
    case downloadDir
    case downloadedEver
    case files
    case fileStats
    case id
    case leftUntilDone
    case name
    case peers
    case peersConnected
    case peersGettingFromUs
    case peersSendingToUs
    case status
    case percentDone
    case secondsDownloading
    case secondsSeeding
    case trackers
    case trackerStats
    case totalSize
    case rateDownload
    case rateUpload
    case eta
    case error
    case errorString
    case uploadedEver

    public static let defaultListFields: [TorrentField] = [
        .id,
        .name,
        .status,
        .percentDone,
        .totalSize,
        .rateDownload,
        .rateUpload,
        .eta,
        .error,
        .errorString
    ]

    public static let detailFields: [TorrentField] = [
        .id,
        .name,
        .status,
        .percentDone,
        .totalSize,
        .bandwidthPriority,
        .downloadDir,
        .downloadedEver,
        .uploadedEver,
        .leftUntilDone,
        .rateDownload,
        .rateUpload,
        .eta,
        .error,
        .errorString,
        .activityDate,
        .addedDate,
        .dateCreated,
        .secondsDownloading,
        .secondsSeeding,
        .peersConnected,
        .peersGettingFromUs,
        .peersSendingToUs,
        .trackers,
        .files,
        .fileStats,
        .trackerStats,
        .peers
    ]
}

public struct TorrentDetailsList: Decodable, Equatable, Sendable {
    public let torrents: [TorrentDetails]
}

public struct TorrentDetails: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let status: TorrentStatus
    public let percentDone: Double
    public let totalSize: Int64
    public let bandwidthPriority: BandwidthPriority
    public let downloadDir: String?
    public let downloadedEver: Int64?
    public let uploadedEver: Int64?
    public let leftUntilDone: Int64?
    public let rateDownload: Int64
    public let rateUpload: Int64
    public let eta: Int?
    public let error: Int?
    public let errorString: String?
    public let activityDate: Int?
    public let addedDate: Int?
    public let dateCreated: Int?
    public let secondsDownloading: Int?
    public let secondsSeeding: Int?
    public let peersConnected: Int?
    public let peersGettingFromUs: Int?
    public let peersSendingToUs: Int?
    public let trackers: [TorrentTracker]?
    public let files: [TorrentFile]
    public let fileStats: [TorrentFileStats]
    public let trackerStats: [TrackerStats]
    public let peers: [TorrentPeer]

    public var filesWithStats: [TorrentFileWithStats] {
        files.enumerated().map { index, file in
            TorrentFileWithStats(
                id: index,
                file: file,
                stats: fileStats.indices.contains(index) ? fileStats[index] : nil
            )
        }
    }
}

public enum BandwidthPriority: Int, CaseIterable, Decodable, Equatable, Identifiable, Sendable {
    case low = -1
    case normal = 0
    case high = 1

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low:
            "Low"
        case .normal:
            "Normal"
        case .high:
            "High"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = BandwidthPriority(rawValue: rawValue) ?? .normal
    }
}

public struct TorrentFile: Decodable, Equatable, Sendable {
    public let name: String
    public let length: Int64
    public let bytesCompleted: Int64
}

public struct TorrentFileStats: Decodable, Equatable, Sendable {
    public let bytesCompleted: Int64
    public let wanted: Bool
    public let priority: Int

    public var priorityLevel: FilePriority {
        FilePriority(rawValue: priority) ?? .normal
    }
}

public enum FilePriority: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case low = -1
    case normal = 0
    case high = 1

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low:
            "Low"
        case .normal:
            "Normal"
        case .high:
            "High"
        }
    }
}

public struct TorrentFileWithStats: Identifiable, Equatable, Sendable {
    public let id: Int
    public let file: TorrentFile
    public let stats: TorrentFileStats?

    public var progress: Double {
        guard file.length > 0 else {
            return 1
        }
        let completed = stats?.bytesCompleted ?? file.bytesCompleted
        return min(max(Double(completed) / Double(file.length), 0), 1)
    }
}

public struct TrackerStats: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let host: String?
    public let announce: String?
    public let announceState: TrackerState?
    public let scrape: String?
    public let scrapeState: TrackerState?
    public let tier: Int?
    public let hasAnnounced: Bool?
    public let hasScraped: Bool?
    public let isBackup: Bool?
    public let lastAnnouncePeerCount: Int?
    public let lastAnnounceResult: String?
    public let lastAnnounceStartTime: Int?
    public let lastAnnounceSucceeded: Bool?
    public let lastAnnounceTime: Int?
    public let lastAnnounceTimedOut: Bool?
    public let lastScrapeResult: String?
    public let lastScrapeStartTime: Int?
    public let lastScrapeSucceeded: Bool?
    public let lastScrapeTime: Int?
    public let lastScrapeTimedOut: Bool?
    public let nextAnnounceTime: Int?
    public let nextScrapeTime: Int?
    public let seederCount: Int?
    public let leecherCount: Int?
    public let downloadCount: Int?
}

public struct TorrentTracker: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let announce: String
    public let scrape: String?
    public let tier: Int?
}

public enum TrackerState: Int, Decodable, Equatable, Sendable {
    case inactive = 0
    case waiting = 1
    case queued = 2
    case active = 3
    case unknown = -1

    public var isUpdating: Bool {
        self == .queued || self == .active
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TrackerState(rawValue: rawValue) ?? .unknown
    }
}

public struct TorrentPeer: Identifiable, Decodable, Equatable, Sendable {
    public var id: String {
        "\(address):\(port ?? -1)"
    }

    public let address: String
    public let port: Int?
    public let clientName: String?
    public let flagStr: String?
    public let progress: Double?
    public let rateToClient: Int64?
    public let rateToPeer: Int64?

    enum CodingKeys: String, CodingKey {
        case address
        case port
        case clientName = "clientName"
        case flagStr
        case progress
        case rateToClient
        case rateToPeer
    }
}

public struct TorrentAddResult: Decodable, Equatable, Sendable {
    public let torrentAdded: AddedTorrent?
    public let torrentDuplicate: AddedTorrent?

    enum CodingKeys: String, CodingKey {
        case torrentAdded = "torrent-added"
        case torrentDuplicate = "torrent-duplicate"
    }
}

public struct AddedTorrent: Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let hashString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case hashString = "hashString"
    }
}
