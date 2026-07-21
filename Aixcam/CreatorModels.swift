import Foundation

struct AppUser: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var email: String
    var accountType: AccountType
    var createdAt: Date
    var hasPublishedCreatorProfile: Bool
    var accountStatus: AccountStatus
    var hasCompletedSubscriberOnboarding: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email, accountType, createdAt
        case hasPublishedCreatorProfile, accountStatus, hasCompletedSubscriberOnboarding
    }

    init(
        id: String,
        name: String,
        email: String,
        accountType: AccountType,
        createdAt: Date,
        hasPublishedCreatorProfile: Bool,
        accountStatus: AccountStatus = .active,
        hasCompletedSubscriberOnboarding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accountType = accountType
        self.createdAt = createdAt
        self.hasPublishedCreatorProfile = hasPublishedCreatorProfile
        self.accountStatus = accountStatus
        self.hasCompletedSubscriberOnboarding = hasCompletedSubscriberOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        hasPublishedCreatorProfile = try container.decode(Bool.self, forKey: .hasPublishedCreatorProfile)
        accountStatus = try container.decodeIfPresent(AccountStatus.self, forKey: .accountStatus) ?? .active
        hasCompletedSubscriberOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedSubscriberOnboarding) ?? false
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }

    /// Product direction maps fan (and temporarily brand) onto the subscriber experience.
    var isSubscriberRole: Bool {
        self == .fan || self == .brand
    }
}

enum AuthStatus: Equatable {
    case idle
    case success(String)
    case error(String)
}

enum CreatorOnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case profile
    case branding
    case content
    case subscriptions
    case aiStudio
    case dashboard
    case publish

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .profile:
            return "Profile Information"
        case .branding:
            return "Creator Branding"
        case .content:
            return "Content Creation"
        case .subscriptions:
            return "Fan Subscriptions"
        case .aiStudio:
            return "AI Studio"
        case .dashboard:
            return "Creator Dashboard"
        case .publish:
            return "Publish"
        }
    }

    var subtitle: String {
        switch self {
        case .profile:
            return "Set up profile photos, name, bio, and social links."
        case .branding:
            return "Customize your fan page style and profile URL."
        case .content:
            return "Upload media, create albums, and organize categories."
        case .subscriptions:
            return "Define free, premium, and VIP membership tiers."
        case .aiStudio:
            return "Enable AI editing workflows and content generation."
        case .dashboard:
            return "Review growth, revenue, and engagement analytics."
        case .publish:
            return "Confirm everything before launching your creator page."
        }
    }
}

struct CreatorOnboardingDraft: Codable, Equatable {
    var profile: CreatorProfileInfo
    var branding: CreatorBranding
    var content: CreatorContentSetup
    var subscriptions: CreatorSubscriptionSetup
    var aiStudio: CreatorAIStudioSetup
    var dashboard: CreatorDashboardSnapshot
    var publishedProfileURL: String?
    var lastUpdatedAt: Date

    init(user: AppUser) {
        profile = CreatorProfileInfo(
            displayName: user.name,
            username: user.email.split(separator: "@").first.map(String.init) ?? ""
        )
        branding = CreatorBranding()
        content = CreatorContentSetup()
        subscriptions = CreatorSubscriptionSetup()
        aiStudio = CreatorAIStudioSetup()
        dashboard = .empty
        publishedProfileURL = nil
        lastUpdatedAt = Date()
    }
}

struct CreatorProfileInfo: Codable, Equatable {
    var profilePhotoURL: String
    var bannerPhotoURL: String
    var displayName: String
    var username: String
    var aboutMe: String
    var location: String
    var websites: [String]
    var socialLinks: [SocialLink]

    init(
        profilePhotoURL: String = "",
        bannerPhotoURL: String = "",
        displayName: String = "",
        username: String = "",
        aboutMe: String = "",
        location: String = "",
        websites: [String] = [],
        socialLinks: [SocialLink] = []
    ) {
        self.profilePhotoURL = profilePhotoURL
        self.bannerPhotoURL = bannerPhotoURL
        self.displayName = displayName
        self.username = username
        self.aboutMe = aboutMe
        self.location = location
        self.websites = websites
        self.socialLinks = socialLinks
    }
}

struct SocialLink: Codable, Equatable, Identifiable {
    let id: String
    var platform: SocialPlatform
    var handleOrURL: String

