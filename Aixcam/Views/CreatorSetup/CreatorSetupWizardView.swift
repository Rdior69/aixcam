import SwiftUI

struct CreatorSetupWizardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CreatorSetupViewModel

    init(member: Member) {
        _viewModel = StateObject(wrappedValue: CreatorSetupViewModel(member: member))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()

                VStack(spacing: 0) {
                    wizardHeader

                    ScrollView {
                        VStack(spacing: 20) {
                            stepContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .id(viewModel.currentStep)

                            if let error = viewModel.errorMessage {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }

                    wizardFooter
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                }

                if viewModel.isLoading {
                    LoadingOverlay(message: "Saving your progress...")
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadExistingData()
            }
        }
    }

    private var wizardHeader: some View {
        VStack(spacing: 16) {
            HStack {
                AixcamIconView(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Creator Setup")
                        .font(.headline.weight(.bold))
                    Text(viewModel.currentStep.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sign Out") {
                    authViewModel.logout()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            WizardProgressBar(
                currentStep: viewModel.currentStep,
                totalSteps: CreatorSetupStep.totalSteps
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .profileInformation:
            ProfileInformationStepView(viewModel: viewModel)
        case .creatorBranding:
            CreatorBrandingStepView(viewModel: viewModel)
        case .contentCreation:
            ContentCreationStepView(viewModel: viewModel)
        case .fanSubscriptions:
            FanSubscriptionsStepView(viewModel: viewModel)
        case .aiStudio:
            AIStudioStepView(viewModel: viewModel)
        case .creatorDashboard:
            CreatorDashboardStepView(viewModel: viewModel)
        case .publish:
            PublishStepView(viewModel: viewModel)
        }
    }

    private var wizardFooter: some View {
        WizardNavigationBar(
            canGoBack: viewModel.currentStep.previous != nil,
            canGoForward: viewModel.canGoForward,
            isLastStep: viewModel.currentStep == .publish,
            isLoading: viewModel.isLoading,
            onBack: { viewModel.goToPreviousStep() },
            onNext: {
                if viewModel.currentStep == .publish {
                    Task { await viewModel.publish(authViewModel: authViewModel) }
                } else {
                    viewModel.goToNextStep(authViewModel: authViewModel)
                }
            }
        )
    }
}
