import XCTest
@testable import Aixcam

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSignUpStoresSessionAndWelcomesUser() async {
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: UserDefaults(suiteName: "test.auth.signup")!
        )
        let defaults = UserDefaults(suiteName: "test.auth.session.signup")!
        defaults.removePersistentDomain(forName: "test.auth.session.signup")

        let viewModel = AuthViewModel(
            backendService: backend,
            userDefaults: defaults,
            restoreSessionOnInit: false
        )

        viewModel.signUp(
            name: "Taylor Creator",
            email: "Taylor@Example.com",
            accountType: .creator,
            password: "correct-password"
        )

        let deadline = Date().addingTimeInterval(2)
        while viewModel.isBusy && Date() < deadline {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.currentUser?.email, "taylor@example.com")
        XCTAssertEqual(viewModel.currentUser?.name, "Taylor Creator")
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(viewModel.status, .success("Welcome to Aixcam, Taylor Creator."))
    }

    func testLoginRejectsWrongPassword() async {
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: UserDefaults(suiteName: "test.auth.login")!
        )
        _ = try? await backend.signUp(
            payload: SignUpPayload(
                fullName: "Jordan Fan",
                email: "jordan@example.com",
                password: "correct-password",
                accountType: .fan
            )
        )

        let defaults = UserDefaults(suiteName: "test.auth.session.login")!
        defaults.removePersistentDomain(forName: "test.auth.session.login")
        let viewModel = AuthViewModel(
            backendService: backend,
            userDefaults: defaults,
            restoreSessionOnInit: false
        )

        viewModel.login(email: "jordan@example.com", password: "wrong-password")
        let deadline = Date().addingTimeInterval(2)
        while viewModel.isBusy && Date() < deadline {
            await Task.yield()
        }

        XCTAssertNil(viewModel.currentUser)
        if case .error = viewModel.status {
            // expected
        } else {
            XCTFail("Expected login error status")
        }
    }

    func testRestoreSessionClearsMissingUser() async {
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: UserDefaults(suiteName: "test.auth.restore")!
        )
        let defaults = UserDefaults(suiteName: "test.auth.session.restore")!
        defaults.removePersistentDomain(forName: "test.auth.session.restore")

        let ghost = AppUser(
            id: "missing-user",
            name: "Ghost",
            email: "ghost@example.com",
            accountType: .creator,
            createdAt: Date(),
            hasPublishedCreatorProfile: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        struct SessionRecord: Codable { var user: AppUser }
        let data = try! encoder.encode(SessionRecord(user: ghost))
        defaults.set(data, forKey: "aixcam.currentSession.v2")

        let viewModel = AuthViewModel(
            backendService: backend,
            userDefaults: defaults,
            restoreSessionOnInit: true
        )

        let deadline = Date().addingTimeInterval(2)
        while viewModel.currentUser != nil && Date() < deadline {
            await Task.yield()
        }

        XCTAssertNil(viewModel.currentUser)
        XCTAssertNil(defaults.data(forKey: "aixcam.currentSession.v2"))
    }
}
