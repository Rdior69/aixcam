import FirebaseAuth
import Foundation
import Observation

/// Loads and saves the signed-in viewer's profile document.
///
/// Uses the Firestore REST API with the caller's Firebase ID token, matching
/// `StreamHistoryService`. The document ID is always the caller's uid, so the
/// security rules can pin ownership without trusting any client-supplied field.
@Observable
@MainActor
final class ViewerProfileService {

    private(set) var profile: ViewerProfile?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadFailed = false

    private static let projectID = "aixcam"
    private static let baseURL = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: — Load

    /// Fetches the current user's profile. A 404 is a normal first-run result and
    /// yields an empty profile rather than an error, so new accounts land straight
    /// in the setup form.
    func load() async {
        // Drop any previously loaded profile first. Without this, signing out and
        // back in as someone else renders the previous person's profile until the
        // new fetch lands.
        profile = nil

        guard let uid = Auth.auth().currentUser?.uid,
              let idToken = await currentIDToken() else {
            loadFailed = true
            return
        }

        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "\(Self.baseURL)/viewerProfiles/\(uid)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                loadFailed = true
                return
            }

            if http.statusCode == 404 {
                profile = ViewerProfile()
                return
            }

            guard (200...299).contains(http.statusCode) else {
                loadFailed = true
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                loadFailed = true
                return
            }
            profile = Self.decode(document: json) ?? ViewerProfile()
        } catch {
            loadFailed = true
        }
    }

    // MARK: — Save

    /// Writes the profile, overwriting the whole document. Returns true on success.
    @discardableResult
    func save(_ incoming: ViewerProfile) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid,
              let idToken = await currentIDToken() else { return false }

        var clean = incoming.sanitized()
        clean.updatedAt = Date()

        isSaving = true
        defer { isSaving = false }

        var request = URLRequest(url: URL(string: "\(Self.baseURL)/viewerProfiles/\(uid)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: Self.encode(clean, uid: uid))
        request.timeoutInterval = 20

        do {
            let (_, response) = try await session.data(for: request)
            // URLSession does not throw on 4xx/5xx, so a rules rejection would
            // otherwise be reported to the user as a successful save.
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
        } catch {
            return false
        }

        profile = clean
        await syncAuthDisplayName(clean.displayName)
        return true
    }

    /// Mirrors the profile name onto the Firebase Auth user so `AppRouter.displayName`
    /// (used by HomeView's greeting) doesn't drift from what the person actually set.
    /// Best-effort: the profile document is the source of truth, so a failure here
    /// must not fail the save.
    private func syncAuthDisplayName(_ name: String) async {
        guard let user = Auth.auth().currentUser, user.displayName != name else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try? await request.commitChanges()
    }

    // MARK: — Firestore encoding

    // internal (not private) so unit tests can round-trip the mapping.
    static func encode(_ profile: ViewerProfile, uid: String) -> [String: Any] {
        var fields: [String: Any] = [
            // Stamped so the security rules can pin the document to its owner.
            "uid": ["stringValue": uid],
            "displayName": ["stringValue": profile.displayName],
            "aboutMe": ["stringValue": profile.aboutMe],
            "turnOns": arrayValue(profile.turnOns),
            "fetishes": arrayValue(profile.fetishes),
            "turnOnsVisibility": ["stringValue": profile.turnOnsVisibility.rawValue],
            "fetishesVisibility": ["stringValue": profile.fetishesVisibility.rawValue],
            "genderSelfDescription": ["stringValue": profile.genderSelfDescription],
            "pronounsCustom": ["stringValue": profile.pronounsCustom],
            "updatedAt": ["timestampValue": formatDate(profile.updatedAt ?? Date())]
        ]

        if let birthdate = profile.birthdate {
            fields["birthdate"] = ["timestampValue": formatDate(birthdate)]
        }
        if let gender = profile.gender {
            fields["gender"] = ["stringValue": gender.rawValue]
        }
        if let pronouns = profile.pronouns {
            fields["pronouns"] = ["stringValue": pronouns.rawValue]
        }

        return ["fields": fields]
    }

    static func decode(document: [String: Any]) -> ViewerProfile? {
        guard let fields = document["fields"] as? [String: Any] else { return nil }

        var profile = ViewerProfile()
        profile.displayName = string(fields, "displayName") ?? ""
        profile.aboutMe = string(fields, "aboutMe") ?? ""
        profile.genderSelfDescription = string(fields, "genderSelfDescription") ?? ""
        profile.pronounsCustom = string(fields, "pronounsCustom") ?? ""
        profile.turnOns = strings(fields, "turnOns")
        profile.fetishes = strings(fields, "fetishes")

        if let raw = string(fields, "gender") { profile.gender = Gender(rawValue: raw) }
        if let raw = string(fields, "pronouns") { profile.pronouns = Pronouns(rawValue: raw) }
        if let raw = string(fields, "turnOnsVisibility"), let v = FieldVisibility(rawValue: raw) {
            profile.turnOnsVisibility = v
        }
        if let raw = string(fields, "fetishesVisibility"), let v = FieldVisibility(rawValue: raw) {
            profile.fetishesVisibility = v
        }
        if let raw = timestamp(fields, "birthdate") { profile.birthdate = parseDate(raw) }
        if let raw = timestamp(fields, "updatedAt") { profile.updatedAt = parseDate(raw) }

        return profile
    }

    // MARK: — Firestore value helpers

    private static func arrayValue(_ values: [String]) -> [String: Any] {
        ["arrayValue": ["values": values.map { ["stringValue": $0] }]]
    }

    private static func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private static func timestamp(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["timestampValue"] as? String
    }

    private static func strings(_ fields: [String: Any], _ key: String) -> [String] {
        guard let array = (fields[key] as? [String: Any])?["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else { return [] }
        return values.compactMap { $0["stringValue"] as? String }
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
