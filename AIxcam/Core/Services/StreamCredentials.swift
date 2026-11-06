import FirebaseAuth
import Foundation

/// Live-streaming credentials for one creator's channel.
///
/// SECURITY: `ingestURL` embeds the stream key as its last path component. That
/// key is a long-lived broadcast credential — anyone holding it can publish to
/// the channel — so it is **never** shipped in the app bundle. It is minted by
/// an authenticated Cloud Function (`createStreamCredentials`) and handed only
/// to signed-in creators at "Go Live" time, which is why fetching it costs a
/// network round trip that cannot be cached away.
nonisolated struct StreamCredentials: Sendable, Codable {

    /// Full RTMPS publish URL, stream key included, e.g.
    /// `rtmps://live.cloudflare.com:443/live/<streamKey>`.
    ///
    /// The backend returns the whole URL rather than a host and key the client
    /// recombines. Cloudflare publishes to `/live/`, AWS IVS used `/app/`, and
    /// baking either path into the client is how you end up with an app that
    /// can only ever talk to one vendor. HaishinKit takes a complete URL and
    /// splits the trailing path component off as the stream name itself, so
    /// there is nothing left for the client to assemble.
    let ingestURL: String

    /// Public HLS manifest viewers watch. Not secret — it is how anyone with
    /// the link watches the channel.
    let playbackURL: String

    /// True before the backend has provisioned a channel for this creator.
    var isPlaceholder: Bool { ingestURL.isEmpty }
}

/// Errors from the stream-credentials backend.
enum StreamCredentialsError: LocalizedError {
    case notAuthenticated
    case requestFailed(statusCode: Int)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "Sign in required to start a broadcast.")
        case .requestFailed(let code):
            return String(localized: "The streaming service returned an error (\(code)).")
        case .decodingFailed:
            return String(localized: "We couldn’t read the streaming service response.")
        case .network(let error):
            return AppError(error).message
        }
    }
}

/// Supplies credentials to the streaming layer. Abstracted so previews and
/// unit tests can inject static values without hitting the network.
protocol StreamCredentialsProviding: Sendable {
    func fetchCredentials() async throws -> StreamCredentials
}

/// Fetches credentials from the backend Cloud Function.
///
/// The function derives the creator identity from the verified Firebase ID token
/// (never from a client-supplied value) and returns the ingest and playback URLs
/// for that creator's own channel.
final class FirebaseStreamCredentialsProvider: StreamCredentialsProviding {

    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://us-central1-aixcam.cloudfunctions.net/createStreamCredentials")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchCredentials() async throws -> StreamCredentials {
        guard let user = Auth.auth().currentUser else {
            throw StreamCredentialsError.notAuthenticated
        }
        let idToken: String
        do {
            idToken = try await user.getIDToken()
        } catch {
            throw StreamCredentialsError.notAuthenticated
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": [:]])
        // Generous: a creator's first call provisions a live input with
        // Cloudflare before it can answer, which is slower than a cached fetch.
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StreamCredentialsError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw StreamCredentialsError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StreamCredentialsError.requestFailed(statusCode: http.statusCode)
        }

        // Callable functions wrap the payload in a top-level "result" object.
        struct Envelope: Decodable { let result: StreamCredentials }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).result
        } catch {
            throw StreamCredentialsError.decodingFailed
        }
    }
}

/// Static provider for Xcode Previews and unit tests — no network, no secrets.
nonisolated struct StaticStreamCredentialsProvider: StreamCredentialsProviding {
    let credentials: StreamCredentials

    init(credentials: StreamCredentials = StreamCredentials(ingestURL: "", playbackURL: "")) {
        self.credentials = credentials
    }

    func fetchCredentials() async throws -> StreamCredentials {
        credentials
    }
}
