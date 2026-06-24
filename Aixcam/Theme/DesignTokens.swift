import SwiftUI

enum DesignTokens {
    static let cornerRadiusLarge: CGFloat = 28
    static let cornerRadiusMedium: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 14
    static let cardPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let itemSpacing: CGFloat = 12

    enum Colors {
        static let accent = Color.teal
        static let accentSecondary = Color.purple

        static func backgroundPrimary(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.03, green: 0.04, blue: 0.08)
                : Color(red: 0.96, green: 0.97, blue: 0.99)
        }

        static func backgroundSecondary(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.05, green: 0.09, blue: 0.18)
                : Color(red: 0.92, green: 0.94, blue: 0.98)
        }

        static func backgroundTertiary(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.12, green: 0.09, blue: 0.22)
                : Color(red: 0.88, green: 0.90, blue: 0.96)
        }

        static func glassStroke(for scheme: ColorScheme) -> Color {
            scheme == .dark ? .white.opacity(0.18) : .black.opacity(0.08)
        }

        static func cardFill(for scheme: ColorScheme) -> Color {
            scheme == .dark ? .white.opacity(0.08) : .black.opacity(0.04)
        }

        static func textSecondary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? .white.opacity(0.65) : .black.opacity(0.55)
        }
    }
}

struct AdaptiveBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                DesignTokens.Colors.backgroundPrimary(for: colorScheme),
                DesignTokens.Colors.backgroundSecondary(for: colorScheme),
                DesignTokens.Colors.backgroundTertiary(for: colorScheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(DesignTokens.Colors.accent.opacity(colorScheme == .dark ? 0.28 : 0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -110, y: -100)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(DesignTokens.Colors.accentSecondary.opacity(colorScheme == .dark ? 0.28 : 0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 130, y: 20)
        }
        .ignoresSafeArea()
    }
}

struct AixcamIconView: View {
    let size: CGFloat

    var body: some View {
        Image("AixcamIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(size * 0.08)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: size * 0.1, x: 0, y: size * 0.06)
            .accessibilityLabel("Aixcam app icon")
    }
}

struct PillText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(1.2)
            .foregroundStyle(DesignTokens.Colors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignTokens.Colors.accent.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(DesignTokens.Colors.accent.opacity(0.35), lineWidth: 1)
            }
    }
}
