import XCTest
@testable import Aixcam

@MainActor
final class CreatorHomeViewModelTests: XCTestCase {
    func testPublicURLUsesPublishedDraftSlug() async throws {
        let store = MemoryCredentialStore()
        let defaults = UserDefaults(suiteName: "test.creator.home")!
        defaults.removePersistentDomain(forName: "test.creator.home")
        let backend = LocalCreatorBackendService(credentialStore: store, userDefaults: defaults)

        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Home Creator",
                email: "home@example.com",
                password: "correct-password",
                accountType: .creator
            )
        )

        var draft = try await backend.loadCreatorDraft(userID: user.id)!
        draft.profile.username = "home_creator"
        draft.branding.customProfilePath = "home_creator"
        _ = try await backend.publishCreatorProfile(userID: user.id, draft: draft)

        let viewModel = CreatorHomeViewModel(user: user, backendService: backend)
        viewModel.load()

        let deadline = Date().addingTimeInterval(2)
        while viewModel.isLoading && Date() < deadline {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.publicURL, "https://aixcam.app/creator/home-creator")
        XCTAssertEqual(viewModel.displayName, "Home Creator")
        XCTAssertEqual(viewModel.username, "home_creator")
    }
}
