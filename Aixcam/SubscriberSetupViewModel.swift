import Foundation
import SwiftUI

@MainActor
final class SubscriberSetupViewModel: ObservableObject {
    @Published var draft: SubscriberOnboardingDraft
    @Published var currentStep: SubscriberOnboardingStep = .welcome
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isCompleting = false
    @Published var errorMessage = ""
    @Published var bannerMessage = ""

    let user: AppUser
    private let backendService: CreatorBackendServicing

    init(user: AppUser, backendService: CreatorBackendServicing = CreatorBackendFactory.makeService()) {
        self.user = user
        self.backendService = backendService
        self.draft = SubscriberOnboardingDraft(user: user)
    }

    var progressValue: Double {
        Double(currentStep.rawValue + 1) / Double(SubscriberOnboardingStep.allCases.count)
    }

    var canMoveForward: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .profile:
            return draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .interests:
            return draft.interests.isEmpty == false
        case .preferences:
            return true
        }
    }

    func load() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = ""
        Task {
            do {
                if let existing = try await backendService.loadSubscriberDraft(userID: user.id) {
                    draft = existing
                } else {
                    draft = SubscriberOnboardingDraft(user: user)
                    try await backendService.saveSubscriberDraft(userID: user.id, draft: draft)
                }
                currentStep = SubscriberOnboardingStep(rawValue: draft.currentStepRawValue) ?? .welcome
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func nextStep() {
        guard canMoveForward else {
            errorMessage = "Complete this step before continuing."
            return
        }
        errorMessage = ""
        guard let next = SubscriberOnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        withAnimation(.smooth) {
            currentStep = next
        }
        draft.currentStepRawValue = currentStep.rawValue
        saveProgress(message: "Progress saved.")
    }

    func previousStep() {
        guard let previous = SubscriberOnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        withAnimation(.smooth) {
            currentStep = previous
        }
        draft.currentStepRawValue = currentStep.rawValue
        saveProgress()
    }

    func toggleInterest(_ interest: String) {
        if let index = draft.interests.firstIndex(of: interest) {
            draft.interests.remove(at: index)
        } else {
            draft.interests.append(interest)
        }
    }

    func saveProgress(message: String = "") {
        isSaving = true
        draft.lastUpdatedAt = Date()
        draft.currentStepRawValue = currentStep.rawValue
        Task {
            do {
                try await backendService.saveSubscriberDraft(userID: user.id, draft: draft)
                if message.isEmpty == false {
                    bannerMessage = message
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    func completeOnboarding() async throws -> AppUser {
        guard canMoveForward else {
            throw CreatorBackendError.invalidInput("Finish the required fields first.")
        }
        isCompleting = true
        errorMessage = ""
        defer { isCompleting = false }
        draft.currentStepRawValue = SubscriberOnboardingStep.preferences.rawValue
        draft.lastUpdatedAt = Date()
        return try await backendService.completeSubscriberOnboarding(userID: user.id, draft: draft)
    }
}
