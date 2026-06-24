import Combine
import Foundation

@MainActor
final class CreatorOnboardingViewModel: ObservableObject {
    @Published private(set) var profile: CreatorProfile
    @Published var selectedStep: CreatorSetupStep = .profileInfo
    @Published var profileInfoForm: CreatorProfileInfoForm
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var validationErrors: [String] = []
    @Published private(set) var isSaving = false

    let steps = CreatorSetupStep.allCases

    private let service: CreatorProfileServicing

    init(member: Member, service: CreatorProfileServicing = FirebaseCreatorProfileService()) {
        let profile = CreatorProfile(member: member)
        self.profile = profile
        self.profileInfoForm = CreatorProfileInfoForm(profile: profile)
        self.service = service
    }

    var selectedStepIndex: Int {
        steps.firstIndex(of: selectedStep) ?? 0
    }

    var isFirstStep: Bool {
        selectedStepIndex == steps.startIndex
    }

    var isLastStep: Bool {
        selectedStepIndex == steps.index(before: steps.endIndex)
    }

    func loadProfile() async {
        do {
            if let remoteProfile = try await service.fetchProfile(for: profile.id) {
                profile = remoteProfile
                profileInfoForm = CreatorProfileInfoForm(profile: remoteProfile)
                statusMessage = "Loaded creator onboarding draft."
            } else {
                await saveDraft(message: "Created creator onboarding draft.")
            }
        } catch {
            errorMessage = "Creator profile service is not ready yet."
        }
    }

    func select(_ step: CreatorSetupStep) {
        selectedStep = step
    }

    func moveToNextStep() {
        guard isLastStep == false else {
            return
        }

        selectedStep = steps[selectedStepIndex + 1]
    }

    func moveToPreviousStep() {
        guard isFirstStep == false else {
            return
        }

        selectedStep = steps[selectedStepIndex - 1]
    }

    func markSelectedStepComplete() async {
        guard profile.completedSteps.contains(selectedStep) == false else {
            moveToNextStep()
            return
        }

        profile.completedSteps.append(selectedStep)
        profile.updatedAt = Date()
        await saveDraft(message: "\(selectedStep.title) marked ready.")
        moveToNextStep()
    }

    func setProfilePhoto(data: Data?) {
        profileInfoForm.profilePhotoData = data
        clearProfileInfoMessages()
    }

    func setCoverImage(data: Data?) {
        profileInfoForm.coverImageData = data
        clearProfileInfoMessages()
    }

    func setProfileInfoError(_ message: String) {
        statusMessage = nil
        validationErrors = [message]
        errorMessage = message
    }

    func saveProfileInformationAndContinue() async {
        clearProfileInfoMessages()
        let errors = validateProfileInformation()
        guard errors.isEmpty else {
            validationErrors = errors
            errorMessage = errors.first
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var updatedProfile = profile
            updatedProfile.displayName = profileInfoForm.displayName.trimmed
            updatedProfile.username = CreatorProfileInfoForm.normalizedUsername(profileInfoForm.username)
            updatedProfile.aboutMe = profileInfoForm.aboutMe.trimmed
            updatedProfile.location = profileInfoForm.location.trimmed
            updatedProfile.websiteURL = profileInfoForm.websiteURL.trimmed
            updatedProfile.instagramURL = profileInfoForm.instagramURL.trimmed
            updatedProfile.tiktokURL = profileInfoForm.tiktokURL.trimmed
            updatedProfile.xTwitterURL = profileInfoForm.xTwitterURL.trimmed

            if let profilePhotoData = profileInfoForm.profilePhotoData {
                let path = "\(updatedProfile.id)/profile-photo.jpg"
                let url = try await service.uploadImage(data: profilePhotoData, path: path, contentType: "image/jpeg")
                updatedProfile.profilePhotoURL = url?.absoluteString ?? updatedProfile.profilePhotoURL
            }

            if let coverImageData = profileInfoForm.coverImageData {
                let path = "\(updatedProfile.id)/cover-image.jpg"
                let url = try await service.uploadImage(data: coverImageData, path: path, contentType: "image/jpeg")
                updatedProfile.coverImageURL = url?.absoluteString ?? updatedProfile.coverImageURL
            }

            if updatedProfile.completedSteps.contains(.profileInfo) == false {
                updatedProfile.completedSteps.append(.profileInfo)
            }
            updatedProfile.updatedAt = Date()

            try await service.saveProfile(updatedProfile)
            profile = updatedProfile
            profileInfoForm = CreatorProfileInfoForm(profile: updatedProfile)
            statusMessage = "Profile information saved."
            selectedStep = .photos
        } catch {
            errorMessage = "We could not save your profile information. Please try again."
        }
    }

    private func saveDraft(message: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.saveProfile(profile)
            statusMessage = message
        } catch {
            errorMessage = "Creator profile draft is local until Firebase is configured."
        }
    }

    private func validateProfileInformation() -> [String] {
        var errors: [String] = []

        if profileInfoForm.profilePhotoData == nil, profile.profilePhotoURL?.isEmpty != false {
            errors.append("Add a profile photo.")
        }

        if profileInfoForm.coverImageData == nil, profile.coverImageURL?.isEmpty != false {
            errors.append("Add a cover image.")
        }

        if profileInfoForm.displayName.trimmed.isEmpty {
            errors.append("Enter a display name.")
        }

        let username = CreatorProfileInfoForm.normalizedUsername(profileInfoForm.username)
        if username.isEmpty {
            errors.append("Enter a username.")
        } else if username.range(of: #"^[a-z0-9_]{3,24}$"#, options: .regularExpression) == nil {
            errors.append("Use 3-24 lowercase letters, numbers, or underscores for username.")
        }

        if profileInfoForm.aboutMe.trimmed.isEmpty {
            errors.append("Add an About Me description.")
        }

        for link in [
            profileInfoForm.websiteURL,
            profileInfoForm.instagramURL,
            profileInfoForm.tiktokURL,
            profileInfoForm.xTwitterURL
        ] where link.trimmed.isEmpty == false && Self.isValidAbsoluteURL(link.trimmed) == false {
            errors.append("Enter valid full links, including https://.")
            break
        }

        return errors
    }

    private func clearProfileInfoMessages() {
        statusMessage = nil
        errorMessage = nil
        validationErrors = []
    }

    private static func isValidAbsoluteURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value) else {
            return false
        }

        return components.scheme?.hasPrefix("http") == true && components.host?.isEmpty == false
    }
}

struct CreatorProfileInfoForm: Equatable {
    var profilePhotoData: Data?
    var coverImageData: Data?
    var displayName: String
    var username: String
    var aboutMe: String
    var location: String
    var websiteURL: String
    var instagramURL: String
    var tiktokURL: String
    var xTwitterURL: String

    init(profile: CreatorProfile) {
        profilePhotoData = nil
        coverImageData = nil
        displayName = profile.displayName
        username = profile.username
        aboutMe = profile.aboutMe
        location = profile.location
        websiteURL = profile.websiteURL
        instagramURL = profile.instagramURL
        tiktokURL = profile.tiktokURL
        xTwitterURL = profile.xTwitterURL
    }

    static func normalizedUsername(_ username: String) -> String {
        username.trimmed
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
