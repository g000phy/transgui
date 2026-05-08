import Foundation

public struct TransmissionServer: Sendable, Equatable {
    public var rpcURL: URL
    public var username: String?
    public var password: String?

    public init(rpcURL: URL, username: String? = nil, password: String? = nil) {
        self.rpcURL = rpcURL
        self.username = username
        self.password = password
    }
}

public enum TransmissionRPCError: Error, Equatable {
    case invalidHTTPResponse
    case unexpectedStatusCode(Int)
    case missingSessionID
    case transmissionError(String)
}

public struct TransmissionRPCEnvelope<Arguments: Decodable>: Decodable {
    public let arguments: Arguments
    public let result: String
}

public final class TransmissionRPCClient: Sendable {
    private let server: TransmissionServer
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let sessionIDLock = NSLock()
    private nonisolated(unsafe) var sessionID: String?

    public init(server: TransmissionServer, urlSession: URLSession = .shared) {
        self.server = server
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func sessionGet() async throws -> TransmissionSession {
        try await call(method: "session-get", arguments: EmptyArguments())
    }

    public func torrentGet(fields: [TorrentField] = TorrentField.defaultListFields) async throws -> TorrentList {
        try await call(method: "torrent-get", arguments: TorrentGetArguments(fields: fields.map(\.rawValue)))
    }

    public func startTorrent(ids: [Int]) async throws {
        let _: EmptyArguments = try await call(method: "torrent-start", arguments: TorrentIDs(ids: ids))
    }

    public func stopTorrent(ids: [Int]) async throws {
        let _: EmptyArguments = try await call(method: "torrent-stop", arguments: TorrentIDs(ids: ids))
    }

    public func removeTorrent(ids: [Int], deleteLocalData: Bool) async throws {
        let arguments = TorrentRemoveArguments(ids: ids, deleteLocalData: deleteLocalData)
        let _: EmptyArguments = try await call(method: "torrent-remove", arguments: arguments)
    }

    public func addMagnet(_ magnetLink: String, downloadDirectory: String? = nil) async throws -> TorrentAddResult {
        let arguments = TorrentAddArguments(filename: magnetLink, downloadDirectory: downloadDirectory)
        return try await call(method: "torrent-add", arguments: arguments)
    }

    public func call<RequestArguments: Encodable, ResponseArguments: Decodable>(
        method: String,
        arguments: RequestArguments
    ) async throws -> ResponseArguments {
        var request = try makeRequest(method: method, arguments: arguments)
        let (data, response) = try await urlSession.data(for: request)
        let httpResponse = try castHTTPResponse(response)

        if httpResponse.statusCode == 409 {
            guard let receivedSessionID = httpResponse.value(forHTTPHeaderField: "X-Transmission-Session-Id") else {
                throw TransmissionRPCError.missingSessionID
            }
            storeSessionID(receivedSessionID)
            request = try makeRequest(method: method, arguments: arguments)
            let retry = try await urlSession.data(for: request)
            return try decodeResponse(data: retry.0, response: retry.1)
        }

        return try decodeResponse(data: data, response: httpResponse)
    }

    private func makeRequest<Arguments: Encodable>(method: String, arguments: Arguments) throws -> URLRequest {
        let body = TransmissionRPCRequest(method: method, arguments: arguments)
        var request = URLRequest(url: server.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        if let authorization = basicAuthorizationHeader(username: server.username, password: server.password) {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try encoder.encode(body)
        return request
    }

    private func decodeResponse<ResponseArguments: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> ResponseArguments {
        let httpResponse = try castHTTPResponse(response)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TransmissionRPCError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let envelope = try decoder.decode(TransmissionRPCEnvelope<ResponseArguments>.self, from: data)
        guard envelope.result == "success" else {
            throw TransmissionRPCError.transmissionError(envelope.result)
        }
        return envelope.arguments
    }

    private func castHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransmissionRPCError.invalidHTTPResponse
        }
        return httpResponse
    }

    private func storeSessionID(_ newValue: String) {
        sessionIDLock.lock()
        defer { sessionIDLock.unlock() }
        sessionID = newValue
    }

    private func basicAuthorizationHeader(username: String?, password: String?) -> String? {
        guard let username, let password else {
            return nil
        }
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            return nil
        }
        return "Basic \(data.base64EncodedString())"
    }
}

private struct TransmissionRPCRequest<Arguments: Encodable>: Encodable {
    let method: String
    let arguments: Arguments
}

private struct EmptyArguments: Codable, Equatable {
}

private struct TorrentIDs: Encodable {
    let ids: [Int]
}

private struct TorrentGetArguments: Encodable {
    let fields: [String]
}

private struct TorrentRemoveArguments: Encodable {
    let ids: [Int]
    let deleteLocalData: Bool

    enum CodingKeys: String, CodingKey {
        case ids
        case deleteLocalData = "delete-local-data"
    }
}

private struct TorrentAddArguments: Encodable {
    let filename: String
    let downloadDirectory: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case downloadDirectory = "download-dir"
    }
}
