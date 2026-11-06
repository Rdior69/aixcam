import FirebaseAuth
import Foundation
import Observation
import OSLog

nonisolated struct ChatMessage: Identifiable, Sendable, Equatable {
    let id: String
    let sender: String
    let text: String
    let timestamp: Date
}

/// Live chat for one broadcast, backed by `streams/{streamID}/messages`.
///
/// This replaced an AWS IVS Chat WebSocket client. IVS is unavailable on this
/// project's AWS account — an organisation SCP denies `ivschat:*` — and rather
/// than take on a second streaming vendor purely for chat, messages now live in
/// Firestore alongside the stream record they belong to.
///
/// Reads are polled over the Firestore REST API rather than pushed. The app
/// links only FirebaseAuth and FirebaseCore, and every other Firestore access
/// here is REST (see `StreamHistoryService`, `ViewerProfileService`); real-time
/// listeners would mean pulling in the full Firestore SDK. At `pollInterval`
/// the latency is within what a chat overlay needs — moving to a snapshot
/// listener is a worthwhile upgrade later, not a correctness fix.
@Observable
@MainActor
final class ChatService {
    private(set) var messages: [ChatMessage] = []
    private(set) var isConnected = false

    private static let messageLimit = 200
    /// Matches the ceiling in firestore.rules. Clamping client-side fails fast
    /// instead of surfacing a rules rejection as a mysteriously failed send.
    static let maxOutgoingMessageLength = 500
    private static let pollInterval: Duration = .seconds(2)

    private var pollTask: Task<Void, Never>?
    private var currentStreamID: String?
    /// Document IDs already rendered, so a poll that re-reads the same window
    /// does not duplicate what is on screen.
    private var seenIDs: Set<String> = []

    private let baseURL: String
    private let session: URLSession
    private let authTokenProvider: AuthTokenProviding

    init(
        baseURL: String = ViewerProfileService.defaultBaseURL,
        session: URLSession = .shared,
        authTokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    // MARK: — Lifecycle

    func connect(streamID: String) async throws {
        guard await authTokenProvider.currentIdentity() != nil else {
            throw ChatError.notAuthenticated
        }

        disconnect()
        currentStreamID = streamID
        isConnected = true

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: ChatService.pollInterval)
            }
        }
    }

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        currentStreamID = nil
        seenIDs = []
        messages = []
        isConnected = false
    }

    // MARK: — Read

    private func poll() async {
        guard let streamID = currentStreamID,
              let identity = await authTokenProvider.currentIdentity() else { return }

        var components = URLComponents(string: "\(baseURL)/streams/\(streamID)/messages")!
        components.queryItems = [
            URLQueryItem(name: "orderBy", value: "createdAt"),
            URLQueryItem(name: "pageSize", value: "\(Self.messageLimit)")
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(identity.idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            // 404 means nobody has sent a message yet — a subcollection does not
            // exist until its first document does. Not an error.
            if http.statusCode == 404 { return }
            guard (200...299).contains(http.statusCode) else {
                AppLog.streaming.error("chat poll: HTTP \(http.statusCode, privacy: .public)")
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let documents = json["documents"] as? [[String: Any]] else { return }

            merge(documents.compactMap(Self.parse(document:)))
        } catch let error where error.isCancellation {
            // Routine: disconnect() cancels the poll loop.
        } catch {
            AppLog.streaming.error("chat poll failed: \(String(reflecting: error), privacy: .public)")
        }
    }

    /// Appends only messages not already shown, preserving send order.
    private func merge(_ incoming: [ChatMessage]) {
        let fresh = incoming.filter { !seenIDs.contains($0.id) }
        guard !fresh.isEmpty else { return }

        for message in fresh { seenIDs.insert(message.id) }
        messages.append(contentsOf: fresh.sorted { $0.timestamp < $1.timestamp })

        if messages.count > Self.messageLimit {
            let overflow = messages.count - Self.messageLimit
            for dropped in messages.prefix(overflow) { seenIDs.remove(dropped.id) }
            messages.removeFirst(overflow)
        }
    }

    // MARK: — Write

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let streamID = currentStreamID else { return }
        let content = String(trimmed.prefix(Self.maxOutgoingMessageLength))

        Task { [weak self] in
            await self?.post(content, to: streamID)
        }
    }

    private func post(_ text: String, to streamID: String) async {
        guard let identity = await authTokenProvider.currentIdentity() else { return }

        let displayName = Auth.auth().currentUser?.displayName ?? "Viewer"
        let body: [String: Any] = [
            "fields": [
                // Stamped so the rules can pin authorship to the caller rather
                // than trusting a client-supplied name.
                "senderUid": ["stringValue": identity.userID],
                "displayName": ["stringValue": displayName],
                "text": ["stringValue": text],
                "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/streams/\(streamID)/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(identity.idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let detail = String(decoding: data.prefix(256), as: UTF8.self)
                AppLog.streaming.error("chat send: HTTP \(status, privacy: .public) — \(detail)")
                return
            }
            // Pull the new message in immediately rather than waiting a tick, so
            // the sender sees their own text appear without a visible lag.
            await poll()
        } catch {
            AppLog.streaming.error("chat send failed: \(String(reflecting: error), privacy: .public)")
        }
    }

    // MARK: — Decoding

    // internal (not private) so unit tests can exercise the parser directly.
    static func parse(document: [String: Any]) -> ChatMessage? {
        guard let name = document["name"] as? String,
              let fields = document["fields"] as? [String: Any],
              let text = string(fields, "text"), !text.isEmpty else { return nil }

        let id = String(name.split(separator: "/").last ?? "")
        guard !id.isEmpty else { return nil }

        let sender = string(fields, "displayName").flatMap { $0.isEmpty ? nil : $0 } ?? "Viewer"
        let timestamp = timestampValue(fields, "createdAt").flatMap(parseDate) ?? Date()

        return ChatMessage(id: id, sender: sender, text: text, timestamp: timestamp)
    }

    private static func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private static func timestampValue(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["timestampValue"] as? String
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ value: String) -> Date? {
        isoWithFraction.date(from: value) ?? isoPlain.date(from: value)
    }
}

// MARK: — Errors

enum ChatError: LocalizedError, Equatable {
    case notAuthenticated
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return String(localized: "Sign in required to join chat.")
        case .sendFailed:       return String(localized: "Your message couldn’t be sent.")
        }
    }
}
