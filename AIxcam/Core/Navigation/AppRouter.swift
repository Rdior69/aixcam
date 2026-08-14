import FirebaseAuth
import Observation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var isAuthenticated: Bool = false
    var currentUser: FirebaseAuth.User?

    @ObservationIgnored
    nonisolated(unsafe) private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            MainActor.assumeIsolated {
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

    func signOut() {
        try? Auth.auth().signOut()
    }
}
