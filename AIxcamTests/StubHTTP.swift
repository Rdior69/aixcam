//
//  StubHTTP.swift
//  AIxcamTests
//
//  A stubbed HTTP transport for the services that accept an injected
//  URLSession. Together with StaticAuthTokenProvider this is what makes the
//  networked services testable: request construction, HTTP status handling,
//  error mapping and response parsing can all now be executed without a
//  network and without a signed-in Firebase user.
//

import Foundation

/// Answers requests from a queue of canned responses and records what was sent.
///
/// Each instance hands out a unique host and resolves responses by that host,
/// and the services under test take their endpoint as well as their session —
/// so there is no shared mutable state between instances and suites using this
/// can still run in parallel.
final class StubHTTP {

    // MARK: - Canned responses

    struct CannedResponse {
        var statusCode: Int = 200
        var body: Data = Data()
        var error: Error?

        static func ok(json: String = "{}") -> CannedResponse {
            CannedResponse(statusCode: 200, body: Data(json.utf8))
        }

        static func status(_ code: Int, json: String = "{}") -> CannedResponse {
            CannedResponse(statusCode: code, body: Data(json.utf8))
        }

        /// A transport-level failure, i.e. what URLSession throws from.
        static func transportFailure(
            _ error: Error = URLError(.notConnectedToInternet)
        ) -> CannedResponse {
            CannedResponse(error: error)
        }
    }

    // MARK: - Captured requests

    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data?

        var bodyObject: [String: Any]? {
            guard let body,
                  let object = try? JSONSerialization.jsonObject(with: body) else { return nil }
            return object as? [String: Any]
        }

        var authorizationHeader: String? { headers["Authorization"] }

        /// The `fields` dictionary of a Firestore REST write.
        var firestoreFields: [String: Any]? {
            bodyObject?["fields"] as? [String: Any]
        }

        /// The string value of a Firestore REST field, e.g. `creatorId`.
        func firestoreString(_ key: String) -> String? {
            (firestoreFields?[key] as? [String: Any])?["stringValue"] as? String
        }
    }

    // MARK: - Channel

    /// The per-instance state, held by the registry so the `URLProtocol` (which
    /// the system instantiates itself) can reach it.
    fileprivate final class Channel: @unchecked Sendable {
        private let lock = NSLock()
        private var queued: [CannedResponse] = []
        private var captured: [CapturedRequest] = []
        /// Used when the queue runs dry, so a test only has to enqueue the
        /// responses it actually cares about.
        var fallback = CannedResponse.ok()

        func enqueue(_ response: CannedResponse) {
            lock.withLock { queued.append(response) }
        }

        func nextResponse() -> CannedResponse {
            lock.withLock { queued.isEmpty ? fallback : queued.removeFirst() }
        }

        func record(_ request: CapturedRequest) {
            lock.withLock { captured.append(request) }
        }

        var capturedRequests: [CapturedRequest] {
            lock.withLock { captured }
        }
    }

    // MARK: - Registry

    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var registry: [String: Channel] = [:]

    fileprivate static func channel(forHost host: String) -> Channel? {
        registryLock.withLock { registry[host.lowercased()] }
    }

    // MARK: - Instance

    private let channel = Channel()
    private let host: String

    /// Base URL for services that build their paths by string interpolation
    /// (`StreamHistoryService`, `FirebasePaymentBackend`).
    let baseURL: String

    /// Single endpoint for services that take one `URL`
    /// (`FirebaseLiveChannelProvider`, `FirebaseStreamCredentialsProvider`).
    var endpoint: URL { URL(string: baseURL)! }

    let session: URLSession

    init() {
        // `.invalid` is reserved by RFC 6761 and can never resolve, so a stub
        // that somehow escapes interception fails loudly instead of reaching
        // a real server.
        host = "stub-\(UUID().uuidString.lowercased()).invalid"
        baseURL = "https://\(host)/v1/documents"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)

        Self.registryLock.withLock { Self.registry[host] = channel }
    }

    deinit {
        let host = self.host
        Self.registryLock.withLock { Self.registry[host] = nil }
    }

    // MARK: - API

    /// Queues the next response. Calls are answered in the order enqueued.
    func enqueue(_ response: CannedResponse) {
        channel.enqueue(response)
    }

    /// Response used once the queue is empty. Defaults to an empty 200.
    func setFallback(_ response: CannedResponse) {
        channel.fallback = response
    }

    var capturedRequests: [CapturedRequest] { channel.capturedRequests }

    var lastRequest: CapturedRequest? { channel.capturedRequests.last }

    var requestCount: Int { channel.capturedRequests.count }
}

// MARK: - URLProtocol

/// Installed only on the sessions `StubHTTP` creates, so it can never affect
/// `URLSession.shared`.
final class StubURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return StubHTTP.channel(forHost: host) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host,
              let channel = StubHTTP.channel(forHost: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        channel.record(
            StubHTTP.CapturedRequest(
                url: url,
                method: request.httpMethod ?? "GET",
                headers: request.allHTTPHeaderFields ?? [:],
                body: Self.bodyData(from: request)
            )
        )

        let canned = channel.nextResponse()

        if let error = canned.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: canned.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: canned.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession converts `httpBody` into `httpBodyStream` before handing the
    /// request to a URLProtocol, so reading only `httpBody` would report every
    /// POST as having sent nothing.
    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
