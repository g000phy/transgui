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

    private var server: TransmissionServer {
        TransmissionServer(rpcURL: URL(string: "http://example.test/transmission/rpc")!)
    }

    private var mockSession: URLSession {
        MockURLProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [MockResponse] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
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

private struct MockResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

private extension Collection {
    var single: Element? {
        count == 1 ? first : nil
    }
}
