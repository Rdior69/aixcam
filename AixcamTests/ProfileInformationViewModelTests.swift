import XCTest
@testable import Aixcam

@MainActor
final class ProfileInformationViewModelTests: XCTestCase {
    func testValidationRequiresDisplayNameUsernameAndProfilePhoto() async {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        let baseProfile = CreatorProfile(member: member)
        let viewModel = ProfileInformationViewModel(
            profile: baseProfile,
            profileService: MemoryCreatorProfileService(),
            mediaService: MemoryCreatorMediaService()
        )

        viewModel.displayName = "   "
        viewModel.username = "ab"

        let result = await viewModel.saveAndContinue(baseProfile: baseProfile)

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.validationErrors[.displayName], "Enter the name fans will see on your profile.")
        XCTAssertEqual(viewModel.validationErrors[.username], "Use 3–30 letters, numbers, or underscores.")
        XCTAssertEqual(viewModel.validationErrors[.profilePhoto], "Add a profile photo to continue.")
    }

    func testSavePersistsProfileInformationAndMarksStepComplete() async {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        var baseProfile = CreatorProfile(member: member)
        baseProfile.profilePhotoURL = "https://example.com/existing-profile.jpg"
        let profileService = MemoryCreatorProfileService()
        let viewModel = ProfileInformationViewModel(
            profile: baseProfile,
            profileService: profileService,
            mediaService: MemoryCreatorMediaService()
        )

        viewModel.displayName = "Aix Creator"
        viewModel.username = "aixcreator"
        viewModel.aboutMe = "Live creator"
        viewModel.location = "Los Angeles"
        viewModel.websiteLink = "https://aixcam.example"

        let result = await viewModel.saveAndContinue(baseProfile: baseProfile)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.displayName, "Aix Creator")
        XCTAssertEqual(result?.username, "aixcreator")
        XCTAssertEqual(result?.aboutMe, "Live creator")
        XCTAssertEqual(result?.location, "Los Angeles")
        XCTAssertEqual(result?.websiteLink, "https://aixcam.example")
        XCTAssertTrue(result?.completedSteps.contains(.profileInfo) == true)
        XCTAssertEqual(result?.profilePhotoURL, "https://example.com/existing-profile.jpg")
    }

    func testInvalidWebsiteShowsError() async {
        let member = Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator)
        var baseProfile = CreatorProfile(member: member)
        baseProfile.profilePhotoURL = "https://example.com/existing-profile.jpg"
        let viewModel = ProfileInformationViewModel(
            profile: baseProfile,
            profileService: MemoryCreatorProfileService(),
            mediaService: MemoryCreatorMediaService()
        )

        viewModel.displayName = "Aix Creator"
        viewModel.username = "aixcreator"
        viewModel.websiteLink = "not-a-url"

        let result = await viewModel.saveAndContinue(baseProfile: baseProfile)

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "Website link must start with http:// or https://.")
    }
}

private final class MemoryCreatorProfileService: CreatorProfileServicing {
    private(set) var savedProfile: CreatorProfile?

    func fetchProfile(for id: String) async throws -> CreatorProfile? {
        savedProfile?.id == id ? savedProfile : nil
    }

    func saveProfile(_ profile: CreatorProfile) async throws {
        savedProfile = profile
    }
}

private final class MemoryCreatorMediaService: CreatorMediaUploadServicing {
    func uploadProfilePhoto(data: Data, profileID: String) async throws -> URL {
        _ = data
        _ = profileID
        return URL(string: "https://example.com/profile.jpg")!
    }

    func uploadCoverImage(data: Data, profileID: String) async throws -> URL {
        _ = profileID
        return URL(string: "https://example.com/cover.jpg")!
    }
}
