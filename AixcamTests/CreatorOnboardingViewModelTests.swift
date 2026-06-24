import XCTest
@testable import Aixcam

@MainActor
final class CreatorOnboardingViewModelTests: XCTestCase {
    func testCreatorSetupStepsMatchFoundationOrder() {
        XCTAssertEqual(
            CreatorSetupStep.allCases.map(\.title),
            [
                "Profile Info",
                "Photos",
                "Fan Subscriptions",
                "AI Photo Editor",
                "Creator Dashboard",
                "Publish Profile"
            ]
        )
    }

    func testCreatorProfileDefaultsFromMember() {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)

        let profile = CreatorProfile(member: member)

        XCTAssertEqual(profile.id, member.id.uuidString)
        XCTAssertEqual(profile.ownerMemberId, member.id.uuidString)
        XCTAssertEqual(profile.displayName, "Aix Creator")
        XCTAssertEqual(profile.email, "creator@example.com")
        XCTAssertTrue(profile.completedSteps.isEmpty)
        XCTAssertFalse(profile.isPublished)
    }

    func testViewModelMovesBetweenPlaceholderSteps() async {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        let viewModel = CreatorOnboardingViewModel(member: member, service: MemoryCreatorProfileService())

        XCTAssertEqual(viewModel.selectedStep, .profileInfo)

        viewModel.moveToNextStep()
        XCTAssertEqual(viewModel.selectedStep, .photos)

        await viewModel.markSelectedStepComplete()
        XCTAssertTrue(viewModel.profile.completedSteps.contains(.photos))
        XCTAssertEqual(viewModel.selectedStep, .fanSubscriptions)

        viewModel.moveToPreviousStep()
        XCTAssertEqual(viewModel.selectedStep, .photos)
    }
}

private final class MemoryCreatorProfileService: CreatorProfileServicing {
    private var profile: CreatorProfile?

    func fetchProfile(for id: String) async throws -> CreatorProfile? {
        guard profile?.id == id else {
            return nil
        }

        return profile
    }

    func saveProfile(_ profile: CreatorProfile) async throws {
        self.profile = profile
    }
}
