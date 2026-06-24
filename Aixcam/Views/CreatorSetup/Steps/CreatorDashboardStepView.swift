import SwiftUI
import Charts

struct CreatorDashboardStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Creator Dashboard",
                subtitle: "Preview your analytics and performance metrics"
            ) {
                VStack(spacing: 20) {
                    metricsGrid
                    revenueChart
                    subscriberChart
                    topContentSection
                }
            }

            Text("Analytics will populate with real data once your profile is live.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AnalyticsMetricCard(
                title: "Monthly Revenue",
                value: formatCurrency(viewModel.analytics.monthlyRevenue),
                change: "+\(String(format: "%.1f", viewModel.analytics.profileViewsChange))%",
                icon: "dollarsign.circle.fill",
                color: DesignTokens.Colors.accent
            )
            AnalyticsMetricCard(
                title: "Subscribers",
                value: "\(viewModel.analytics.totalSubscribers)",
                change: "+\(viewModel.analytics.premiumSubscribers + viewModel.analytics.vipSubscribers) paid",
                icon: "person.3.fill",
                color: DesignTokens.Colors.accentSecondary
            )
            AnalyticsMetricCard(
                title: "Profile Views",
                value: formatNumber(viewModel.analytics.profileViews),
                change: "+\(String(format: "%.1f", viewModel.analytics.profileViewsChange))%",
                icon: "eye.fill",
                color: .blue
            )
            AnalyticsMetricCard(
                title: "Engagement",
                value: "\(String(format: "%.1f", viewModel.analytics.engagementRate))%",
                change: "\(formatNumber(viewModel.analytics.contentViews)) views",
                icon: "heart.fill",
                color: .pink
            )
        }
    }

    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Revenue Trend")
                .font(.subheadline.weight(.semibold))

            Chart(viewModel.analytics.revenueByMonth) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Revenue", NSDecimalNumber(decimal: item.amount).doubleValue)
                )
                .foregroundStyle(DesignTokens.Colors.accent.gradient)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private var subscriberChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscriber Growth")
                .font(.subheadline.weight(.semibold))

            Chart(viewModel.analytics.subscriberGrowth) { point in
                LineMark(
                    x: .value("Month", point.label),
                    y: .value("Subscribers", point.count)
                )
                .foregroundStyle(DesignTokens.Colors.accentSecondary)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Month", point.label),
                    y: .value("Subscribers", point.count)
                )
                .foregroundStyle(DesignTokens.Colors.accentSecondary.opacity(0.15))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 140)
        }
    }

    private var topContentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Performing Content")
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.analytics.topPerformingContent) { content in
                HStack {
                    Image(systemName: content.type.icon)
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(.caption.weight(.medium))
                        Text("\(formatNumber(content.views)) views")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(content.revenue))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
                .padding(10)
                .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", Double(value) / 1000)
        }
        return "\(value)"
    }
}

private struct AnalyticsMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let change: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.black))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(change)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(14)
        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }
}
