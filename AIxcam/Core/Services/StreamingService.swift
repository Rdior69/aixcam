import Foundation

struct BroadcastSession: Sendable {
    let streamID: String
    let startedAt: Date
}

enum TransportSecurityLevel: String, Sendable {
    case initializing = "INIT"
    case secure = "SECURE"
    case degraded = "DEGRADED"
}

struct StreamingInfrastructureStatus: Sendable {
    let isReady: Bool
    let securityLevel: TransportSecurityLevel
    let description: String
}

enum StreamingError: LocalizedError {
    case infrastructureNotPrepared
    case insecureIngestURL
    case disallowedHost
    case ipAddressHostBlocked
    case broadcastAlreadyActive
    case noActiveBroadcast

    var errorDescription: String? {
        switch self {
        case .infrastructureNotPrepared:
            return "Streaming infrastructure is not prepared."
        case .insecureIngestURL:
            return "Streaming ingest URL must use a secure transport (https/wss)."
        case .disallowedHost:
            return "Streaming host is not in the approved allowlist."
        case .ipAddressHostBlocked:
            return "Direct IP hosts are blocked for stream publishing."
        case .broadcastAlreadyActive:
            return "A broadcast session is already active."
        case .noActiveBroadcast:
            return "No active broadcast session was found."
        }
    }
}

struct StreamingSecurityPolicy: Sendable {
    let ingestURL: URL
    let allowedHosts: Set<String>

    static let `default` = StreamingSecurityPolicy(
        ingestURL: URL(string: "https://stream.aixlive.local/ingest")!,
        allowedHosts: ["stream.aixlive.local"]
    )

    func validate() throws {
        guard ["https", "wss"].contains(ingestURL.scheme?.lowercased() ?? "") else {
            throw StreamingError.insecureIngestURL
        }

        guard let host = ingestURL.host?.lowercased() else {
            throw StreamingError.disallowedHost
        }

        guard !Self.isIPAddress(host) else {
            throw StreamingError.ipAddressHostBlocked
        }

        guard allowedHosts.contains(host) else {
            throw StreamingError.disallowedHost
        }
    }

    private static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), (0...255).contains(value) else { return false }
            return true
        }
    }
}

protocol StreamingService: Sendable {
    func prepareInfrastructure() async throws -> StreamingInfrastructureStatus
    func startBroadcast(creatorID: String) async throws -> BroadcastSession
    func endBroadcast(streamID: String) async throws
}

private actor StreamingStateStore {
    private(set) var isPrepared = false
    private(set) var activeStreamID: String?

    func markPrepared() {
        isPrepared = true
    }

    func beginBroadcast(streamID: String) throws {
        guard isPrepared else { throw StreamingError.infrastructureNotPrepared }
        guard activeStreamID == nil else { throw StreamingError.broadcastAlreadyActive }
        activeStreamID = streamID
    }

    func endBroadcast(streamID: String) throws {
        guard let activeStreamID else { throw StreamingError.noActiveBroadcast }
        guard activeStreamID == streamID else { throw StreamingError.noActiveBroadcast }
        self.activeStreamID = nil
    }
}

struct MockStreamingService: StreamingService {
    private let policy: StreamingSecurityPolicy
    private let stateStore = StreamingStateStore()

    init(policy: StreamingSecurityPolicy = .default) {
        self.policy = policy
    }

    func prepareInfrastructure() async throws -> StreamingInfrastructureStatus {
        try policy.validate()
        try await Task.sleep(for: .milliseconds(250))
        await stateStore.markPrepared()

        return StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "Secure transport preflight passed"
        )
    }

    func startBroadcast(creatorID: String) async throws -> BroadcastSession {
        let streamID = UUID().uuidString
        try await stateStore.beginBroadcast(streamID: streamID)
        try await Task.sleep(for: .milliseconds(450))

        return BroadcastSession(streamID: streamID, startedAt: .now)
    }

    func endBroadcast(streamID: String) async throws {
        try await stateStore.endBroadcast(streamID: streamID)
        try await Task.sleep(for: .milliseconds(250))
    }
}
