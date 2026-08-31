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

enum StreamingError: LocalizedError, Equatable {
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

// Nonisolated so the policy (an immutable Sendable value) and its `default`
// can be used from any actor, including the nonisolated test target.
nonisolated struct StreamingSecurityPolicy: Sendable {
    let ingestURL: URL
    let allowedHosts: Set<String>

    static let `default`: StreamingSecurityPolicy = {
        guard let url = URL(string: "https://stream.aixcam.local/ingest") else {
            preconditionFailure("Default ingest URL literal is malformed — programmer error")
        }
        return StreamingSecurityPolicy(ingestURL: url, allowedHosts: ["stream.aixcam.local"])
    }()

    func validate() throws {
        guard ["https", "wss", "rtmps"].contains(ingestURL.scheme?.lowercased() ?? "") else {
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
    /// The IVS Chat room ARN for this channel — provided by the service to avoid
    /// callers reaching directly into IVSConfiguration (O-4 DI fix).
    var chatRoomARN: String { get }
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

// MARK: — Real IVS streaming service

/// Production StreamingService implementation backed by HaishinKit + AWS IVS.
///
/// Holds a reference to CameraManager so it can trigger RTMP connect/publish
/// on the same RTMPStream that is already attached to the camera preview.
@MainActor
final class IVSStreamingService: StreamingService {
    private let credentialsProvider: StreamCredentialsProviding
    private let cameraManager: CameraManager

    /// Credentials fetched from the backend during `prepareInfrastructure`.
    /// Never sourced from the app bundle — see `IVSConfiguration` security note.
    private var configuration: IVSConfiguration?

    init(credentialsProvider: StreamCredentialsProviding, cameraManager: CameraManager) {
        self.credentialsProvider = credentialsProvider
        self.cameraManager = cameraManager
    }

    /// Available only after `prepareInfrastructure` has fetched credentials.
    /// Empty before then; chat connect fails gracefully in that window.
    var chatRoomARN: String { configuration?.chatRoomARN ?? "" }

    func prepareInfrastructure() async throws -> StreamingInfrastructureStatus {
        // Fetch credentials from the authenticated backend. The stream key is
        // never shipped in the binary, so this network hop is mandatory.
        let configuration: IVSConfiguration
        do {
            configuration = try await credentialsProvider.fetchCredentials()
        } catch {
            return StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "Could not obtain streaming credentials — check sign-in and connectivity"
            )
        }

        // Surface a clear "not configured" state rather than crashing when the
        // backend has no channel provisioned for this creator yet.
        guard !configuration.isPlaceholder else {
            return StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "No streaming channel is provisioned for this account"
            )
        }

        // Validate the ingest URL scheme and host before attempting a connection.
        guard let url = URL(string: "rtmps://\(configuration.ingestEndpoint)") else {
            throw StreamingError.insecureIngestURL
        }
        let policy = StreamingSecurityPolicy(
            ingestURL: url,
            allowedHosts: [configuration.ingestEndpoint]
        )
        try policy.validate()

        self.configuration = configuration

        return StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "IVS endpoint validated — ready to broadcast"
        )
    }

    func startBroadcast(creatorID: String) async throws -> BroadcastSession {
        guard let configuration, !configuration.isPlaceholder else {
            throw StreamingError.infrastructureNotPrepared
        }
        try await cameraManager.startPublishing(ingestURL: configuration.rtmpsURL)
        return BroadcastSession(streamID: UUID().uuidString, startedAt: .now)
    }

    func endBroadcast(streamID: String) async throws {
        try await cameraManager.stopPublishing()
    }
}

// MARK: — Mock (kept for Xcode Previews and unit tests)

// Explicitly nonisolated: the app target defaults to main-actor isolation, but
// this mock is a Sendable value type whose state lives in an actor, so it must
// stay callable from any context (tests run off the main actor).
nonisolated struct MockStreamingService: StreamingService {
    private let policy: StreamingSecurityPolicy
    private let stateStore = StreamingStateStore()

    init(policy: StreamingSecurityPolicy = .default) {
        self.policy = policy
    }

    var chatRoomARN: String { "arn:aws:ivschat:us-east-1:000000000000:room/mock-preview" }

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
