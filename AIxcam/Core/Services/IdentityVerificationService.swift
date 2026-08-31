import FirebaseAuth
import Foundation
import Observation

/// Where a creator stands in identity verification.
///
/// This is the app's single source of truth for whether someone may broadcast.
/// It is deliberately *not* derived from anything the client stores: an on-device
/// flag is trivially forged and is wiped by a reinstall, neither of which is
/// acceptable for the gate that keeps unverified people off an 18+ platform.
nonisolated enum IdentityVerificationStatus: String, Sendable, Codable, CaseIterable {
    /// Never submitted, or the backend returned something unrecognised.
    case unverified
    /// Submitted and awaiting review by the KYC provider.
    case pending
    case approved
    case rejected

    /// Only an approved creator may go live. Everything else — including
    /// `pending` — fails closed.
    var allowsBroadcasting: Bool { self == .approved }

    /// Shown wherever the status is surfaced (profile row, broadcast gate).
    var label: String {
        switch self {
        case .unverified: return "Not verified"
        case .pending:    return "Submitted · Under review"
        case .approved:   return "Verified"
        case .rejected:   return "Verification failed"
        }
    }

    /// Why broadcasting is blocked, or nil when it isn't.
    var broadcastBlockedReason: String? {
        switch self {
        case .approved:
            return nil
        case .unverified:
            return "Verify your identity in Profile before going live."
        case .pending:
            return "Your identity verification is still under review."
        case .rejected:
            return "Your identity verification was not accepted. Please resubmit in Profile."
        }
    }
}

/// Reads the signed-in creator's verification status. Abstracted so previews and
/// unit tests can supply a status without hitting the network.
protocol IdentityVerificationProviding: Sendable {
    func fetchStatus() async throws -> IdentityVerificationStatus
}

enum IdentityVerificationError: LocalizedError {
    case notAuthenticated
    case requestFailed(statusCode: Int)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in required to check verification status."
        case .requestFailed(let code):
            return "The verification service returned an error (\(code))."
        case .decodingFailed:
            return "We couldn’t read the verification service response."
        case .network(let error):
            return error.localizedDescription
        }
    }
}

/// Fetches the status from the `getIdentityVerificationStatus` Cloud Function.
///
/// The function derives the caller from the verified Firebase ID token, so the
/// client cannot ask about anyone else. It returns only the status enum — the
/// underlying `identityVerifications/{uid}` document is closed to clients by
/// `firestore.rules` because it also holds idType and countryOfIssue.
/// Nonisolated: the app target defaults to main-actor isolation, but this holds
/// only immutable values and is used as a default argument, which is evaluated
/// outside any actor.
nonisolated final class FirebaseIdentityVerificationProvider: IdentityVerificationProviding {

    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://us-central1-aixcam.cloudfunctions.net/getIdentityVerificationStatus")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchStatus() async throws -> IdentityVerificationStatus {
        guard let user = Auth.auth().currentUser else {
            throw IdentityVerificationError.notAuthenticated
        }

        let idToken: String
        do {
            idToken = try await user.getIDToken()
        } catch {
            throw IdentityVerificationError.notAuthenticated
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
            throw IdentityVerificationError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw IdentityVerificationError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw IdentityVerificationError.requestFailed(statusCode: http.statusCode)
        }

        // Callable functions wrap the payload in a top-level "result" object.
        struct Envelope: Decodable {
            struct Result: Decodable { let status: String }
            let result: Result
        }

        do {
            let raw = try JSONDecoder().decode(Envelope.self, from: data).result.status
            // An unknown value must fail closed rather than unlock broadcasting.
            return IdentityVerificationStatus(rawValue: raw) ?? .unverified
        } catch {
            throw IdentityVerificationError.decodingFailed
        }
    }
}

/// Static provider for Xcode Previews and unit tests — no network.
nonisolated struct StaticIdentityVerificationProvider: IdentityVerificationProviding {
    let status: IdentityVerificationStatus

    init(status: IdentityVerificationStatus = .unverified) {
        self.status = status
    }

    func fetchStatus() async throws -> IdentityVerificationStatus { status }
}

/// Observable holder for the verification status, injected through the
/// environment so Profile and the broadcast gate read the same value.
@Observable
@MainActor
final class IdentityVerificationService {

    /// Starts `unverified` so the UI fails closed while the first fetch is in
    /// flight — a creator must never see a broadcast-enabled state by default.
    private(set) var status: IdentityVerificationStatus = .unverified
    private(set) var isLoading = false
    private(set) var loadFailed = false

    private let provider: IdentityVerificationProviding

    init(provider: IdentityVerificationProviding = FirebaseIdentityVerificationProvider()) {
        self.provider = provider
    }

    func refresh() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            status = try await provider.fetchStatus()
        } catch {
            // Keep the last known status rather than silently downgrading a
            // verified creator because the network blipped, but surface the
            // failure so the UI can offer a retry.
            loadFailed = true
        }
    }

    /// Clears state on sign-out so the next person can't inherit this status.
    func reset() {
        status = .unverified
        loadFailed = false
    }
}
