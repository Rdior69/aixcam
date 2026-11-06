import Foundation

// Nonisolated so these immutable results can be inspected from any actor. The
// app target defaults to main-actor isolation, which would otherwise confine
// their stored properties to the main actor even though the values are Sendable.
nonisolated struct BroadcastSession: Sendable {
    let streamID: String
    let startedAt: Date
}

enum TransportSecurityLevel: String, Sendable {
    case initializing = "INIT"
    case secure = "SECURE"
    case degraded = "DEGRADED"
}

nonisolated struct StreamingInfrastructureStatus: Sendable {
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
            return String(localized: "Streaming infrastructure is not prepared.")
        case .insecureIngestURL:
            return String(localized: "Streaming ingest URL must use a secure transport (https/wss).")
        case .disallowedHost:
            return String(localized: "Streaming host is not in the approved allowlist.")
        case .ipAddressHostBlocked:
            return String(localized: "Direct IP hosts are blocked for stream publishing.")
        case .broadcastAlreadyActive:
            return String(localized: "A broadcast session is already active.")
        case .noActiveBroadcast:
            return String(localized: "No active broadcast session was found.")
        }
    }
}

// Nonisolated so the policy (an immutable Sendable value) and its `default`
// can be used from any actor, including the nonisolated test target.
nonisolated struct StreamingSecurityPolicy: Sendable {
    let ingestURL: URL
    let allowedHosts: Set<String>

    /// Ingest hosts this app will publish to.
    ///
    /// This list used to be derived from the very URL being validated, which
    /// made `disallowedHost` unreachable — the check could not fail. Pinning it
    /// to a constant means a compromised or misconfigured backend cannot
    /// redirect a creator's camera feed to an arbitrary host. Add an entry here
    /// when adding a streaming provider; that is deliberately a code change.
    static let allowedIngestHosts: Set<String> = ["live.cloudflare.com"]

    static let `default`: StreamingSecurityPolicy = {
        guard let url = URL(string: "rtmps://live.cloudflare.com:443/live/preview") else {
            preconditionFailure("Default ingest URL literal is malformed — programmer error")
        }
        return StreamingSecurityPolicy(ingestURL: url, allowedHosts: allowedIngestHosts)
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

protocol StreamingServicing: Sendable {
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

// MARK: — Real streaming service

/// Production StreamingServicing implementation backed by HaishinKit, publishing
/// RTMPS to whichever provider the backend hands back credentials for.
///
/// Holds a reference to CameraManager so it can trigger RTMP connect/publish
/// on the same RTMPStream that is already attached to the camera preview.
@MainActor
final class LiveStreamingService: StreamingServicing {
    private let credentialsProvider: StreamCredentialsProviding
    private let cameraManager: CameraManager

    /// Credentials fetched from the backend during `prepareInfrastructure`.
    /// Never sourced from the app bundle — see `StreamCredentials` security note.
    private var credentials: StreamCredentials?

    init(credentialsProvider: StreamCredentialsProviding, cameraManager: CameraManager) {
        self.credentialsProvider = credentialsProvider
        self.cameraManager = cameraManager
    }

    func prepareInfrastructure() async throws -> StreamingInfrastructureStatus {
        // Fetch credentials from the authenticated backend. The stream key is
        // never shipped in the binary, so this network hop is mandatory.
        let fetched: StreamCredentials
        do {
            fetched = try await credentialsProvider.fetchCredentials()
        } catch {
            return StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "Could not obtain streaming credentials — check sign-in and connectivity"
            )
        }

        // Surface a clear "not configured" state rather than crashing when the
        // backend has no channel provisioned for this creator yet.
        guard !fetched.isPlaceholder else {
            return StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "No streaming channel is provisioned for this account"
            )
        }

        // Validate the backend's URL as given. It arrives complete (scheme,
        // host, stream key) so there is nothing to compose — only to check.
        guard let url = URL(string: fetched.ingestURL) else {
            throw StreamingError.insecureIngestURL
        }
        try StreamingSecurityPolicy(
            ingestURL: url,
            allowedHosts: StreamingSecurityPolicy.allowedIngestHosts
        ).validate()

        self.credentials = fetched

        return StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "Ingest endpoint validated — ready to broadcast"
        )
    }

    func startBroadcast(creatorID: String) async throws -> BroadcastSession {
        guard let credentials, !credentials.isPlaceholder else {
            throw StreamingError.infrastructureNotPrepared
        }
        try await cameraManager.startPublishing(ingestURL: credentials.ingestURL)
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
nonisolated struct MockStreamingService: StreamingServicing {
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
