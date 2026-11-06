import Foundation
import Observation
import OSLog

struct StreamRecord: Identifiable {
    let id: String
    let startedAt: Date
    let endedAt: Date?
    let peakViewers: Int

    var durationSeconds: Int? {
        guard let end = endedAt else { return nil }
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    var formattedDuration: String {
        guard let d = durationSeconds else { return "Ongoing" }
        let m = d / 60
        let s = d % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    var formattedDate: String {
        Self.displayFormatter.string(from: startedAt)
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

@Observable
@MainActor
final class StreamHistoryService {
    private(set) var recentStreams: [StreamRecord] = []
    private(set) var isLoading = false

    private nonisolated static let projectID = "aixcam"

    // nonisolated so it can be evaluated as a default argument of `init`, which
    // runs outside the main actor even though the class is @MainActor.
    nonisolated static let defaultBaseURL = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"

    // Held as a String rather than a URL because `fetchHistory` appends the
    // `:runQuery` verb, which is a suffix on the collection path and not a
    // path component — `URL.appending(path:)` would percent-encode the colon.
    private let baseURL: String
    private let session: URLSession
    private let authTokenProvider: AuthTokenProviding

    /// Everything that touches the outside world is injected so the write paths
    /// below are reachable from a test: without this, `startSession` returned
    /// nil the moment there was no signed-in user and none of the request
    /// construction, status checking or parsing ever ran.
    init(
        baseURL: String = StreamHistoryService.defaultBaseURL,
        session: URLSession = .shared,
        authTokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    /// Creates a new stream record in Firestore. Returns the document ID on success, nil on failure.
    func startSession(creatorID: String) async -> String? {
        guard let idToken = await currentIDToken() else { return nil }
        let documentID = UUID().uuidString
        let now = Self.formatDate(Date())

        let body: [String: Any] = [
            "fields": [
                "creatorID": ["stringValue": creatorID],
                "startedAt": ["timestampValue": now],
                "peakViewers": ["integerValue": "0"],
                // Written explicitly as null rather than omitted. Firestore's
                // `== null` matches only documents where the field *exists* and
                // is null — a missing field matches no equality filter at all,
                // so the "currently live" query in listLiveChannels would never
                // return anything if this were left out. endSession overwrites
                // it with a timestamp, which firestore.rules already permits.
                "endedAt": ["nullValue": NSNull()]
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/streams?documentId=\(documentID)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            // URLSession does not throw on HTTP 4xx/5xx, so a permission-denied
            // or malformed write would otherwise be reported as success.
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                AppLog.streaming.error("startSession: HTTP \(status, privacy: .public)")
                return nil
            }
        } catch {
            AppLog.streaming.error("startSession failed: \(String(reflecting: error), privacy: .public)")
            return nil
        }
        return documentID
    }

    /// Stamps the stream record with an end time and peak viewer count.
    func endSession(documentID: String, peakViewers: Int) async {
        guard let idToken = await currentIDToken() else { return }
        let now = Self.formatDate(Date())

        let body: [String: Any] = [
            "fields": [
                "endedAt": ["timestampValue": now],
                "peakViewers": ["integerValue": "\(peakViewers)"]
            ]
        ]

        // updateMask ensures only these two fields are written; creatorID/startedAt are preserved.
        let mask = "updateMask.fieldPaths=endedAt&updateMask.fieldPaths=peakViewers"
        var request = URLRequest(url: URL(string: "\(baseURL)/streams/\(documentID)?\(mask)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            AppLog.streaming.error("endSession failed for \(documentID, privacy: .public)")
            return
        }
    }

    /// Loads the most recent streams for the given creator, newest first.
    func fetchHistory(creatorID: String) async {
        guard let idToken = await currentIDToken() else { return }
        isLoading = true
        defer { isLoading = false }

        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "streams"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "creatorID"],
                        "op": "EQUAL",
                        "value": ["stringValue": creatorID]
                    ]
                ],
                "orderBy": [
                    ["field": ["fieldPath": "startedAt"], "direction": "DESCENDING"]
                ],
                "limit": 20
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL):runQuery")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: query)

        guard let (data, _) = try? await session.data(for: request),
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        recentStreams = results.compactMap { Self.parseRecord($0) }
    }

    // MARK: — Parsing

    // internal (not private) so unit tests can exercise the Firestore parser.
    static func parseRecord(_ result: [String: Any]) -> StreamRecord? {
        guard let document = result["document"] as? [String: Any],
              let name = document["name"] as? String,
              let fields = document["fields"] as? [String: Any],
              let startedAtStr = (fields["startedAt"] as? [String: Any])?["timestampValue"] as? String,
              let startedAt = parseDate(startedAtStr) else { return nil }

        let id = name.components(separatedBy: "/").last ?? UUID().uuidString

        let endedAt: Date?
        if let endedAtStr = (fields["endedAt"] as? [String: Any])?["timestampValue"] as? String {
            endedAt = parseDate(endedAtStr)
        } else {
            endedAt = nil
        }

        let peakViewers: Int
        if let pv = (fields["peakViewers"] as? [String: Any])?["integerValue"] as? String {
            peakViewers = Int(pv) ?? 0
        } else {
            peakViewers = 0
        }

        return StreamRecord(id: id, startedAt: startedAt, endedAt: endedAt, peakViewers: peakViewers)
    }

    private static let isoFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func formatDate(_ date: Date) -> String {
        isoFormatterPlain.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date? {
        isoFormatterWithFraction.date(from: string) ?? isoFormatterPlain.date(from: string)
    }

    private func currentIDToken() async -> String? {
        await authTokenProvider.currentIDToken()
    }
}