    init(id: String = UUID().uuidString, platform: SocialPlatform, handleOrURL: String) {
        self.id = id
        self.platform = platform
        self.handleOrURL = handleOrURL
    }
}

enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram
    case tiktok
    case x
    case youtube
    case patreon
    case onlyfans
    case website

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct CreatorBranding: Codable, Equatable {
    var themeColorHex: String
    var profileStyle: ProfileStyle
    var customProfilePath: String
    var enableGlassmorphism: Bool

    init(
        themeColorHex: String = "#14b8a6",
        profileStyle: ProfileStyle = .neon,
        customProfilePath: String = "",
        enableGlassmorphism: Bool = true
    ) {
        self.themeColorHex = themeColorHex
        self.profileStyle = profileStyle
        self.customProfilePath = customProfilePath
        self.enableGlassmorphism = enableGlassmorphism
    }
}

enum ProfileStyle: String, CaseIterable, Codable, Identifiable {
    case minimal
    case neon
    case editorial
    case cinematic

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct CreatorContentSetup: Codable, Equatable {
    var mediaItems: [CreatorMediaItem]
    var albums: [CreatorAlbum]
    var categories: [String]

    init(
        mediaItems: [CreatorMediaItem] = [],
        albums: [CreatorAlbum] = [],
        categories: [String] = ["Behind the scenes", "Livestream clips", "Exclusive drops"]
    ) {
        self.mediaItems = mediaItems
        self.albums = albums
        self.categories = categories
    }
}

struct CreatorMediaItem: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var mediaType: CreatorMediaType
    var assetURL: String
    var category: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        mediaType: CreatorMediaType,
        assetURL: String,
        category: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.mediaType = mediaType
        self.assetURL = assetURL
        self.category = category
        self.createdAt = createdAt
    }
}

enum CreatorMediaType: String, CaseIterable, Codable, Identifiable {
    case photo
    case video

    var id: String { rawValue }
}

struct CreatorAlbum: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var description: String
    var mediaItemIDs: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        mediaItemIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mediaItemIDs = mediaItemIDs
    }
}

struct CreatorSubscriptionSetup: Codable, Equatable {
    var monthlyBasePrice: Double
    var freeTier: SubscriptionTier
    var premiumTier: SubscriptionTier
    var vipTier: SubscriptionTier

    init(
        monthlyBasePrice: Double = 9.99,
        freeTier: SubscriptionTier = SubscriptionTier(
            title: "Free",
            price: 0,
            isEnabled: true,
            benefits: ["Public posts", "Community updates"]
        ),
        premiumTier: SubscriptionTier = SubscriptionTier(
            title: "Premium",
            price: 19.99,
            isEnabled: true,
            benefits: ["Exclusive photo sets", "Members-only livestreams", "Priority replies"]
        ),
        vipTier: SubscriptionTier = SubscriptionTier(
            title: "VIP",
            price: 49.99,
            isEnabled: true,
            benefits: ["1:1 chat windows", "Monthly private AMA", "Early content access"]
        )
    ) {
        self.monthlyBasePrice = monthlyBasePrice
        self.freeTier = freeTier
        self.premiumTier = premiumTier
        self.vipTier = vipTier
    }
}

struct SubscriptionTier: Codable, Equatable {
    var title: String
    var price: Double
    var isEnabled: Bool
    var benefits: [String]
}

struct CreatorAIStudioSetup: Codable, Equatable {
    var backgroundRemovalEnabled: Bool
    var enhancementEnabled: Bool
    var filtersEnabled: Bool
    var captionGeneratorEnabled: Bool
    var thumbnailGeneratorEnabled: Bool
    var upscalingEnabled: Bool
    var batchEditingEnabled: Bool
    var latestCaptionSuggestion: String

    init(
        backgroundRemovalEnabled: Bool = true,
        enhancementEnabled: Bool = true,
        filtersEnabled: Bool = true,
        captionGeneratorEnabled: Bool = true,
        thumbnailGeneratorEnabled: Bool = true,
        upscalingEnabled: Bool = true,
        batchEditingEnabled: Bool = true,
        latestCaptionSuggestion: String = ""
    ) {
        self.backgroundRemovalEnabled = backgroundRemovalEnabled
        self.enhancementEnabled = enhancementEnabled
        self.filtersEnabled = filtersEnabled
        self.captionGeneratorEnabled = captionGeneratorEnabled
        self.thumbnailGeneratorEnabled = thumbnailGeneratorEnabled
        self.upscalingEnabled = upscalingEnabled
        self.batchEditingEnabled = batchEditingEnabled
        self.latestCaptionSuggestion = latestCaptionSuggestion
    }
}

