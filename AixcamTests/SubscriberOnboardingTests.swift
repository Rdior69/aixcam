import XCTest
@testable import Aixcam

@MainActor
final class SubscriberOnboardingTests: XCTestCase {
    func testCompleteSubscriberOnboardingMarksUser() async throws {
        let defaults = UserDefaults(suiteName: "test.subscriber.complete")!
        defaults.removePersistentDomain(forName: "test.subscriber.complete")
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: defaults
        )
        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Sam Fan",
                email: "sam.fan@example.com",
                password: "password123",
                accountType: .fan
            )
        )
        XCTAssertFalse(user.hasCompletedSubscriberOnboarding)

        var draft = SubscriberOnboardingDraft(user: user)
        draft.displayName = "Sam"
        draft.interests = ["Music", "Live streams"]
        draft.notifyNewDrops = true

        let completed = try await backend.completeSubscriberOnboarding(userID: user.id, draft: draft)
        XCTAssertTrue(completed.hasCompletedSubscriberOnboarding)
        XCTAssertEqual(completed.name, "Sam")
        XCTAssertEqual(SessionRouter.route(for: completed), .subscriberHome)
    }

    func testSubscriberDraftRoundTrip() async throws {
        let defaults = UserDefaults(suiteName: "test.subscriber.draft")!
        defaults.removePersistentDomain(forName: "test.subscriber.draft")
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: defaults
        )
        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Brand Co",
                email: "brand@example.com",
                password: "password123",
                accountType: .brand
            )
        )

        var draft = try await backend.loadSubscriberDraft(userID: user.id)
        XCTAssertNotNil(draft)
        draft?.interests = ["Fashion"]
        draft?.currentStepRawValue = SubscriberOnboardingStep.interests.rawValue
        try await backend.saveSubscriberDraft(userID: user.id, draft: draft!)

        let reloaded = try await backend.loadSubscriberDraft(userID: user.id)
        XCTAssertEqual(reloaded?.interests, ["Fashion"])
        XCTAssertEqual(reloaded?.currentStepRawValue, SubscriberOnboardingStep.interests.rawValue)
    }

    func testSetupViewModelRequiresInterestBeforeFinish() async throws {
        let defaults = UserDefaults(suiteName: "test.subscriber.vm")!
        defaults.removePersistentDomain(forName: "test.subscriber.vm")
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: defaults
        )
        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Alex",
                email: "alex.sub@example.com",
                password: "password123",
                accountType: .fan
            )
        )
        let viewModel = SubscriberSetupViewModel(user: user, backendService: backend)
        viewModel.currentStep = .preferences
        viewModel.draft.displayName = "Alex"
        viewModel.draft.interests = []
        XCTAssertTrue(viewModel.canMoveForward)

        do {
            _ = try await viewModel.completeOnboarding()
            XCTFail("Expected completion to fail without interests")
        } catch {
            // expected
        }
    }

    func testBrandWithoutOnboardingRoutesToNeedsOnboarding() {
        let user = AppUser(
            id: "b1",
            name: "Brand",
            email: "b@example.com",
            accountType: .brand,
            createdAt: Date(),
            hasPublishedCreatorProfile: false,
            hasCompletedSubscriberOnboarding: false
        )
        XCTAssertEqual(SessionRouter.route(for: user), .subscriberNeedsOnboarding)
    }
}

@MainActor
final class CreatorOnboardingResumeTests: XCTestCase {
    func testCreatorDraftPersistsCurrentStep() async throws {
        let defaults = UserDefaults(suiteName: "test.creator.step")!
        defaults.removePersistentDomain(forName: "test.creator.step")
        let backend = LocalCreatorBackendService(
            credentialStore: MemoryCredentialStore(),
            userDefaults: defaults
        )
        let user = try await backend.signUp(
            payload: SignUpPayload(
                fullName: "Creator One",
                email: "creator.step@example.com",
                password: "password123",
                accountType: .creator
            )
        )
        var draft = try await backend.loadCreatorDraft(userID: user.id)!
        draft.currentStepRawValue = CreatorOnboardingStep.branding.rawValue
        try await backend.saveCreatorDraft(userID: user.id, draft: draft)

        let viewModel = CreatorSetupViewModel(user: user, backendService: backend)
        let deadline = Date().addingTimeInterval(2)
        viewModel.load()
        while viewModel.isLoading && Date() < deadline {
            await Task.yield()
        }
        XCTAssertEqual(viewModel.currentStep, .branding)
    }
}
