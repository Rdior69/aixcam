import XCTest
@testable import Aixcam

@MainActor
final class LocalCreatorBackendServiceTests: XCTestCase {
    func testSignUpRejectsInvalidEmail() async {
        let backend = makeBackend(suite: "test.backend.email")

        do {
            _ = try await backend.signUp(
                payload: SignUpPayload(
                    fullName: "Invalid Email",
                    email: "@.",
                    password: "correct-password",
                    accountType: .brand
                )
            )
            XCTFail("Expected invalid email error")
        } catch let error as CreatorBackendError {
            if case .invalidInput = error {
                // expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPublishUsesAixcamPublicURL() async throws {
        let backend = makeBackend(suite: "test.backend.publish")
        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Creator One",
                email: "creator@example.com",
                password: "correct-password",
                accountType: .creator
            )
        )

        var draft = try await backend.loadCreatorDraft(userID: user.id)
        XCTAssertNotNil(draft)
        draft?.profile.username = "creator_one"
        draft?.branding.customProfilePath = "creator_one"

        let published = try await backend.publishCreatorProfile(userID: user.id, draft: draft!)
        XCTAssertEqual(published.publicURL, "https://aixcam.app/creator/creator-one")

        let refreshed = try await backend.refreshUser(userID: user.id)
        XCTAssertTrue(refreshed.hasPublishedCreatorProfile)
    }

    func testSlugSanitization() {
        XCTAssertEqual(CreatorProfileURL.sanitizeSlug("Hello World_Path"), "hello-world-path")
        XCTAssertEqual(CreatorProfileURL.make(slug: "demo"), "https://aixcam.app/creator/demo")
    }

    private func makeBackend(suite: String) -> LocalCreatorBackendService {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: defaults
        )
    }
}
