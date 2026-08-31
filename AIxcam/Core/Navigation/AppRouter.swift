import FirebaseAuth
import Observation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var isAuthenticated: Bool = false
    var currentUser: FirebaseAuth.User?

    /// Best available display name: Firebase displayName → email prefix → fallback.
    var displayName: String {
        if let name = currentUser?.displayName, !name.isEmpty { return name }
        if let email = currentUser?.email { return String(email.prefix(while: { $0 != "@" })) }
        return "Creator"
    }

    @ObservationIgnored
    // nonisolated(unsafe) lets deinit access this without MainActor.assumeIsolated,
    // which would crash if deinit runs off the main thread. Safe because the handle
    // is written once in init and read once in deinit with no concurrent access.
    nonisolated(unsafe) private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    /// Sends a password reset email.
    ///
    /// Firebase returns `.userNotFound` for unregistered addresses. We deliberately
    /// do not surface that distinction to the caller — reporting it turns this screen
    /// into an account-enumeration oracle. Callers should show the same confirmation
    /// either way.
    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch let error as NSError
                    where error.code == AuthErrorCode.userNotFound.rawValue {
            return
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func updateDisplayName(_ name: String) async {
        guard let user = Auth.auth().currentUser else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try? await request.commitChanges()
        try? await user.reload()
        currentUser = Auth.auth().currentUser
    }
}
