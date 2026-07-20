import Combine
import Foundation

private struct SessionRecord: Codable {
    var user: AppUser
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published var status: AuthStatus = .idle
    @Published private(set) var isBusy = false

    private let sessionStorageKey = "aixcam.currentSession.v2"
    private let backendService: CreatorBackendServicing
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var shouldShowCreatorOnboarding: Bool {
        guard let currentUser else { return false }
        return currentUser.accountType == .creator && currentUser.hasPublishedCreatorProfile == false
    }

    init(
        backendService: CreatorBackendServicing = CreatorBackendFactory.makeService(),
        userDefaults: UserDefaults = .standard,
        restoreSessionOnInit: Bool = true
    ) {
        self.backendService = backendService
        self.userDefaults = userDefaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        if restoreSessionOnInit {
            restoreSession()
        }
    }

    func signUp(name: String, email: String, accountType: AccountType, password: String) {
        isBusy = true
        status = .idle

        Task {
            do {
                let user = try await backendService.signUp(
                    payload: SignUpPayload(
                        fullName: name,
                        email: email,
                        password: password,
                        accountType: accountType
                    )
                )
                applyAuthenticatedState(for: user)
                status = .success("Welcome to Aixcam, \(user.name).")
            } catch {
                status = .error(error.localizedDescription)
            }
            isBusy = false
        }
    }

    func login(email: String, password: String) {
        isBusy = true
        status = .idle

        Task {
            do {
                let user = try await backendService.login(email: email, password: password)
                applyAuthenticatedState(for: user)
                status = .success("Welcome back, \(user.name).")
            } catch {
                status = .error(error.localizedDescription)
            }
            isBusy = false
        }
    }

    func resetStatus() {
        status = .idle
    }

    func markCreatorOnboardingPublished() {
        guard var user = currentUser else { return }
        user.hasPublishedCreatorProfile = true
        applyAuthenticatedState(for: user)
    }

    func signOut() {
        Task {
            try? await backendService.signOut()
            currentUser = nil
            status = .idle
            userDefaults.removeObject(forKey: sessionStorageKey)
        }
    }

    private func applyAuthenticatedState(for user: AppUser) {
        currentUser = user
        persistSession()
    }

    private func restoreSession() {
        guard let data = userDefaults.data(forKey: sessionStorageKey),
              let record = try? decoder.decode(SessionRecord.self, from: data) else {
            return
        }

        // Show cached user immediately, then revalidate against the backend.
        currentUser = record.user
        Task {
            do {
                let refreshed = try await backendService.refreshUser(userID: record.user.id)
                applyAuthenticatedState(for: refreshed)
            } catch {
                currentUser = nil
                userDefaults.removeObject(forKey: sessionStorageKey)
            }
        }
    }

    private func persistSession() {
        guard let currentUser else { return }
        let record = SessionRecord(user: currentUser)
        if let data = try? encoder.encode(record) {
            userDefaults.set(data, forKey: sessionStorageKey)
        }
    }
}
