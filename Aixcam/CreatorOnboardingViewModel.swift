import Combine
import Foundation

@MainActor
final class CreatorOnboardingViewModel: ObservableObject {
    @Published private(set) var profile: CreatorProfile
    @Published var selectedStep: CreatorSetupStep = .profileInfo
    @Published private(set) var statusMessage: String?
    @Published private(set) var isSaving = false

    let steps = CreatorSetupStep.allCases

    private let service: CreatorProfileServicing

    init(member: Member, service: CreatorProfileServicing = FirebaseCreatorProfileService()) {
        self.profile = CreatorProfile(member: member)
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
                statusMessage = "Loaded creator onboarding draft."
            } else {
                await saveDraft(message: "Created creator onboarding draft.")
            }
        } catch {
            statusMessage = "Creator profile service is not ready yet."
        }
    }

    func applyProfileUpdate(_ profile: CreatorProfile) {
        self.profile = profile
        statusMessage = "Profile information saved."
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

    private func saveDraft(message: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.saveProfile(profile)
            statusMessage = message
        } catch {
            statusMessage = "Creator profile draft is local until Firebase is configured."
        }
    }
}
