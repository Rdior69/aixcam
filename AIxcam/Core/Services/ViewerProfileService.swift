import FirebaseAuth
import Foundation
import Observation
import OSLog

/// Why a profile load produced no profile.
///
/// These are kept apart because the remedies are different, and the screen that
/// reports them used to claim every one of them was a connection problem. A
/// rules rejection or a missing backend deployment is not something "check your
/// connection and try again" can fix, and telling someone otherwise sends them
/// to reset their router over a server-side misconfiguration.
enum ViewerProfileLoadFailure: Equatable, Sendable {
    /// No signed-in user, or the ID token could not be minted.
    case notSignedIn
    /// Firestore evaluated the security rules and said no (HTTP 403).
    case permissionDenied
    /// Any other non-success HTTP status.
    case server(status: Int)
    /// The request never completed — offline, timeout, DNS.
    case transport
    /// A 2xx response whose body was not a Firestore document.
    case malformedResponse

    /// Headline shown to the person. Honest about which side is at fault.
    var message: String {
        switch self {
        case .notSignedIn:      return "You're signed out"
        case .permissionDenied: return "Your profile is locked"
        case .server:           return "Couldn't load your profile"
        case .transport:        return "Couldn't reach AIxcam"
        case .malformedResponse: return "Couldn't read your profile"
        }
    }

    /// What to do next. Retrying a 403 will keep failing, so it says so.
    var guidance: String {
        switch self {
        case .notSignedIn:
            return "Sign in again to continue."
        case .permissionDenied:
            return "Your account doesn't have access to its own profile yet. This is a server-side setting, not something you can fix here — retrying won't help until it's corrected."
        case .server(let status):
            return "AIxcam returned an unexpected error (\(status)). Try again in a moment."
        case .transport:
            return "Check your connection and try again."
        case .malformedResponse:
            return "AIxcam sent something unexpected. Try again in a moment."
        }
    }

    var systemImage: String {
        switch self {
        case .transport:        return "wifi.exclamationmark"
        case .permissionDenied: return "lock.slash"
        case .notSignedIn:      return "person.crop.circle.badge.exclamationmark"
        default:                return "exclamationmark.triangle"
        }
    }

    /// Whether the Retry button is worth offering.
    var isRetryable: Bool { self != .permissionDenied }
}

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

    /// nil when the last load succeeded, or when none has finished yet.
    private(set) var loadFailure: ViewerProfileLoadFailure?

    var loadFailed: Bool { loadFailure != nil }

    private nonisolated static let projectID = "aixcam"

    // nonisolated so it can be evaluated as a default argument of `init`, which
    // runs outside the main actor even though the class is @MainActor.
    nonisolated static let defaultBaseURL = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"

    private let baseURL: String
    private let session: URLSession
    private let authTokenProvider: AuthTokenProviding

    /// The uid whose profile is currently held, so a load for a *different*
    /// person clears it while a reload for the same person does not.
    private var loadedUID: String?

    init(
        baseURL: String = ViewerProfileService.defaultBaseURL,
        session: URLSession = .shared,
        authTokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    // MARK: — Load

    /// Fetches the current user's profile. A 404 is a normal first-run result and
    /// yields an empty profile rather than an error, so new accounts land straight
    /// in the setup form.
    func load() async {
        guard let identity = await authTokenProvider.currentIdentity() else {
            AppLog.profile.error("load: no signed-in user or no ID token")
            fail(.notSignedIn)
            return
        }

        // Only drop a held profile when it belongs to somebody else. Wiping it
        // on every load meant a failed reload replaced a perfectly good profile
        // with the full-screen error, and a cancelled one did the same.
        if loadedUID != identity.userID {
            profile = nil
            loadedUID = nil
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "\(baseURL)/viewerProfiles/\(identity.userID)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(identity.idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                AppLog.profile.error("load: non-HTTP response")
                fail(.malformedResponse)
                return
            }

            if http.statusCode == 404 {
                succeed(ViewerProfile(), for: identity.userID)
                return
            }

            guard (200...299).contains(http.statusCode) else {
                // The body carries Firestore's reason (PERMISSION_DENIED and
                // friends). Logging it is the difference between a five-minute
                // diagnosis and guessing at the network. It can also echo
                // document contents, so it stays private — redacted in release,
                // readable while debugging.
                let body = String(decoding: data.prefix(512), as: UTF8.self)
                AppLog.profile.error("load: HTTP \(http.statusCode, privacy: .public) — \(body)")
                fail(http.statusCode == 403 ? .permissionDenied : .server(status: http.statusCode))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AppLog.profile.error("load: response was not a JSON object")
                fail(.malformedResponse)
                return
            }
            succeed(Self.decode(document: json) ?? ViewerProfile(), for: identity.userID)
        } catch let error where error.isCancellation {
            // The caller is a `.task(id:)`, so SwiftUI cancels this on every auth
            // transition and view teardown. That is routine, not a failure, and
            // must not paint the error screen.
        } catch {
            AppLog.profile.error("load failed: \(String(reflecting: error), privacy: .public)")
            fail(.transport)
        }
    }

    private func succeed(_ loaded: ViewerProfile, for uid: String) {
        profile = loaded
        loadedUID = uid
        loadFailure = nil
    }

    private func fail(_ failure: ViewerProfileLoadFailure) {
        loadFailure = failure
    }

    /// Clears state on sign-out so the next person can't inherit this profile.
    func reset() {
        profile = nil
        loadedUID = nil
        loadFailure = nil
    }

    // MARK: — Save

    /// Writes the profile, overwriting the whole document. Returns true on success.
    @discardableResult
    func save(_ incoming: ViewerProfile) async -> Bool {
        guard let identity = await authTokenProvider.currentIdentity() else { return false }

        var clean = incoming.sanitized()
        clean.updatedAt = Date()

        isSaving = true
        defer { isSaving = false }

        var request = URLRequest(url: URL(string: "\(baseURL)/viewerProfiles/\(identity.userID)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(identity.idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: Self.encode(clean, uid: identity.userID))
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            // URLSession does not throw on 4xx/5xx, so a rules rejection would
            // otherwise be reported to the user as a successful save.
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(decoding: data.prefix(512), as: UTF8.self)
                AppLog.profile.error("save: HTTP \(status, privacy: .public) — \(body)")
                return false
            }
        } catch {
            AppLog.profile.error("save failed: \(String(reflecting: error), privacy: .public)")
            return false
        }

        profile = clean
        loadedUID = identity.userID
        loadFailure = nil
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
            "interests": arrayValue(profile.interests),
            "favoriteCategories": arrayValue(profile.favoriteCategories),
            "interestsVisibility": ["stringValue": profile.interestsVisibility.rawValue],
            "favoriteCategoriesVisibility": ["stringValue": profile.favoriteCategoriesVisibility.rawValue],
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
        profile.interests = strings(fields, "interests")
        profile.favoriteCategories = strings(fields, "favoriteCategories")

        if let raw = string(fields, "gender") { profile.gender = Gender(rawValue: raw) }
        if let raw = string(fields, "pronouns") { profile.pronouns = Pronouns(rawValue: raw) }
        if let raw = string(fields, "interestsVisibility"), let v = FieldVisibility(rawValue: raw) {
            profile.interestsVisibility = v
        }
        if let raw = string(fields, "favoriteCategoriesVisibility"), let v = FieldVisibility(rawValue: raw) {
            profile.favoriteCategoriesVisibility = v
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
}
