import Foundation

/// The one type the UI shows failures through.
///
/// Every screen stores its failure as an `AppError?` named `error`, and presents
/// it with `.errorAlert(_:)` or `ErrorBanner`, so naming, wording, and dismissal
/// behave the same everywhere.
///
/// Wrapping at the boundary is also what keeps raw framework text off the
/// screen. `error.localizedDescription` on a plain `NSError` produces
/// "The operation couldn't be completed. (FIRAuthErrorDomain error 17009.)",
/// which the sign-in, broadcast, and tip screens used to show verbatim. Only a
/// `LocalizedError` that supplies its own `errorDescription` gets to write the
/// message; everything else falls back to generic copy.
///
/// Nonisolated because services throw and wrap from off the main actor, and the
/// app target defaults to main-actor isolation.
nonisolated struct AppError: Identifiable, Equatable, Sendable {

    /// Presentation identity only — see `==`.
    let id = UUID()

    /// Shown to the user. Always localized, never raw framework text.
    let message: String

    /// Untranslated detail for logs. Never displayed.
    let diagnostic: String

    // MARK: - Creating

    /// Wraps copy that is already written for a person to read.
    init(message: String) {
        self.message = message
        self.diagnostic = message
    }

    /// Wraps a thrown error, translating it into presentable copy.
    init(_ error: Error) {
        self.message = Self.message(for: error)
        self.diagnostic = String(reflecting: error)
    }

    /// `nil` for cancellation, which is routine teardown rather than a failure.
    /// SwiftUI cancels `.task` work on every view dismissal and `.task(id:)`
    /// change, and a screen the user already left must not leave an alert
    /// behind. Prefer this over `init(_:)` in any `catch` that feeds the UI.
    static func presentable(_ error: Error) -> AppError? {
        error.isCancellation ? nil : AppError(error)
    }

    /// For failures that carry no wording fit to show.
    static var generic: AppError {
        AppError(message: genericMessage)
    }

    // MARK: - Equatable

    /// Compares content, not identity. `id` exists only to drive SwiftUI
    /// presentation; two failures with the same message are the same failure as
    /// far as a view or a test is concerned.
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.message == rhs.message && lhs.diagnostic == rhs.diagnostic
    }

    // MARK: - Translation

    private static var genericMessage: String {
        String(localized: "Something went wrong. Please try again.")
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        if let urlError = error as? URLError {
            return message(for: urlError)
        }
        return genericMessage
    }

    /// Connectivity is the common failure and is worth naming plainly. Every
    /// other `URLError` is noise to the person holding the phone.
    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return String(localized: "You appear to be offline. Check your connection and try again.")
        case .timedOut:
            return String(localized: "The request timed out. Please try again.")
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return String(localized: "We couldn’t reach the server. Please try again.")
        default:
            return genericMessage
        }
    }
}

extension Error {
    /// True when the error only means "the caller went away", in either of the
    /// two shapes Swift concurrency and `URLSession` report it.
    nonisolated var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
