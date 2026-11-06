import SwiftUI

extension View {
    /// Presents a failure modally, and clears the binding on dismissal.
    ///
    /// The standard treatment for an action the user explicitly triggered which
    /// then produced nothing — a purchase, a broadcast start, a submission.
    /// Replaces the hand-rolled `Binding(get:set:)` that each such screen had
    /// written out for itself.
    func errorAlert(
        _ error: Binding<AppError?>,
        title: LocalizedStringKey = "Something went wrong"
    ) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { error.wrappedValue = nil }
                }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { presented in
            Text(presented.message)
        }
    }
}

/// Inline failure treatment, for forms where the message belongs next to the
/// controls that produced it and the user is expected to correct and retry.
///
/// Use `.errorAlert(_:)` instead when the failure interrupts rather than
/// annotates.
struct ErrorBanner: View {

    enum Style {
        /// Centred text, no chrome. Sits under the fields on the auth screens.
        case plain
        /// Boxed and icon-led, for forms long enough that plain text is missed.
        case prominent
    }

    private let message: String
    private let style: Style

    init(_ message: String, style: Style = .plain) {
        self.message = message
        self.style = style
    }

    init(_ error: AppError, style: Style = .plain) {
        self.init(error.message, style: style)
    }

    var body: some View {
        switch style {
        case .plain:
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        case .prominent:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(message)
                    .font(.footnote)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.red.opacity(0.9))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(0.12))
            )
        }
    }
}
