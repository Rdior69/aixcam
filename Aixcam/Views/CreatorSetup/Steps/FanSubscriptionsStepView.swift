import SwiftUI

struct FanSubscriptionsStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Fan Subscriptions",
                subtitle: "Set up membership tiers and benefits for your fans"
            ) {
                VStack(spacing: 16) {
                    SubscriptionTierCard(
                        tier: $viewModel.profile.subscriptionTiers.freeTier,
                        onChange: { viewModel.debouncedSave() }
                    )
                    SubscriptionTierCard(
                        tier: $viewModel.profile.subscriptionTiers.premiumTier,
                        onChange: { viewModel.debouncedSave() }
                    )
                    SubscriptionTierCard(
                        tier: $viewModel.profile.subscriptionTiers.vipTier,
                        onChange: { viewModel.debouncedSave() }
                    )
                }
            }

            SubscriptionPreviewCard(configuration: viewModel.profile.subscriptionTiers)
        }
    }
}

private struct SubscriptionTierCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var tier: SubscriptionTier
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: tier.tierType.color) ?? .gray)
                            .frame(width: 10, height: 10)
                        Text(tier.name)
                            .font(.headline.weight(.bold))
                    }
                    Text(tier.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if tier.tierType != .free {
                    Toggle("", isOn: $tier.isEnabled)
                        .labelsHidden()
                        .onChange(of: tier.isEnabled) { onChange() }
                }
            }

            if tier.tierType != .free && tier.isEnabled {
                HStack {
                    Text("Monthly price")
                        .font(.caption)
                    Spacer()
                    Text("$")
                    TextField("0.00", value: $tier.monthlyPrice, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: tier.monthlyPrice) { onChange() }
                    Text("/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(tier.formattedPrice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Benefits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach($tier.benefits) { $benefit in
                    HStack(spacing: 8) {
                        Image(systemName: benefit.icon)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Colors.accent)
                            .frame(width: 20)
                        Text(benefit.title)
                            .font(.caption)
                        Spacer()
                        if tier.tierType != .free {
                            Toggle("", isOn: $benefit.isEnabled)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .onChange(of: benefit.isEnabled) { onChange() }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium))
        .opacity(tier.tierType != .free && !tier.isEnabled ? 0.6 : 1)
    }
}

struct SubscriptionPreviewCard: View {
    let configuration: SubscriptionConfiguration
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Preview")
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.accent)

            Text("What fans will see")
                .font(.subheadline.weight(.semibold))

            ForEach(activeTiers) { tier in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name)
                            .font(.subheadline.weight(.bold))
                        Text(tier.formattedPrice)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(tier.benefits.filter(\.isEnabled).prefix(2)) { benefit in
                            Text(benefit.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
        }
    }

    private var activeTiers: [SubscriptionTier] {
        [configuration.freeTier, configuration.premiumTier, configuration.vipTier]
            .filter { $0.tierType == .free || $0.isEnabled }
    }
}