struct CreatorDashboardSnapshot: Codable, Equatable {
    var monthlyRevenue: Double
    var subscriberCount: Int
    var profileViews: Int
    var engagementRate: Double
    var earningsByMonth: [EarningsPoint]
    var contentPerformance: [ContentPerformancePoint]
    var isDemoData: Bool

    enum CodingKeys: String, CodingKey {
        case monthlyRevenue, subscriberCount, profileViews, engagementRate
        case earningsByMonth, contentPerformance, isDemoData
    }

    init(
        monthlyRevenue: Double,
        subscriberCount: Int,
        profileViews: Int,
        engagementRate: Double,
        earningsByMonth: [EarningsPoint],
        contentPerformance: [ContentPerformancePoint],
        isDemoData: Bool
    ) {
        self.monthlyRevenue = monthlyRevenue
        self.subscriberCount = subscriberCount
        self.profileViews = profileViews
        self.engagementRate = engagementRate
        self.earningsByMonth = earningsByMonth
        self.contentPerformance = contentPerformance
        self.isDemoData = isDemoData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyRevenue = try container.decode(Double.self, forKey: .monthlyRevenue)
        subscriberCount = try container.decode(Int.self, forKey: .subscriberCount)
        profileViews = try container.decode(Int.self, forKey: .profileViews)
        engagementRate = try container.decode(Double.self, forKey: .engagementRate)
        earningsByMonth = try container.decode([EarningsPoint].self, forKey: .earningsByMonth)
        contentPerformance = try container.decode([ContentPerformancePoint].self, forKey: .contentPerformance)
        isDemoData = try container.decodeIfPresent(Bool.self, forKey: .isDemoData) ?? false
    }

    static let empty = CreatorDashboardSnapshot(
        monthlyRevenue: 0,
        subscriberCount: 0,
        profileViews: 0,
        engagementRate: 0,
        earningsByMonth: [
            EarningsPoint(monthLabel: "Jan", value: 0),
            EarningsPoint(monthLabel: "Feb", value: 0),
            EarningsPoint(monthLabel: "Mar", value: 0),
            EarningsPoint(monthLabel: "Apr", value: 0)
        ],
        contentPerformance: [
            ContentPerformancePoint(category: "Livestream", score: 0),
            ContentPerformancePoint(category: "Photos", score: 0),
            ContentPerformancePoint(category: "Videos", score: 0),
            ContentPerformancePoint(category: "Stories", score: 0)
        ],
        isDemoData: false
    )

    /// Optional preview dataset for design demos — not used for new drafts.
    static let sample = CreatorDashboardSnapshot(
        monthlyRevenue: 18240.58,
        subscriberCount: 1432,
        profileViews: 58012,
        engagementRate: 0.084,
        earningsByMonth: [
            EarningsPoint(monthLabel: "Jan", value: 4200),
            EarningsPoint(monthLabel: "Feb", value: 6300),
            EarningsPoint(monthLabel: "Mar", value: 7120),
            EarningsPoint(monthLabel: "Apr", value: 8240)
        ],
        contentPerformance: [
            ContentPerformancePoint(category: "Livestream", score: 92),
            ContentPerformancePoint(category: "Photos", score: 81),
            ContentPerformancePoint(category: "Videos", score: 88),
            ContentPerformancePoint(category: "Stories", score: 74)
        ],
        isDemoData: true
    )
}

struct EarningsPoint: Codable, Equatable, Identifiable {
    let id: String
    let monthLabel: String
    let value: Double

    init(id: String = UUID().uuidString, monthLabel: String, value: Double) {
        self.id = id
        self.monthLabel = monthLabel
        self.value = value
    }
}

struct ContentPerformancePoint: Codable, Equatable, Identifiable {
    let id: String
    let category: String
    let score: Double

    init(id: String = UUID().uuidString, category: String, score: Double) {
        self.id = id
        self.category = category
        self.score = score
    }
}

struct PublishedCreatorProfile: Codable, Equatable {
    var publicURL: String
    var publishedAt: Date
}
