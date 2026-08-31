import FirebaseAuth
import Foundation
import Observation

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

    private static let projectID = "aixcam"
    private static let baseURL = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"

    /// Creates a new stream record in Firestore. Returns the document ID on success, nil on failure.
    func startSession(creatorID: String) async -> String? {
        guard let idToken = await currentIDToken() else { return nil }
        let documentID = UUID().uuidString
        let now = Self.formatDate(Date())

        let body: [String: Any] = [
            "fields": [
                "creatorID": ["stringValue": creatorID],
                "startedAt": ["timestampValue": now],
                "peakViewers": ["integerValue": "0"]
            ]
        ]

        var request = URLRequest(url: URL(string: "\(Self.baseURL)/streams?documentId=\(documentID)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            // URLSession does not throw on HTTP 4xx/5xx, so a permission-denied
            // or malformed write would otherwise be reported as success.
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("[StreamHistoryService] startSession non-success status")
                return nil
            }
        } catch {
            print("[StreamHistoryService] startSession failed: \(error)")
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
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/streams/\(documentID)?\(mask)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            print("[StreamHistoryService] endSession failed for \(documentID)")
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

        var request = URLRequest(url: URL(string: "\(Self.baseURL):runQuery")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: query)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
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
        try? await Auth.auth().currentUser?.getIDToken()
    }
}
