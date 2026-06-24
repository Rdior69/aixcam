import SwiftUI

enum AuthRoute: Equatable {
    case home
    case signup
    case login
}

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var route: AuthRoute = .home

    var body: some View {
        Group {
            if let member = authViewModel.currentMember {
                CreatorExperienceView(member: member)
            } else {
                AuthFlowView(route: $route)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: authViewModel.isAuthenticated)
    }
}

private struct AuthFlowView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()

                ScrollView {
                    VStack(spacing: 28) {
                        HeaderView(route: $route)

                        switch route {
                        case .home:
                            LandingView(route: $route)
                        case .signup:
                            SignUpView(route: $route)
                        case .login:
                            LoginView(route: $route)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: route) {
                authViewModel.resetStatus()
            }
        }
    }
}

private struct HeaderView: View {
    @Binding var route: AuthRoute

    var body: some View {
        HStack(spacing: 12) {
            Button {
                route = .home
            } label: {
                HStack(spacing: 12) {
                    AixcamIconView(size: 48)
                    Text("Aixcam")
                        .font(.headline.weight(.bold))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Login") {
                route = .login
            }
            .buttonStyle(.bordered)

            Button("Join") {
                route = .signup
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
    }
}

private struct LandingView: View {
    @Binding var route: AuthRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                PillText("Creator onboarding, ready after signup.")

                Text("Launch your creator business with a guided Aixcam studio.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineSpacing(-4)

                Text("Build your fan page, upload media, configure subscriptions, unlock AI tools, and publish a polished creator profile from one mobile-first flow.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                Button {
                    route = .signup
                } label: {
                    Label("Create your account", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.teal)

                Button {
                    route = .login
                } label: {
                    Label("I already have an account", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            FeatureCard()
        }
    }
}

private struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accountType = AccountType.creator

    var body: some View {
        AuthCard(
            title: "Create your Aixcam account.",
            subtitle: "Sign up to unlock livestreams, fan subscriptions, creator tools, virtual gifting, premium drops, and AI-powered experiences."
        ) {
            TextField("Full name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()

            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Picker("Joining as", selection: $accountType) {
                ForEach(AccountType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            SecureField("Password", text: $password)
                .textContentType(.newPassword)

            StatusBanner(status: authViewModel.status)

            Button {
                authViewModel.signUp(
                    name: name,
                    email: email,
                    accountType: accountType,
                    password: password
                )

                if case .success = authViewModel.status {
                    name = ""
                    email = ""
                    password = ""
                    accountType = .creator
                }
            } label: {
                Text("Create account and start setup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Button("Already signed up? Login") {
                route = .login
            }
            .buttonStyle(.plain)
            .foregroundStyle(.teal)
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        AuthCard(
            title: "Welcome back to Aixcam.",
            subtitle: "Log in to manage livestreams, subscriptions, virtual gifts, premium content, fan messaging, and creator growth tools."
        ) {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .textContentType(.password)

            StatusBanner(status: authViewModel.status)

            Button {
                authViewModel.login(email: email, password: password)
            } label: {
                Text("Log in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Button("New to Aixcam? Create an account") {
                route = .signup
            }
            .buttonStyle(.plain)
            .foregroundStyle(.teal)
        }
    }
}

private struct CreatorExperienceView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var setupViewModel: CreatorSetupViewModel

    init(member: Member) {
        _setupViewModel = StateObject(wrappedValue: CreatorSetupViewModel(member: member))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()

                ScrollView {
                    VStack(spacing: 22) {
                        CreatorTopBar(
                            member: setupViewModel.member,
                            isPublished: setupViewModel.isPublished,
                            logout: authViewModel.logout
                        )

                        if setupViewModel.isPublished {
                            PublishedCreatorHome(viewModel: setupViewModel)
                        } else {
                            CreatorWizardView(viewModel: setupViewModel)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

private struct CreatorTopBar: View {
    let member: Member
    let isPublished: Bool
    let logout: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AixcamIconView(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline.weight(.bold))
                Text(isPublished ? "Creator profile live" : "Creator setup wizard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Logout", action: logout)
                .buttonStyle(.bordered)
                .accessibilityLabel("Log out of Aixcam")
        }
    }
}

private struct CreatorWizardView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(spacing: 18) {
            SetupProgressHeader(viewModel: viewModel)

            GlassCard {
                switch viewModel.currentStep {
                case .profile:
                    ProfileInformationStep(profile: $viewModel.profile, addWebsite: viewModel.addWebsiteLink, addSocial: viewModel.addSocialLink)
                case .branding:
                    CreatorBrandingStep(profile: $viewModel.profile)
                case .content:
                    ContentCreationStep(viewModel: viewModel)
                case .subscriptions:
                    FanSubscriptionsStep(profile: $viewModel.profile)
                case .aiStudio:
                    AIStudioStep(profile: $viewModel.profile)
                case .dashboard:
                    DashboardSetupStep(profile: $viewModel.profile)
                case .publish:
                    PublishStep(profile: viewModel.profile)
                }
            }

            StatusBanner(status: viewModel.status)

            HStack(spacing: 12) {
                Button {
                    viewModel.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.currentStep == .profile)

                Button {
                    viewModel.continueFromCurrentStep()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(viewModel.currentStep.nextTitle, systemImage: viewModel.currentStep == .publish ? "paperplane.fill" : "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.teal)
            }
        }
    }
}

private struct SetupProgressHeader: View {
    @ObservedObject var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: viewModel.currentStep.icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.teal)
                    .frame(width: 48, height: 48)
                    .background(.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.currentStep.eyebrow)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.teal)
                        .textCase(.uppercase)
                    Text(viewModel.currentStep.title)
                        .font(.title.weight(.black))
                        .minimumScaleFactor(0.8)
                    Text("Complete each section to publish your fan page with subscriptions, content, AI tools, and analytics ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: viewModel.currentStep.progress)
                .tint(.teal)

            StepRail(currentStep: viewModel.currentStep, completedSteps: viewModel.profile.completedSteps)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct StepRail: View {
    let currentStep: CreatorSetupStep
    let completedSteps: Set<CreatorSetupStep>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CreatorSetupStep.allCases) { step in
                    HStack(spacing: 6) {
                        Image(systemName: completedSteps.contains(step) ? "checkmark.circle.fill" : step.icon)
                        Text(step.title)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundStyle(step == currentStep ? .white : .secondary)
                    .background(step == currentStep ? Color.teal : Color.primary.opacity(0.08), in: Capsule())
                }
            }
        }
        .accessibilityLabel("Creator setup progress")
    }
}

private struct ProfileInformationStep: View {
    @Binding var profile: CreatorProfile
    let addWebsite: () -> Void
    let addSocial: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Make your creator profile recognizable.", subtitle: "Add the essentials fans see first.")

            VStack(spacing: 12) {
                TextField("Profile photo storage path", text: $profile.profilePhotoPath)
                    .textContentType(.URL)
                TextField("Cover/banner storage path", text: $profile.coverImagePath)
                    .textContentType(.URL)
                TextField("Display name", text: $profile.displayName)
                TextField("Username", text: $profile.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("About Me biography", text: $profile.biography, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Location (optional)", text: $profile.location)
            }
            .textFieldStyle(.roundedBorder)

            EditableLinks(title: "Website links", links: $profile.websiteLinks, addAction: addWebsite)
            EditableLinks(title: "Social media links", links: $profile.socialLinks, addAction: addSocial)
        }
    }
}

private struct EditableLinks: View {
    let title: String
    @Binding var links: [String]
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: addAction) {
                    Label("Add", systemImage: "plus")
                }
                .font(.caption.weight(.bold))
            }

            ForEach(links.indices, id: \.self) { index in
                TextField(title, text: $links[index])
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

private struct CreatorBrandingStep: View {
    @Binding var profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Shape the fan page experience.", subtitle: "Pick a theme, profile URL, and mobile page treatment.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                ForEach(CreatorTheme.allCases) { theme in
                    Button {
                        profile.theme = theme
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Circle()
                                .fill(Color(hex: theme.hex))
                                .frame(width: 34, height: 34)
                            Text(theme.rawValue)
                                .font(.headline)
                            Text(theme.hex)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(profile.theme == theme ? Color(hex: theme.hex).opacity(0.2) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(theme.rawValue) theme")
                }
            }

            TextField("Custom profile URL", text: $profile.customProfileURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            TextField("Profile customization notes", text: $profile.appearanceNotes, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)

            FanPagePreview(profile: profile)
        }
    }
}

private struct ContentCreationStep: View {
    @ObservedObject var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Upload and organize launch content.", subtitle: "Prototype photo, video, album, category, and drag reorder management.")

            HStack(spacing: 10) {
                ForEach(MediaKind.allCases) { kind in
                    Button {
                        viewModel.addMediaItem(kind: kind)
                    } label: {
                        Label(kind.rawValue, systemImage: kind.icon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack {
                Text("Categories")
                    .font(.headline)
                Spacer()
                Button("Add category", action: viewModel.addCategory)
                    .font(.caption.weight(.bold))
            }

            ForEach(viewModel.profile.categories.indices, id: \.self) { index in
                TextField("Category", text: $viewModel.profile.categories[index])
                    .textFieldStyle(.roundedBorder)
            }

            List {
                ForEach($viewModel.profile.mediaItems) { $item in
                    HStack(spacing: 12) {
                        Image(systemName: item.kind.icon)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Media title", text: $item.title)
                            TextField("Category", text: $item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: viewModel.moveMedia)
            }
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("Use Edit in Xcode preview or a device build to drag media into the desired fan page order.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FanSubscriptionsStep: View {
    @Binding var profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Configure fan memberships.", subtitle: "Set Free, Premium, and VIP pricing and benefits.")

            ForEach($profile.subscriptionTiers) { $tier in
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $tier.isEnabled) {
                        TextField("Tier name", text: $tier.name)
                            .font(.headline)
                    }

                    HStack {
                        Text("Monthly price")
                        Spacer()
                        TextField("Price", value: $tier.monthlyPrice, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    ForEach(tier.benefits.indices, id: \.self) { index in
                        TextField("Benefit", text: $tier.benefits[index])
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            SubscriptionPreview(tiers: profile.subscriptionTiers)
        }
    }
}

private struct AIStudioStep: View {
    @Binding var profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Prepare AI-assisted creator tools.", subtitle: "Enable image, caption, thumbnail, upscaling, and batch editing workflows.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(AIStudioTool.defaultTools) { tool in
                    let isEnabled = profile.aiTools.contains(tool.title)

                    Button {
                        if isEnabled {
                            profile.aiTools.removeAll { $0 == tool.title }
                        } else {
                            profile.aiTools.append(tool.title)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: tool.icon)
                                .font(.title2)
                                .foregroundStyle(.teal)
                            Text(tool.title)
                                .font(.headline)
                            Text(tool.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(isEnabled ? Color.teal.opacity(0.18) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DashboardSetupStep: View {
    @Binding var profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Review the creator dashboard.", subtitle: "Analytics cards are ready for revenue, subscribers, views, engagement, earnings, and content performance.")

            AnalyticsGrid(analytics: profile.analytics)

            VStack(alignment: .leading, spacing: 10) {
                Label("Earnings reports", systemImage: "doc.text.magnifyingglass")
                Label("Subscriber analytics", systemImage: "person.3.fill")
                Label("Content performance charts", systemImage: "chart.bar.xaxis")
                Label("Real-time profile updates", systemImage: "bolt.horizontal.circle.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }
}

private struct PublishStep: View {
    let profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Review and publish.", subtitle: "Confirm your public fan page, subscriptions, media, AI tools, and Firebase data map.")

            FanPagePreview(profile: profile)
            SubscriptionPreview(tiers: profile.subscriptionTiers)

            VStack(alignment: .leading, spacing: 10) {
                Text("Firebase structure")
                    .font(.headline)
                ForEach(FirebaseCreatorBlueprint.firestoreCollections, id: \.self) { collection in
                    Label(collection, systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PublishedCreatorHome: View {
    @ObservedObject var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    PillText("Published")
                    Text("Creator dashboard")
                        .font(.largeTitle.weight(.black))
                    Text("Your creator profile is live with fan subscriptions, content collections, AI tools, and analytics connected.")
                        .foregroundStyle(.secondary)
                    FanPagePreview(profile: viewModel.profile)
                }
            }

            GlassCard {
                DashboardSetupStep(profile: $viewModel.profile)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.black))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct FanPagePreview: View {
    let profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: profile.theme.hex), .purple.opacity(0.7), .black.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 154)

                VStack(alignment: .leading, spacing: 8) {
                    Circle()
                        .fill(.thinMaterial)
                        .frame(width: 68, height: 68)
                        .overlay {
                            Text(String(profile.displayName.prefix(1)))
                                .font(.title.weight(.black))
                        }

                    Text(profile.displayName)
                        .font(.title2.weight(.black))
                    Text("@\(profile.username) · \(profile.customProfileURL)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
                .foregroundStyle(.white)
                .padding()
            }

            Text(profile.biography)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(profile.categories.prefix(3), id: \.self) { category in
                    Text(category)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: profile.theme.hex).opacity(0.16), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fan page preview for \(profile.displayName)")
    }
}

private struct SubscriptionPreview: View {
    let tiers: [SubscriptionTier]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription preview")
                .font(.headline)

            ForEach(tiers.filter(\.isEnabled)) { tier in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tier.monthlyPrice == 0 ? "gift.fill" : "crown.fill")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.name)
                            .font(.headline)
                        Text(tier.monthlyPrice, format: .currency(code: "USD"))
                            .font(.subheadline.weight(.bold))
                        Text(tier.benefits.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct AnalyticsGrid: View {
    let analytics: CreatorAnalytics

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            MetricView(value: analytics.monthlyRevenue.formatted(.currency(code: "USD")), label: "Monthly revenue")
            MetricView(value: "\(analytics.subscribers)", label: "Subscribers")
            MetricView(value: "\(analytics.profileViews)", label: "Profile views")
            MetricView(value: "\(analytics.engagementRate, specifier: "%.1f")%", label: "Engagement")
        }

        Text("Top content: \(analytics.topContent)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct AuthCard<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AixcamIconView(size: 76)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.largeTitle.weight(.black))
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            VStack(spacing: 16) {
                content
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct FeatureCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AixcamIconView(size: 128)

            Text("Designed for high-touch fan communities.")
                .font(.title2.weight(.bold))

            Text("Bring onboarding, membership access, creator tools, and premium fan engagement together in a responsive mobile experience.")
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                MetricView(value: "24/7", label: "Creator access")
                MetricView(value: "1:1", label: "Fan moments")
                MetricView(value: "AI", label: "Assisted growth")
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct MetricView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline.weight(.black))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatusBanner: View {
    let status: AuthStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct AixcamIconView: View {
    let size: CGFloat

    var body: some View {
        Image("AixcamIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(size * 0.08)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: size * 0.12, x: 0, y: size * 0.08)
            .accessibilityLabel("Aixcam app icon")
    }
}

private struct PillText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(1.2)
            .foregroundStyle(.teal)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.teal.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.teal.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.teal.opacity(0.16),
                Color.purple.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(.teal.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -110, y: -100)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.purple.opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 130, y: 20)
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
