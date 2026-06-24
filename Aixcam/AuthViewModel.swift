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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var shouldShowCreatorOnboarding: Bool {
        guard let currentUser else { return false }
        return currentUser.accountType == .creator && currentUser.hasPublishedCreatorProfile == false
    }

    init(backendService: CreatorBackendServicing = CreatorBackendFactory.makeService()) {
        self.backendService = backendService
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        restoreSession()
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
                status = .success("Welcome to AIXLive, \(user.name).")
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
        currentUser = nil
        status = .idle
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
    }

    private func applyAuthenticatedState(for user: AppUser) {
        currentUser = user
        persistSession()
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey),
              let record = try? decoder.decode(SessionRecord.self, from: data) else {
            return
        }
        currentUser = record.user
    }

    private func persistSession() {
        guard let currentUser else { return }
        let record = SessionRecord(user: currentUser)
        if let data = try? encoder.encode(record) {
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
        }
    }
}
