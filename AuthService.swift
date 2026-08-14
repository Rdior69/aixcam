import FirebaseAuth
import Observation

/// Service responsible for managing Firebase authentication state and operations.
/// 
/// This service handles:
/// - User authentication state monitoring
/// - Sign in/sign up/sign out operations
/// - Current user state management
@MainActor
@Observable
final class AuthService {
    /// The currently authenticated Firebase user, if any
    private(set) var currentUser: FirebaseAuth.User?
    
    /// Whether a user is currently authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    @ObservationIgnored
    nonisolated(unsafe) private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            MainActor.assumeIsolated {
                self?.currentUser = user
            }
        }
    }
    
    // MARK: - Public Authentication Methods
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: Firebase authentication errors
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    /// Create a new user account with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: Firebase authentication errors
    func signUp(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    /// Sign out the current user
    func signOut() {
        try? Auth.auth().signOut()
    }
}
