import Foundation

struct SubscriptionConfiguration: Codable, Equatable, Sendable {
    var freeTier: SubscriptionTier
    var premiumTier: SubscriptionTier
    var vipTier: SubscriptionTier
    var currency: String

    static let `default` = SubscriptionConfiguration(
        freeTier: .freeDefault,
        premiumTier: .premiumDefault,
        vipTier: .vipDefault,
        currency: "USD"
    )
}

struct SubscriptionTier: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var tierType: TierType
    var monthlyPrice: Decimal
    var isEnabled: Bool
    var benefits: [TierBenefit]
    var description: String

    init(
        id: UUID = UUID(),
        name: String,
        tierType: TierType,
        monthlyPrice: Decimal,
        isEnabled: Bool = true,
        benefits: [TierBenefit] = [],
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.tierType = tierType
        self.monthlyPrice = monthlyPrice
        self.isEnabled = isEnabled
        self.benefits = benefits
        self.description = description
    }

    static let freeDefault = SubscriptionTier(
        name: "Free",
        tierType: .free,
        monthlyPrice: 0,
        benefits: [
            TierBenefit(title: "Public posts", icon: "eye"),
            TierBenefit(title: "Follow updates", icon: "bell"),
            TierBenefit(title: "Comment on posts", icon: "bubble.left")
        ],
        description: "Follow for free and stay connected"
    )

    static let premiumDefault = SubscriptionTier(
        name: "Premium",
        tierType: .premium,
        monthlyPrice: 9.99,
        benefits: [
            TierBenefit(title: "Exclusive content", icon: "lock.open"),
            TierBenefit(title: "Early access drops", icon: "clock"),
            TierBenefit(title: "Member-only livestreams", icon: "video"),
            TierBenefit(title: "Direct messaging", icon: "message")
        ],
        description: "Unlock premium content and perks"
    )

    static let vipDefault = SubscriptionTier(
        name: "VIP",
        tierType: .vip,
        monthlyPrice: 24.99,
        benefits: [
            TierBenefit(title: "All Premium benefits", icon: "crown"),
            TierBenefit(title: "1:1 video calls", icon: "person.2"),
            TierBenefit(title: "Custom shoutouts", icon: "megaphone"),
            TierBenefit(title: "VIP badge", icon: "star.fill"),
            TierBenefit(title: "Priority support", icon: "bolt.fill")
        ],
        description: "The ultimate fan experience"
    )

    var formattedPrice: String {
        if tierType == .free {
            return "Free"
        }
        return String(format: "$%.2f/mo", NSDecimalNumber(decimal: monthlyPrice).doubleValue)
    }
}

enum TierType: String, Codable, CaseIterable, Identifiable, Sendable {
    case free = "Free"
    case premium = "Premium"
    case vip = "VIP"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .free: "6B7280"
        case .premium: "14B8A6"
        case .vip: "A855F7"
        }
    }
}

struct TierBenefit: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var icon: String
    var isEnabled: Bool

    init(id: UUID = UUID(), title: String, icon: String, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
    }
}
