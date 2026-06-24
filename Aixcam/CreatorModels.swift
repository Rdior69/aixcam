import Foundation

struct AppUser: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var email: String
    var accountType: AccountType
    var createdAt: Date
    var hasPublishedCreatorProfile: Bool
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }
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
        dashboard = CreatorDashboardSnapshot.sample
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
        ]
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
