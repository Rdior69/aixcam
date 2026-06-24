import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String?
    let subtitle: String?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
            if let title {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                    }
                }
            }
            content
        }
        .padding(DesignTokens.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
        }
    }
}

struct AuthCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                    .lineSpacing(3)
            }

            VStack(spacing: 16) {
                content
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(DesignTokens.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
        }
    }
}
