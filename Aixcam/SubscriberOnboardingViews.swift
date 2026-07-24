import SwiftUI

struct SubscriberSetupWizardView: View {
    @ObservedObject var viewModel: SubscriberSetupViewModel
    let onCompleted: (AppUser) -> Void
    let onOpenHome: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ProgressView(value: viewModel.progressValue)
                .tint(.teal)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(viewModel.currentStep.title)
                        .font(.title2.weight(.bold))
                    Text(viewModel.currentStep.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    stepContent

                    if viewModel.bannerMessage.isEmpty == false {
                        Text(viewModel.bannerMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.teal)
                    }
                    if viewModel.errorMessage.isEmpty == false {
                        Text(viewModel.errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }

            footer
        }
        .task {
            viewModel.load()
        }
    }

    private var header: some View {
        HStack {
            Text("Subscriber setup")
                .font(.headline.weight(.bold))
            Spacer()
            Button("Home") { onOpenHome() }
                .buttonStyle(.bordered)
            Button("Sign out", role: .destructive, action: onSignOut)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            VStack(alignment: .leading, spacing: 12) {
                Text("You're signed in as \(viewModel.user.accountType.rawValue).")
                    .font(.body.weight(.semibold))
                Text("This short setup personalizes discovery later. You can change interests anytime.")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

        case .profile:
            VStack(alignment: .leading, spacing: 12) {
                TextField("Display name", text: $viewModel.draft.displayName)
                    .textFieldStyle(.roundedBorder)
                TextField("Short bio (optional)", text: $viewModel.draft.bio, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
            }

        case .interests:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(SubscriberOnboardingDraft.interestOptions, id: \.self) { interest in
                    let selected = viewModel.draft.interests.contains(interest)
                    Button {
                        viewModel.toggleInterest(interest)
                    } label: {
                        Text(interest)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selected ? Color.teal.opacity(0.22) : Color.secondary.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? Color.teal : Color.clear, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

        case .preferences:
            VStack(spacing: 12) {
                Toggle("Notify me about new drops", isOn: $viewModel.draft.notifyNewDrops)
                Toggle("Notify me when creators go live", isOn: $viewModel.draft.notifyLiveSessions)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep != .welcome {
                Button("Back") { viewModel.previousStep() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if viewModel.currentStep == .preferences {
                Button {
                    Task {
                        do {
                            let user = try await viewModel.completeOnboarding()
                            onCompleted(user)
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    if viewModel.isCompleting {
                        ProgressView()
                    } else {
                        Text("Finish setup")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(viewModel.isCompleting || viewModel.canMoveForward == false)
            } else {
                Button("Continue") { viewModel.nextStep() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(viewModel.canMoveForward == false)
            }
        }
        .padding(20)
    }
}

struct SubscriberAuthenticatedRoot: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let user: AppUser
    let needsOnboarding: Bool

    @State private var setupViewModel: SubscriberSetupViewModel?
    @State private var showSetup = false

    var body: some View {
        SubscriberHomeView(
            user: user,
            needsOnboarding: needsOnboarding,
            onContinueSetup: {
                configureSetup(forceReload: true)
                showSetup = true
            },
            onSignOut: {
                showSetup = false
                authViewModel.signOut()
            }
        )
        .fullScreenCover(isPresented: $showSetup) {
            NavigationStack {
                if let setupViewModel {
                    SubscriberSetupWizardView(
                        viewModel: setupViewModel,
                        onCompleted: { completedUser in
                            authViewModel.applyUser(completedUser)
                            showSetup = false
                        },
                        onOpenHome: { showSetup = false },
                        onSignOut: {
                            showSetup = false
                            authViewModel.signOut()
                        }
                    )
                } else {
                    ProgressView("Loading setup…")
                        .task { configureSetup(forceReload: true) }
                }
            }
        }
        .task {
            configureSetup()
            if needsOnboarding {
                showSetup = true
            }
        }
        .onChange(of: needsOnboarding) { _, needs in
            if needs {
                showSetup = true
            }
        }
    }

    private func configureSetup(forceReload: Bool = false) {
        if forceReload || setupViewModel?.user.id != user.id {
            setupViewModel = SubscriberSetupViewModel(user: user)
        }
    }
}
