import Foundation
import Testing
@testable import TransmissionRPC

@Suite(.serialized)
struct TransmissionRPCClientTests {
    @Test
    func retriesWithSessionIDAfterConflict() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 409,
                headers: ["X-Transmission-Session-Id": "session-123"],
                body: Data()
            ),
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {
                    "version": "4.0.6",
                    "rpc-version": 17,
                    "download-dir": "/downloads"
                  }
                }
                """.data(using: .utf8)!
            )
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        let session = try await client.sessionGet()

        #expect(session.version == "4.0.6")
        #expect(session.rpcVersion == 17)
        #expect(MockURLProtocol.requests.count == 2)
        #expect(MockURLProtocol.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id") == "session-123")
    }

    @Test
    func sendsBasicAuthHeader() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {
                    "torrents": []
                  }
                }
                """.data(using: .utf8)!
            )
        ]

        let authenticatedServer = TransmissionServer(
            rpcURL: URL(string: "http://example.test/transmission/rpc")!,
            username: "user",
            password: "pass"
        )
        let client = TransmissionRPCClient(server: authenticatedServer, urlSession: mockSession)
        let _: TorrentList = try await client.torrentGet()

        #expect(MockURLProtocol.requests.single?.value(forHTTPHeaderField: "Authorization") == "Basic dXNlcjpwYXNz")
    }

    @Test
    func decodesTorrentList() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {
                    "torrents": [
                      {
                        "id": 7,
                        "name": "Example",
                        "status": 4,
                        "percentDone": 0.5,
                        "totalSize": 2048,
                        "rateDownload": 100,
                        "rateUpload": 20,
                        "eta": 10,
                        "error": 0,
                        "errorString": ""
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            )
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        let list = try await client.torrentGet()

        #expect(list.torrents.single?.id == 7)
        #expect(list.torrents.single?.status == .download)
    }

    @Test
    func decodesTorrentDetails() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {
                    "torrents": [
                      {
                        "id": 7,
                        "name": "Example",
                        "status": 6,
                        "percentDone": 1,
                        "totalSize": 2048,
                        "bandwidthPriority": 0,
                        "downloadDir": "/downloads",
                        "downloadedEver": 2048,
                        "uploadedEver": 4096,
                        "leftUntilDone": 0,
                        "rateDownload": 0,
                        "rateUpload": 128,
                        "eta": -1,
                        "error": 0,
                        "errorString": "",
                        "activityDate": 1800000000,
                        "addedDate": 1799999900,
                        "dateCreated": 1799999800,
                        "secondsDownloading": 10,
                        "secondsSeeding": 20,
                        "peersConnected": 1,
                        "peersGettingFromUs": 0,
                        "peersSendingToUs": 1,
                        "files": [
                          {
                            "name": "example.bin",
                            "length": 2048,
                            "bytesCompleted": 2048
                          }
                        ],
                        "fileStats": [
                          {
                            "bytesCompleted": 2048,
                            "wanted": true,
                            "priority": 0
                          }
                        ],
                        "trackerStats": [
                          {
                            "id": 1,
                            "host": "tracker.example",
                            "announce": "https://tracker.example/announce",
                            "scrape": "https://tracker.example/scrape",
                            "lastAnnounceResult": "Success",
                            "lastAnnounceSucceeded": true,
                            "lastAnnounceTimedOut": false,
                            "nextAnnounceTime": 1800001000,
                            "seederCount": 12,
                            "leecherCount": 3,
                            "downloadCount": 4
                          }
                        ],
                        "peers": [
                          {
                            "address": "10.0.0.1",
                            "port": 51413,
                            "clientName": "Transmission",
                            "flagStr": "DX",
                            "progress": 1,
                            "rateToClient": 0,
                            "rateToPeer": 128
                          }
                        ]
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            )
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        let details = try await client.torrentDetails(id: 7)

        #expect(details?.downloadDir == "/downloads")
        #expect(details?.filesWithStats.single?.progress == 1)
        #expect(details?.trackerStats.single?.host == "tracker.example")
        #expect(details?.peers.single?.address == "10.0.0.1")
    }

    @Test
    func sendsTorrentFileAsMetainfo() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {
                    "torrent-added": {
                      "id": 9,
                      "name": "Example",
                      "hashString": "abc"
                    }
                  }
                }
                """.data(using: .utf8)!
            )
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        _ = try await client.addTorrentFile(data: Data("torrent bytes".utf8))

        let body = try #require(MockURLProtocol.requestBodies.single.flatMap { $0 })
        let request = try JSONDecoder().decode(TorrentAddRequest.self, from: body)
        #expect(request.method == "torrent-add")
        #expect(request.arguments.metainfo == Data("torrent bytes".utf8).base64EncodedString())
        #expect(request.arguments.filename == nil)
    }

    @Test
    func sendsSessionSpeedLimits() async throws {
        MockURLProtocol.responses = [
            MockResponse(
                statusCode: 200,
                headers: [:],
                body: """
                {
                  "result": "success",
                  "arguments": {}
                }
                """.data(using: .utf8)!
            )
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        try await client.sessionSet(
            speedLimits: SpeedLimits(
                downloadLimitKBps: 500,
                isDownloadLimitEnabled: true,
                uploadLimitKBps: 100,
                isUploadLimitEnabled: false,
                altDownloadLimitKBps: 50,
                altUploadLimitKBps: 25,
                isAltSpeedEnabled: true
            )
        )

        let body = try #require(MockURLProtocol.requestBodies.single.flatMap { $0 })
        let request = try JSONDecoder().decode(SessionSetRequest.self, from: body)
        #expect(request.method == "session-set")
        #expect(request.arguments.speedLimitDown == 500)
        #expect(request.arguments.speedLimitDownEnabled == true)
        #expect(request.arguments.speedLimitUp == 100)
        #expect(request.arguments.speedLimitUpEnabled == false)
        #expect(request.arguments.altSpeedEnabled == true)
    }

    @Test
    func sendsTorrentPriority() async throws {
        MockURLProtocol.responses = [
            successResponse()
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        try await client.setTorrentPriority(id: 7, priority: .high)

        let body = try #require(MockURLProtocol.requestBodies.single.flatMap { $0 })
        let request = try JSONDecoder().decode(TorrentSetRequest.self, from: body)
        #expect(request.method == "torrent-set")
        #expect(request.arguments.ids == [7])
        #expect(request.arguments.bandwidthPriority == 1)
    }

    @Test
    func sendsFileWantedAndPriority() async throws {
        MockURLProtocol.responses = [
            successResponse(),
            successResponse()
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        try await client.setFileWanted(torrentID: 7, fileIDs: [2], wanted: false)
        try await client.setFilePriority(torrentID: 7, fileIDs: [2], priority: .low)

        let firstBody = try #require(MockURLProtocol.requestBodies.first.flatMap { $0 })
        let secondBody = try #require(MockURLProtocol.requestBodies.dropFirst().first.flatMap { $0 })
        let wantedRequest = try JSONDecoder().decode(TorrentSetRequest.self, from: firstBody)
        let priorityRequest = try JSONDecoder().decode(TorrentSetRequest.self, from: secondBody)

        #expect(wantedRequest.arguments.filesUnwanted == [2])
        #expect(wantedRequest.arguments.filesWanted == nil)
        #expect(priorityRequest.arguments.priorityLow == [2])
    }

    @Test
    func sendsAdditionalTorrentCommands() async throws {
        MockURLProtocol.responses = [
            successResponse(),
            successResponse(),
            successResponse()
        ]

        let client = TransmissionRPCClient(server: server, urlSession: mockSession)
        try await client.forceStartTorrent(ids: [7])
        try await client.reannounceTorrent(ids: [7])
        try await client.verifyTorrent(ids: [7])

        let requests = try MockURLProtocol.requestBodies.map { body in
            try JSONDecoder().decode(TorrentIDsRequest.self, from: try #require(body))
        }

        #expect(requests.map(\.method) == ["torrent-start-now", "torrent-reannounce", "torrent-verify"])
        #expect(requests.allSatisfy { $0.arguments.ids == [7] })
    }

    private var server: TransmissionServer {
        TransmissionServer(rpcURL: URL(string: "http://example.test/transmission/rpc")!)
    }

    private var mockSession: URLSession {
        MockURLProtocol.requests = []
        MockURLProtocol.requestBodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func successResponse() -> MockResponse {
        MockResponse(
            statusCode: 200,
            headers: [:],
            body: """
            {
              "result": "success",
              "arguments": {}
            }
            """.data(using: .utf8)!
        )
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [MockResponse] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var requestBodies: [Data?] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        Self.requestBodies.append(request.bodyData)
        let response = Self.responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
    }
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let readCount = httpBodyStream.read(buffer, maxLength: bufferSize)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }

        return data
    }
}

private struct MockResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

private struct TorrentAddRequest: Decodable {
    let method: String
    let arguments: Arguments

    struct Arguments: Decodable {
        let filename: String?
        let metainfo: String?
    }
}

private struct SessionSetRequest: Decodable {
    let method: String
    let arguments: Arguments

    struct Arguments: Decodable {
        let speedLimitDown: Int
        let speedLimitDownEnabled: Bool
        let speedLimitUp: Int
        let speedLimitUpEnabled: Bool
        let altSpeedEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case speedLimitDown = "speed-limit-down"
            case speedLimitDownEnabled = "speed-limit-down-enabled"
            case speedLimitUp = "speed-limit-up"
            case speedLimitUpEnabled = "speed-limit-up-enabled"
            case altSpeedEnabled = "alt-speed-enabled"
        }
    }
}

private struct TorrentSetRequest: Decodable {
    let method: String
    let arguments: Arguments

    struct Arguments: Decodable {
        let ids: [Int]
        let bandwidthPriority: Int?
        let filesWanted: [Int]?
        let filesUnwanted: [Int]?
        let priorityLow: [Int]?

        enum CodingKeys: String, CodingKey {
            case ids
            case bandwidthPriority
            case filesWanted = "files-wanted"
            case filesUnwanted = "files-unwanted"
            case priorityLow = "priority-low"
        }
    }
}

private struct TorrentIDsRequest: Decodable {
    let method: String
    let arguments: Arguments

    struct Arguments: Decodable {
        let ids: [Int]
    }
}

private extension Collection {
    var single: Element? {
        count == 1 ? first : nil
    }
}
