import Foundation

/// Client-side checks for the auth forms.
///
/// These exist to give a clear message before the network call — Firebase's own
/// errors are cryptic ("The password must be 6 characters long or more") and
/// arrive only after a round trip. They are a UX affordance, never a security
/// boundary; the server still enforces its own rules.
enum AuthValidation {

    static let minimumPasswordLength = 8

    // Deliberately permissive: something@something.tld. Strict RFC 5322 matching
    // rejects addresses that are in fact deliverable, which is worse than letting
    // a typo through to Firebase.
    private static let emailRegex = /^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$/

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.wholeMatch(of: emailRegex) != nil
    }

    /// Password strength buckets, used for both the meter and the submit gate.
    enum PasswordStrength: Int, Comparable, Sendable {
        case tooShort = 0
        case weak
        case fair
        case strong

        static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .tooShort: return "Too short"
            case .weak:     return "Weak"
            case .fair:     return "Fair"
            case .strong:   return "Strong"
            }
        }

        /// Fraction of the meter to fill, 0...1.
        var fill: Double {
            switch self {
            case .tooShort: return 0.15
            case .weak:     return 0.4
            case .fair:     return 0.7
            case .strong:   return 1.0
            }
        }
    }

    static func strength(of password: String) -> PasswordStrength {
        guard password.count >= minimumPasswordLength else { return .tooShort }

        var classes = 0
        if password.contains(where: \.isLowercase) { classes += 1 }
        if password.contains(where: \.isUppercase) { classes += 1 }
        if password.contains(where: \.isNumber) { classes += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { classes += 1 }

        if password.count >= 12 && classes >= 3 { return .strong }
        if classes >= 2 { return .fair }
        return .weak
    }

    /// A password is acceptable once it clears the length floor. We surface the
    /// strength meter to encourage better, but refusing "weak" here just pushes
    /// people toward writing passwords down.
    static func isAcceptablePassword(_ password: String) -> Bool {
        strength(of: password) > .tooShort
    }
}
