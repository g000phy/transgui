import Foundation

public struct TransmissionSession: Decodable, Equatable, Sendable {
    public let version: String?
    public let rpcVersion: Int?
    public let downloadDirectory: String?

    enum CodingKeys: String, CodingKey {
        case version
        case rpcVersion = "rpc-version"
        case downloadDirectory = "download-dir"
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
    case id
    case name
    case status
    case percentDone
    case totalSize
    case rateDownload
    case rateUpload
    case eta
    case error
    case errorString

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
