import Foundation

enum AppLockBackgroundTimeout: String, Codable, CaseIterable, Equatable {
    case immediate
    case oneMinute
    case fiveMinutes

    var seconds: TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        }
    }

    var title: String {
        switch self {
        case .immediate:
            return "Immediately"
        case .oneMinute:
            return "After 1 minute"
        case .fiveMinutes:
            return "After 5 minutes"
        }
    }
}

struct AppLockPolicy: Codable, Equatable {
    var isEnabled: Bool
    var biometricEnabled: Bool
    var backgroundTimeout: AppLockBackgroundTimeout

    static let `default` = AppLockPolicy(
        isEnabled: false,
        biometricEnabled: true,
        backgroundTimeout: .oneMinute
    )

    /// Whether returning from background should lock the UI.
    static func shouldLockAfterBackground(
        policy: AppLockPolicy,
        hasPIN: Bool,
        backgroundedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard policy.isEnabled, hasPIN, let backgroundedAt else {
            return false
        }
        let elapsed = now.timeIntervalSince(backgroundedAt)
        return elapsed >= policy.backgroundTimeout.seconds
    }

    /// Cold start / session restore: lock when enabled and a PIN exists.
    static func shouldLockOnAuthenticatedLaunch(policy: AppLockPolicy, hasPIN: Bool) -> Bool {
        policy.isEnabled && hasPIN
    }

    static let pinLength = 4

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count == pinLength && pin.allSatisfy(\.isNumber)
    }
}
