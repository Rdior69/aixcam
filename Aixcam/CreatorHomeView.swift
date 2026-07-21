import Charts
import SwiftUI

struct CreatorHomeView: View {
    @StateObject private var viewModel: CreatorHomeViewModel
    let onEditSetup: () -> Void
    let onContinueSetup: (() -> Void)?
    let onSignOut: () -> Void

    @State private var appeared = false

    init(
        user: AppUser,
        onEditSetup: @escaping () -> Void,
        onContinueSetup: (() -> Void)? = nil,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: CreatorHomeViewModel(user: user))
        self.onEditSetup = onEditSetup
        self.onContinueSetup = onContinueSetup
        self.onSignOut = onSignOut
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                topBar
                heroSection
                publicPageSection
                metricsSection
                studioSection
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
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

            Button("Sign out", action: onSignOut)
                .buttonStyle(.bordered)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Live")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.teal.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule().stroke(.teal.opacity(0.35), lineWidth: 1)
                    }

                Text("@\(viewModel.username)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Welcome back, \(viewModel.displayName)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .minimumScaleFactor(0.8)

            Text("Your creator page is published. Track growth, manage studio assets, and keep your fan page fresh.")
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
            if let onContinueSetup {
                Button {
                    onContinueSetup()
                } label: {
                    Label("Continue creator setup", systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.large)
            }

            if onContinueSetup == nil {
                Button {
                    onEditSetup()
                } label: {
                    Label("Edit creator setup", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.large)
            } else {
                Button {
                    onEditSetup()
                } label: {
                    Label("Open full setup wizard", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button("Sign out", action: onSignOut)
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
