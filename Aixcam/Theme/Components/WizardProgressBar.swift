import SwiftUI

struct WizardProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let currentStep: CreatorSetupStep
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Step \(currentStep.stepNumber) of \(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                Spacer()
                Text(currentStep.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.accent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignTokens.Colors.cardFill(for: colorScheme))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.Colors.accent, DesignTokens.Colors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .frame(height: 6)
            .accessibilityLabel("Progress: step \(currentStep.stepNumber) of \(totalSteps)")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CreatorSetupStep.allCases) { step in
                        StepIndicatorPill(
                            step: step,
                            isActive: step == currentStep,
                            isCompleted: step.rawValue < currentStep.rawValue
                        )
                    }
                }
            }
        }
    }

    private var progress: CGFloat {
        CGFloat(currentStep.stepNumber) / CGFloat(totalSteps)
    }
}

private struct StepIndicatorPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: CreatorSetupStep
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isCompleted ? "checkmark" : step.icon)
                .font(.caption2)
            Text(step.title)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor, in: Capsule())
        .overlay {
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        }
        .accessibilityLabel("\(step.title) step\(isActive ? ", current" : isCompleted ? ", completed" : "")")
    }

    private var foregroundColor: Color {
        if isActive || isCompleted { return DesignTokens.Colors.accent }
        return DesignTokens.Colors.textSecondary(for: colorScheme)
    }

    private var backgroundColor: Color {
        if isActive { return DesignTokens.Colors.accent.opacity(0.15) }
        if isCompleted { return DesignTokens.Colors.accent.opacity(0.08) }
        return DesignTokens.Colors.cardFill(for: colorScheme)
    }

    private var borderColor: Color {
        if isActive { return DesignTokens.Colors.accent.opacity(0.4) }
        return DesignTokens.Colors.glassStroke(for: colorScheme)
    }
}

struct WizardNavigationBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLastStep: Bool
    let isLoading: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: onNext) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(
                            isLastStep ? "Publish" : "Continue",
                            systemImage: isLastStep ? "globe" : "chevron.right"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.Colors.accent)
            .disabled(!canGoForward || isLoading)
        }
    }
}
