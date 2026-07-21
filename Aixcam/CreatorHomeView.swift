import Charts
import SwiftUI

struct CreatorHomeView: View {
    @StateObject private var viewModel: CreatorHomeViewModel
    let needsSetup: Bool
    let onEditSetup: () -> Void
    let onSignOut: () -> Void

    @State private var appeared = false
    @State private var showLiveStudio = false

    init(
        user: AppUser,
        needsSetup: Bool = false,
        onEditSetup: @escaping () -> Void,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: CreatorHomeViewModel(user: user))
        self.needsSetup = needsSetup
        self.onEditSetup = onEditSetup
        self.onSignOut = onSignOut
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if needsSetup {
                        incompleteSetupBanner
                    }
                    goLiveSection
                    heroSection
                    publicPageSection
                    metricsSection
                    studioSection
                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
            }
        }
        .task {
            viewModel.load()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                appeared = true
            }
        }
        .refreshable {
            viewModel.load()
        }
        .fullScreenCover(isPresented: $showLiveStudio) {
            LiveCameraStudioView(creatorDisplayName: viewModel.displayName) {
                showLiveStudio = false
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image("AixcamIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            Text("Aixcam")
                .font(.title3.weight(.heavy))

            Spacer()

            Button("Sign out", role: .destructive, action: onSignOut)
                .buttonStyle(.bordered)
        }
    }

    private var incompleteSetupBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finish creator setup")
                .font(.headline)
            Text("Your page isn’t published yet. Continue setup when you’re ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                onEditSetup()
            } label: {
                Label("Continue setup", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var goLiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live studio")
                .font(.headline)
            Text("Open your camera, go live for fans, and manage mute or camera flip from one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showLiveStudio = true
            } label: {
                Label("Go live", systemImage: "video.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.large)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.teal.opacity(0.35), lineWidth: 1)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(needsSetup ? "Draft" : "Live")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(needsSetup ? .orange : .teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((needsSetup ? Color.orange : Color.teal).opacity(0.16), in: Capsule())

                Text("@\(viewModel.username)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Welcome back, \(viewModel.displayName)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .minimumScaleFactor(0.8)

            Text(
                needsSetup
                    ? "You’re on Creator Home. Open setup anytime to finish publishing your page."
                    : "Your creator page is published. Track growth, manage studio assets, and keep your fan page fresh."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(3)

            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 4)
            }

            if viewModel.errorMessage.isEmpty == false {
                Text(viewModel.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if viewModel.statusMessage.isEmpty == false {
                Label(viewModel.statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.teal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.statusMessage)
    }

    private var publicPageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Public fan page")
                .font(.headline)

            Text(viewModel.publicURL)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    viewModel.copyPublicURL()
                }
            } label: {
                Label("Copy page link", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.large)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Growth snapshot")
                .font(.headline)

            Text(
                viewModel.dashboard.isDemoData
                    ? "Sample preview metrics — not live analytics."
                    : "Live metrics start at zero and update as fans engage."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                homeMetric("Revenue", viewModel.dashboard.monthlyRevenue.formatted(.currency(code: "USD")))
                homeMetric("Subscribers", "\(viewModel.dashboard.subscriberCount)")
                homeMetric("Profile views", "\(viewModel.dashboard.profileViews)")
                homeMetric("Engagement", "\(Int(viewModel.dashboard.engagementRate * 100))%")
            }

            Chart(viewModel.dashboard.earningsByMonth) { point in
                BarMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Revenue", point.value)
                )
                .foregroundStyle(.teal.gradient)
            }
            .frame(height: 160)
            .accessibilityLabel("Monthly earnings chart")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var studioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Creator studio")
                .font(.headline)

            HStack(spacing: 10) {
                studioStat("\(viewModel.mediaCount)", "Media")
                studioStat("\(viewModel.albumCount)", "Albums")
                studioStat("\(viewModel.categoryCount)", "Categories")
                studioStat("\(viewModel.enabledAIToolCount)", "AI tools")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Memberships")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.membershipSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                onEditSetup()
            } label: {
                Label(
                    needsSetup ? "Continue creator setup" : "Edit creator setup",
                    systemImage: "slider.horizontal.3"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.large)

            Button("Sign out", role: .destructive, action: onSignOut)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }

    private func homeMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func studioStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.heavy))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
