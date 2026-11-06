import Foundation
import Observation

/// A creator who is live right now, as projected by the backend for the
/// viewer-side Discover feed.
///
/// Deliberately narrow. The underlying `streams/{id}` documents are readable
/// only by their owning creator, and `creatorChannels/{uid}` (which holds the
/// RTMP stream key) is closed to clients entirely — so this is assembled
/// server-side and only the watchable facts cross the wire.
nonisolated struct LiveChannel: Identifiable, Sendable, Equatable {
    let streamID: String
    let creatorID: String
    let displayName: String
    let startedAt: Date?
    /// Public HLS URL. Not secret: it is how anyone watches the channel.
    let playbackURL: URL

    var id: String { streamID }

    /// Falls back rather than rendering an empty row when a creator has no
    /// profile name yet.
    var title: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Live creator"
            : displayName
    }
}

enum LiveChannelError: LocalizedError {
    case notAuthenticated
    case requestFailed(statusCode: Int)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "Sign in to see who's live.")
        case .requestFailed(let code):
            return String(localized: "The discovery service returned an error (\(code)).")
        case .decodingFailed:
            return String(localized: "We couldn’t read the discovery service response.")
        case .network(let error):
            // Through AppError rather than `localizedDescription`, so a
            // transport failure reads as "you appear to be offline" instead of
            // a raw NSError domain and code.
            return AppError(error).message
        }
    }
}

/// Abstracted so previews and tests can supply channels without a network call.
protocol LiveChannelProviding: Sendable {
    func fetchLiveChannels() async throws -> [LiveChannel]
}

/// Fetches the live feed from the `listLiveChannels` Cloud Function.
nonisolated final class FirebaseLiveChannelProvider: LiveChannelProviding {

    private let endpoint: URL
    private let session: URLSession
    private let authTokenProvider: AuthTokenProviding

    init(
        endpoint: URL = URL(string: "https://us-central1-aixcam.cloudfunctions.net/listLiveChannels")!,
        session: URLSession = .shared,
        authTokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func fetchLiveChannels() async throws -> [LiveChannel] {
        guard let idToken = await authTokenProvider.currentIDToken() else {
            throw LiveChannelError.notAuthenticated
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": [:]])
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LiveChannelError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LiveChannelError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LiveChannelError.requestFailed(statusCode: http.statusCode)
        }

        return try LiveChannelDecoding.channels(from: data)
    }
}

/// Wire decoding, split out so it can be tested without a network stack.
nonisolated enum LiveChannelDecoding {

    private struct Envelope: Decodable {
        struct Result: Decodable {
            let channels: [ChannelDTO]
        }
        let result: Result
    }

    private struct ChannelDTO: Decodable {
        let streamID: String
        let creatorID: String
        let displayName: String?
        let startedAt: String?
        let playbackURL: String

        // The wire keys are lowerCamelCase with an `Id` suffix; the Swift
        // properties use `ID` to match the rest of the codebase. Same reason
        // `ConnectedAccount` spells its keys out explicitly.
        enum CodingKeys: String, CodingKey {
            case streamID = "streamId"
            case creatorID = "creatorId"
            case displayName
            case startedAt
            case playbackURL
        }
    }

    /// Entries without a usable playback URL are dropped rather than surfaced
    /// as rows that fail on tap. A malformed *entry* should not fail the whole
    /// feed, but malformed *JSON* still throws.
    static func channels(from data: Data) throws -> [LiveChannel] {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw LiveChannelError.decodingFailed
        }

        return envelope.result.channels.compactMap { dto in
            guard !dto.streamID.isEmpty,
                  !dto.creatorID.isEmpty,
                  let url = URL(string: dto.playbackURL),
                  let scheme = url.scheme?.lowercased(),
                  // Playback must not be plaintext; an http:// URL here would
                  // downgrade the viewer's connection.
                  scheme == "https"
            else { return nil }

            return LiveChannel(
                streamID: dto.streamID,
                creatorID: dto.creatorID,
                displayName: dto.displayName ?? "",
                startedAt: dto.startedAt.flatMap(parseDate),
                playbackURL: url
            )
        }
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Node's toISOString() emits fractional seconds; the plain parser is the
    /// fallback for anything that doesn't.
    static func parseDate(_ string: String) -> Date? {
        isoWithFraction.date(from: string) ?? isoPlain.date(from: string)
    }
}

/// Static provider for Xcode Previews and unit tests — no network.
nonisolated struct StaticLiveChannelProvider: LiveChannelProviding {
    let channels: [LiveChannel]
    let error: (any Error)?

    init(channels: [LiveChannel] = [], error: (any Error)? = nil) {
        self.channels = channels
        self.error = error
    }

    func fetchLiveChannels() async throws -> [LiveChannel] {
        if let error { throw error }
        return channels
    }
}

/// Observable feed backing Discover.
@Observable
@MainActor
final class LiveChannelService {

    private(set) var channels: [LiveChannel] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// True once a fetch has completed, so the UI can tell "nobody is live"
    /// apart from "we haven't looked yet".
    private(set) var hasLoadedOnce = false

    private let provider: LiveChannelProviding

    init(provider: LiveChannelProviding = FirebaseLiveChannelProvider()) {
        self.provider = provider
    }

    func refresh() async {
        isLoading = true
        loadFailed = false
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        do {
            channels = try await provider.fetchLiveChannels()
        } catch {
            // Keep whatever was already on screen; a failed refresh should not
            // blank out a feed the viewer is currently looking at.
            loadFailed = true
        }
    }
}
