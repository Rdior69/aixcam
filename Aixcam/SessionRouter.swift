import Foundation

enum AccountStatus: String, Codable, Equatable {
    case active
    case suspended
    case restricted
}

enum AppRootRoute: Equatable {
    case launching
    case unauthenticated
    case creatorNeedsOnboarding
    case creatorHome
    case subscriberNeedsOnboarding
    case subscriberHome
    case accountBlocked(AccountStatus)
}

enum SessionRouter {
    /// Pure routing used by `SessionManager` and unit tests.
    static func route(for user: AppUser?) -> AppRootRoute {
        guard let user else {
            return .unauthenticated
        }

        switch user.accountStatus {
        case .suspended, .restricted:
            return .accountBlocked(user.accountStatus)
        case .active:
            break
        }

        switch user.accountType {
        case .creator:
            return user.hasPublishedCreatorProfile ? .creatorHome : .creatorNeedsOnboarding
        case .fan, .brand:
            // Brand is parked on the subscriber path until a dedicated role ships.
            return user.hasCompletedSubscriberOnboarding ? .subscriberHome : .subscriberNeedsOnboarding
        }
    }
}
