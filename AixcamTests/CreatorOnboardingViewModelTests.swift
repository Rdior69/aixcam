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

    func testProfileInformationRequiresCoreFields() async {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        let viewModel = CreatorOnboardingViewModel(member: member, service: MemoryCreatorProfileService())

        await viewModel.saveProfileInformationAndContinue()

        XCTAssertEqual(viewModel.selectedStep, .profileInfo)
        XCTAssertTrue(viewModel.validationErrors.contains("Add a profile photo."))
        XCTAssertTrue(viewModel.validationErrors.contains("Add a cover image."))
        XCTAssertTrue(viewModel.validationErrors.contains("Enter a username."))
        XCTAssertTrue(viewModel.validationErrors.contains("Add an About Me description."))
    }

    func testProfileInformationUploadsImagesSavesProfileAndContinues() async {
        let service = MemoryCreatorProfileService()
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        let viewModel = CreatorOnboardingViewModel(member: member, service: service)
        viewModel.profileInfoForm.username = "aix_creator"
        viewModel.profileInfoForm.aboutMe = "Building a fan community."
        viewModel.profileInfoForm.location = "Los Angeles"
        viewModel.profileInfoForm.websiteURL = "https://aixcam.example"
        viewModel.setProfilePhoto(data: Data([1, 2, 3]))
        viewModel.setCoverImage(data: Data([4, 5, 6]))

        await viewModel.saveProfileInformationAndContinue()

        XCTAssertEqual(viewModel.selectedStep, .photos)
        XCTAssertTrue(viewModel.profile.completedSteps.contains(.profileInfo))
        XCTAssertEqual(viewModel.profile.username, "aix_creator")
        XCTAssertEqual(viewModel.profile.aboutMe, "Building a fan community.")
        XCTAssertEqual(viewModel.profile.location, "Los Angeles")
        XCTAssertEqual(service.uploadedPaths, [
            "\(member.id.uuidString)/profile-photo.jpg",
            "\(member.id.uuidString)/cover-image.jpg"
        ])
        XCTAssertEqual(service.profile?.id, member.id.uuidString)
    }
}

private final class MemoryCreatorProfileService: CreatorProfileServicing {
    var profile: CreatorProfile?
    var uploadedPaths: [String] = []

    func fetchProfile(for id: String) async throws -> CreatorProfile? {
        guard profile?.id == id else {
            return nil
        }

        return profile
    }

    func saveProfile(_ profile: CreatorProfile) async throws {
        self.profile = profile
    }

    func uploadImage(data: Data, path: String, contentType: String) async throws -> URL? {
        uploadedPaths.append(path)
        return URL(string: "https://storage.example/\(path)")
    }
}
