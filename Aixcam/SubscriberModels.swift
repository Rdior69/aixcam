import Foundation

enum SubscriberOnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case welcome
    case profile
    case interests
    case preferences

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .profile:
            return "Your profile"
        case .interests:
            return "Interests"
        case .preferences:
            return "Preferences"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "A quick setup so Aixcam can personalize your subscriber experience."
        case .profile:
            return "Tell creators how you want to show up."
        case .interests:
            return "Pick a few categories you care about."
        case .preferences:
            return "Choose alerts, then finish setup."
        }
    }
}

struct SubscriberOnboardingDraft: Codable, Equatable {
    var displayName: String
    var bio: String
    var interests: [String]
    var notifyNewDrops: Bool
    var notifyLiveSessions: Bool
    var currentStepRawValue: Int
    var lastUpdatedAt: Date

    enum CodingKeys: String, CodingKey {
        case displayName, bio, interests, notifyNewDrops, notifyLiveSessions
        case currentStepRawValue, lastUpdatedAt
    }

    init(user: AppUser) {
        displayName = user.name
        bio = ""
        interests = []
        notifyNewDrops = true
        notifyLiveSessions = true
        currentStepRawValue = SubscriberOnboardingStep.welcome.rawValue
        lastUpdatedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        interests = try container.decodeIfPresent([String].self, forKey: .interests) ?? []
        notifyNewDrops = try container.decodeIfPresent(Bool.self, forKey: .notifyNewDrops) ?? true
        notifyLiveSessions = try container.decodeIfPresent(Bool.self, forKey: .notifyLiveSessions) ?? true
        currentStepRawValue = try container.decodeIfPresent(Int.self, forKey: .currentStepRawValue)
            ?? SubscriberOnboardingStep.welcome.rawValue
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? Date()
    }

    static let interestOptions: [String] = [
        "Live streams",
        "Music",
        "Fitness",
        "Fashion",
        "Gaming",
        "Education",
        "Comedy",
        "Art"
    ]
}
