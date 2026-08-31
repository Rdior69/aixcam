import FirebaseAuth
import Foundation
import Observation

struct ChatMessage: Identifiable, Sendable {
    let id: String
    let sender: String
    let text: String
    let timestamp: Date
}

@Observable
@MainActor
final class ChatService {
    private(set) var messages: [ChatMessage] = []
    private(set) var isConnected = false

    private static let messageLimit = 200
    private static let maxReconnectDelay: TimeInterval = 30
    /// IVS Chat rejects messages over 500 bytes; cap client-side to fail fast
    /// and to bound what a single client can push in one frame.
    private static let maxOutgoingMessageLength = 500

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var currentRoomARN: String?
    private var reconnectDelay: TimeInterval = 1.0

    func connect(roomARN: String) async throws {
        currentRoomARN = roomARN
        reconnectDelay = 1.0
        try await connectInternal(roomARN: roomARN)
    }

    private func connectInternal(roomARN: String) async throws {
        let token = try await fetchToken(roomARN: roomARN)
        let region = Self.region(from: roomARN)
        let url = URL(string: "wss://edge.ivschat.\(region).amazonaws.com")!

        // Token is passed as the WebSocket subprotocol — this is how IVS Chat authenticates.
        let task = URLSession.shared.webSocketTask(with: url, protocols: [token])
        task.resume()
        webSocketTask = task

        // Confirm the handshake is complete before advertising connectivity.
        // A successful pong response means the connection is fully established.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        isConnected = true
        // Handshake succeeded — reset backoff so a later drop starts from 1s again.
        reconnectDelay = 1.0

        // Task.detached breaks out of @MainActor so WebSocket receives and JSON
        // decoding run on a background executor. Only state mutations hop back
        // to @MainActor via MainActor.run. The URLSessionWebSocketTask is passed
        // directly to avoid accessing the @MainActor-isolated webSocketTask property
        // from a non-isolated context.
        receiveTask = Task.detached { [weak self, task] in
            await self?.receiveMessages(from: task)
        }
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        currentRoomARN = nil
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func scheduleReconnect() {
        guard let arn = currentRoomARN else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, Self.maxReconnectDelay)

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            try? await self.connectInternal(roomARN: arn)
        }
    }

    func send(_ text: String) {
        guard isConnected, let task = webSocketTask else { return }

        // Trim, drop empties, and clamp length before it ever hits the wire.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let content = String(trimmed.prefix(Self.maxOutgoingMessageLength))

        let payload = SendPayload(Action: "SEND_MESSAGE", RequestId: UUID().uuidString, Content: content)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        task.send(.string(json)) { _ in }
    }

    private nonisolated func receiveMessages(from wsTask: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await wsTask.receive()
                if case .string(let text) = message {
                    // Hop to @MainActor only for decoding + append.
                    // The I/O wait above runs on a background executor.
                    // self is strongly retained for the duration of this instance
                    // method, so no weak capture is needed inside MainActor.run.
                    await MainActor.run {
                        guard let chatMessage = ChatService.parseMessage(text) else { return }
                        self.messages.append(chatMessage)
                        if self.messages.count > ChatService.messageLimit {
                            self.messages.removeFirst(self.messages.count - ChatService.messageLimit)
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { [weak self] in
                        self?.isConnected = false
                        self?.scheduleReconnect()
                    }
                }
                break
            }
        }
    }

    // internal (not private) so unit tests can exercise the parser directly.
    static func parseMessage(_ text: String) -> ChatMessage? {
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(IncomingEvent.self, from: data),
              event.eventType == "MESSAGE",
              let content = event.Content,
              let id = event.Id else { return nil }

        let timestamp: Date
        if let timeStr = event.SendTime {
            timestamp = ISO8601DateFormatter().date(from: timeStr) ?? Date()
        } else {
            timestamp = Date()
        }

        let displayName = event.Sender?.Attributes?["displayName"]
            ?? event.Sender?.UserId
            ?? "Viewer"

        return ChatMessage(id: id, sender: displayName, text: content, timestamp: timestamp)
    }

    private func fetchToken(roomARN: String) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ChatError.notAuthenticated
        }
        let idToken = try await user.getIDToken()

        let url = URL(string: "https://us-central1-aixcam.cloudfunctions.net/createChatToken")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": ["roomArn": roomARN]])
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ChatError.tokenFetchFailed
        }

        let result = try JSONDecoder().decode(TokenResponse.self, from: data)
        return result.result.token
    }

    // internal (not private) so unit tests can verify region derivation.
    static func region(from arn: String) -> String {
        // arn:aws:ivschat:<region>:<account>:room/<id>
        let parts = arn.split(separator: ":")
        return parts.count > 3 ? String(parts[3]) : "us-east-1"
    }
}

// MARK: — Private wire types

private struct SendPayload: Encodable {
    let Action: String
    let RequestId: String
    let Content: String
}

private struct IncomingEvent: Decodable {
    let eventType: String
    let Id: String?
    let Content: String?
    let SendTime: String?
    let RequestId: String?
    let Sender: IncomingSender?

    enum CodingKeys: String, CodingKey {
        case eventType = "Type"
        case Id, Content, SendTime, RequestId, Sender
    }
}

private struct IncomingSender: Decodable {
    let UserId: String
    let Attributes: [String: String]?
}

private struct TokenResponse: Decodable {
    struct Result: Decodable { let token: String }
    let result: Result
}

// MARK: — Errors

enum ChatError: LocalizedError, Equatable {
    case notAuthenticated
    case tokenFetchFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Sign in required to join chat."
        case .tokenFetchFailed: return "Could not obtain a chat session token."
        }
    }
}
