import Foundation

/// Our backend's side of a purchase: recording who a payment was for, and
/// handing Apple's signed transaction over for server-side verification.
///
/// Split out of `PaymentService` because these are the money-critical paths and
/// neither was reachable from a test. `PaymentService` cannot be constructed
/// without StoreKit, and both calls went straight to `Auth.auth()` and
/// `URLSession.shared` against hardcoded URLs. Behind a protocol the real
/// implementation can be driven directly with a stubbed session, and
/// `PaymentService` can be handed a double that asserts the ordering guarantee
/// in `purchase(_:creatorID:)`.
protocol PaymentBackend: Sendable {
    /// Records the buyer→creator mapping for `token` so the backend ledger can
    /// credit the right creator when it verifies the resulting transaction.
    ///
    /// MUST throw on any failure. The caller charges only if this succeeds:
    /// taking the money with no mapping means the creator can never be credited
    /// and there is nothing for the ledger to reconcile against.
    func registerAttribution(token: UUID, creatorID: String) async throws

    /// Hands the App Store-signed transaction (JWS) to the backend so it can
    /// re-verify with Apple and credit the creator ledger.
    ///
    /// Deliberately non-throwing: the backend also reconciles via App Store
    /// Server Notifications, so a dropped call here is eventually corrected and
    /// must not fail a purchase the buyer has already completed.
    func forwardTransaction(jws: String) async
}

/// Talks to the Firestore REST API and our `recordTransaction` Cloud Function.
///
/// Nonisolated because the app target defaults to main-actor isolation but this
/// holds only immutable values and is used as a default argument, which is
/// evaluated outside any actor.
nonisolated final class FirebasePaymentBackend: PaymentBackend {

    // Held as a String rather than a URL because the attribution write appends
    // a `?documentId=` query to the collection path by interpolation.
    static let defaultFirestoreDocumentsURL =
        "https://firestore.googleapis.com/v1/projects/aixcam/databases/(default)/documents"

    static let defaultRecordTransactionURL =
        URL(string: "https://us-central1-aixcam.cloudfunctions.net/recordTransaction")!

    private let firestoreDocumentsURL: String
    private let recordTransactionURL: URL
    private let session: URLSession
    private let authTokenProvider: AuthTokenProviding

    init(
        firestoreDocumentsURL: String = FirebasePaymentBackend.defaultFirestoreDocumentsURL,
        recordTransactionURL: URL = FirebasePaymentBackend.defaultRecordTransactionURL,
        session: URLSession = .shared,
        authTokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider()
    ) {
        self.firestoreDocumentsURL = firestoreDocumentsURL
        self.recordTransactionURL = recordTransactionURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    // MARK: - Attribution

    func registerAttribution(token: UUID, creatorID: String) async throws {
        guard let identity = await authTokenProvider.currentIdentity() else {
            throw PaymentError.attributionFailed
        }

        // The document id is the lowercased token because Apple normalizes
        // `appAccountToken` to lowercase in the signed transaction payload, and
        // the backend looks the mapping up by that value.
        let documentID = token.uuidString.lowercased()
        guard let url = URL(string: "\(firestoreDocumentsURL)/attributions?documentId=\(documentID)") else {
            throw PaymentError.attributionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(identity.idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "fields": [
                "creatorId": ["stringValue": creatorID],
                "buyerUid": ["stringValue": identity.userID]
            ]
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw PaymentError.attributionFailed
        }
        request.httpBody = httpBody

        // URLSession does not throw on 4xx/5xx, so the status has to be checked
        // explicitly — a rules rejection would otherwise read as success.
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw PaymentError.attributionFailed
            }
        } catch let error as PaymentError {
            throw error
        } catch {
            throw PaymentError.attributionFailed
        }
    }

    // MARK: - Transaction Forwarding

    func forwardTransaction(jws: String) async {
        guard let idToken = await authTokenProvider.currentIDToken() else { return }

        var request = URLRequest(url: recordTransactionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "data": [
                // The signed JWS (compact JWT) is the tamper-evident source of
                // truth the backend re-verifies against Apple's public keys.
                // Transaction details (id, product) are read from the verified
                // payload server-side, so nothing here is trusted beyond the
                // signature.
                "signedTransaction": jws
            ]
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        _ = try? await session.data(for: request)
    }
}

/// Does nothing. For Xcode Previews and for tests that need a `PaymentService`
/// without any network traffic.
nonisolated struct NoOpPaymentBackend: PaymentBackend {
    func registerAttribution(token: UUID, creatorID: String) async throws {}
    func forwardTransaction(jws: String) async {}
}
