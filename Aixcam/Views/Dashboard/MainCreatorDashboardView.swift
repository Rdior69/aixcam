import SwiftUI
import Charts

struct MainCreatorDashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var profile: CreatorProfile?
    @State private var analytics: CreatorAnalytics = .preview
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                .tag(0)

            profileTab
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(1)

            contentTab
                .tabItem { Label("Content", systemImage: "photo.on.rectangle.angled") }
                .tag(2)

            settingsTab
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(DesignTokens.Colors.accent)
        .task { await loadProfile() }
    }

    private var dashboardTab: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()

                ScrollView {
                    VStack(spacing: 20) {
                        if let member = authViewModel.currentMember {
                            welcomeHeader(member: member)
                        }

                        CreatorDashboardStepView(
                            viewModel: CreatorSetupViewModel(
                                member: authViewModel.currentMember ?? Member(name: "", email: "", accountType: .creator)
                            )
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    private var profileTab: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()

                ScrollView {
                    if let profile {
                        FanPagePreviewCard(
                            profile: profile,
                            profilePhotoData: nil,
                            coverPhotoData: nil
                        )
                        .padding()
                    } else {
                        EmptyStateView(
                            icon: "person.crop.circle",
                            title: "No profile",
                            message: "Complete creator setup to view your profile"
                        )
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var contentTab: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "Content Manager",
                    message: "Upload and manage your photos, videos, and albums from here"
                )
            }
            .navigationTitle("Content")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()

                VStack(spacing: 20) {
                    if let member = authViewModel.currentMember {
                        GlassCard(title: "Account") {
                            ReviewRow(label: "Name", value: member.name)
                            ReviewRow(label: "Email", value: member.email)
                            ReviewRow(label: "Type", value: member.accountType.rawValue)
                        }
                        .padding(.horizontal)
                    }

                    Button("Sign Out") {
                        authViewModel.logout()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func welcomeHeader(member: Member) -> some View {
        HStack(spacing: 14) {
            AixcamIconView(size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back, \(member.name)")
                    .font(.title2.weight(.bold))
                Text("Your creator dashboard")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
            }
            Spacer()
        }
    }

    private func loadProfile() async {
        guard let memberId = authViewModel.currentMember?.id else { return }
        profile = try? await CreatorServices.profile.loadProfile(memberId: memberId)
        if let id = profile?.id {
            analytics = (try? await CreatorServices.analytics.loadAnalytics(creatorId: id)) ?? .preview
        }
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
