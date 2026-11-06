import FirebaseAuth
import Foundation

/// The two facts every authenticated backend call needs: who is calling, and
/// the bearer token that proves it.
nonisolated struct AuthIdentity: Sendable, Equatable {
    let userID: String
    let idToken: String
}

/// Supplies the signed-in user's identity to services that call our backend.
///
/// Reaching for `Auth.auth().currentUser` inline — as every service used to —
/// left no way to stand in a signed-in user, so request construction, HTTP
/// status handling and error mapping could never be executed by a test; only
/// the pure helpers around them were reachable. This is the seam that opens
/// those paths. `CreatorPayoutService` already took a bare token closure; this
/// generalises it and carries the uid, which attribution writes need.
protocol AuthTokenProviding: Sendable {
    /// nil when nobody is signed in, or the ID token could not be refreshed.
    func currentIdentity() async -> AuthIdentity?
}

extension AuthTokenProviding {
    /// For the callers that only need the bearer token.
    func currentIDToken() async -> String? {
        await currentIdentity()?.idToken
    }
}

/// Production provider, backed by FirebaseAuth.
///
/// Nonisolated because the app target defaults to main-actor isolation but this
/// holds no state and is used as a default argument, which is evaluated outside
/// any actor.
nonisolated struct FirebaseAuthTokenProvider: AuthTokenProviding {
    func currentIdentity() async -> AuthIdentity? {
        guard let user = Auth.auth().currentUser,
              let idToken = try? await user.getIDToken() else { return nil }
        return AuthIdentity(userID: user.uid, idToken: idToken)
    }
}

/// Fixed provider for Xcode Previews and unit tests — never touches
/// FirebaseAuth, so it works in a test process where `FirebaseApp.configure()`
/// was never called.
nonisolated struct StaticAuthTokenProvider: AuthTokenProviding {
    let identity: AuthIdentity?

    init(userID: String = "test-uid", idToken: String = "test-id-token") {
        self.identity = AuthIdentity(userID: userID, idToken: idToken)
    }

    private init(identity: AuthIdentity?) {
        self.identity = identity
    }

    /// Nobody signed in — drives the `.notAuthenticated` paths.
    static let signedOut = StaticAuthTokenProvider(identity: nil)

    func currentIdentity() async -> AuthIdentity? { identity }
}
