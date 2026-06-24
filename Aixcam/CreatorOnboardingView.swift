import SwiftUI

struct CreatorOnboardingView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CreatorOnboardingViewModel

    init(member: Member, service: CreatorProfileServicing = FirebaseCreatorProfileService()) {
        _viewModel = StateObject(wrappedValue: CreatorOnboardingViewModel(member: member, service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            onboardingHeader
            stepSelector
            stepContent
            actionBar
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .task {
            await viewModel.loadProfile()
        }
    }

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.square.badge.video")
                    .font(.title2)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator onboarding")
                        .font(.largeTitle.weight(.black))
                        .minimumScaleFactor(0.8)

                    Text(viewModel.profile.displayName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Complete each setup step to publish your creator profile.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Creator onboarding status. \(statusMessage)")
            }
        }
    }

    private var stepSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup steps")
                .font(.headline)

            ForEach(viewModel.steps) { step in
                Button {
                    viewModel.select(step)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: step.systemImage)
                            .frame(width: 24)
                        Text(step.title)
                        Spacer()
                        if viewModel.profile.completedSteps.contains(step) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if viewModel.selectedStep == step {
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                    .padding(12)
                    .background(stepBackground(for: step), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the \(step.title) placeholder.")
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        if viewModel.selectedStep == .profileInfo {
            ProfileInformationView(onboardingViewModel: viewModel)
        } else {
            CreatorOnboardingStepPlaceholder(step: viewModel.selectedStep)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Back") {
                    viewModel.moveToPreviousStep()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isFirstStep)

                if viewModel.selectedStep != .profileInfo {
                    Button(viewModel.isLastStep ? "Review" : "Next") {
                        viewModel.moveToNextStep()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLastStep)

                    Button {
                        Task {
                            await viewModel.markSelectedStepComplete()
                        }
                    } label: {
                        Label("Mark placeholder ready", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(viewModel.isSaving)
                }
            }

            Button {
                authViewModel.logout()
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func stepBackground(for step: CreatorSetupStep) -> Color {
        if viewModel.selectedStep == step {
            return .teal.opacity(0.18)
        }

        return .white.opacity(0.08)
    }
}

private struct CreatorOnboardingStepPlaceholder: View {
    let step: CreatorSetupStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(step.title, systemImage: step.systemImage)
                .font(.title2.weight(.bold))

            Text(step.placeholderDescription)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            Text("Placeholder screen only. Data entry, uploads, subscriptions, AI tooling, dashboard metrics, and publishing logic will be added in later phases.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    CreatorOnboardingView(member: Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator))
        .environmentObject(AuthViewModel())
        .padding()
        .background(Color(red: 0.03, green: 0.04, blue: 0.08))
}
