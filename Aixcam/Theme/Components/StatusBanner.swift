import SwiftUI

struct StatusBanner: View {
    let status: AuthStatus

    var body: some View {
        switch status {
        case .idle, .loading:
            EmptyView()
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall, style: .continuous))
                .accessibilityLabel("Success: \(message)")
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall, style: .continuous))
                .accessibilityLabel("Error: \(message)")
        }
    }
}

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(DesignTokens.Colors.accent)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(DesignTokens.Colors.accent.opacity(0.7))

            Text(title)
                .font(.headline.weight(.bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.Colors.accent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
