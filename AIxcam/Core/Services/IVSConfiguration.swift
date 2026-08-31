import FirebaseAuth
import Foundation

/// AWS IVS channel credentials.
///
/// SECURITY: These values are **never** shipped inside the app bundle. The RTMP
/// stream key is a long-lived broadcast credential — embedding it in the binary
/// lets anyone who unzips the `.app` hijack the channel. Instead, credentials are
/// minted by an authenticated Cloud Function (`createStreamCredentials`) and handed
/// only to signed-in creators at "Go Live" time, so the key never lives in the
/// distributed binary and can be rotated centrally.
struct IVSConfiguration: Sendable, Codable {
    let ingestEndpoint: String
    let streamKey: String
    let chatRoomARN: String
    /// Public IVS HLS playback URL (.m3u8) viewers use to watch this channel.
    /// Not secret — it's how anyone with the link watches the stream.
    let playbackURL: String

    init(ingestEndpoint: String, streamKey: String, chatRoomARN: String, playbackURL: String = "") {
        self.ingestEndpoint = ingestEndpoint
        self.streamKey = streamKey
        self.chatRoomARN = chatRoomARN
        self.playbackURL = playbackURL
    }

    var rtmpsURL: String {
        "rtmps://\(ingestEndpoint):443/app/\(streamKey)"
    }

    var isPlaceholder: Bool {
        ingestEndpoint.isEmpty || streamKey.isEmpty
    }
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
            return error.localizedDescription
        }
    }
}

/// Supplies IVS credentials to the streaming layer. Abstracted so previews and
/// unit tests can inject static values without hitting the network.
protocol StreamCredentialsProviding: Sendable {
    func fetchCredentials() async throws -> IVSConfiguration
}

/// Fetches short-lived IVS credentials from the backend Cloud Function.
///
/// The function derives the creator identity from the verified Firebase ID token
/// (never from a client-supplied value) and returns the ingest endpoint, stream
/// key, and chat room ARN for that creator's channel.
final class FirebaseStreamCredentialsService: StreamCredentialsProviding {

    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://us-central1-aixcam.cloudfunctions.net/createStreamCredentials")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchCredentials() async throws -> IVSConfiguration {
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
        request.timeoutInterval = 15

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
        struct Envelope: Decodable { let result: IVSConfiguration }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).result
        } catch {
            throw StreamCredentialsError.decodingFailed
        }
    }
}

/// Static provider for Xcode Previews and unit tests — no network, no secrets.
struct StaticStreamCredentialsProvider: StreamCredentialsProviding {
    let configuration: IVSConfiguration

    init(configuration: IVSConfiguration = IVSConfiguration(
        ingestEndpoint: "",
        streamKey: "",
        chatRoomARN: "arn:aws:ivschat:us-east-1:000000000000:room/mock-preview"
    )) {
        self.configuration = configuration
    }

    func fetchCredentials() async throws -> IVSConfiguration {
        configuration
    }
}
