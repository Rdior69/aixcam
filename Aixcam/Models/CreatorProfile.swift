import Foundation
import SwiftUI
import UIKit

struct CreatorProfile: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var memberId: UUID
    var displayName: String
    var username: String
    var biography: String
    var location: String
    var websiteLinks: [WebsiteLink]
    var socialLinks: [SocialLink]
    var profilePhotoPath: String?
    var coverPhotoPath: String?
    var branding: CreatorBranding
    var subscriptionTiers: SubscriptionConfiguration
    var isPublished: Bool
    var customProfileURL: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        memberId: UUID,
        displayName: String = "",
        username: String = "",
        biography: String = "",
        location: String = "",
        websiteLinks: [WebsiteLink] = [],
        socialLinks: SocialLink.defaultPlatforms,
        profilePhotoPath: String? = nil,
        coverPhotoPath: String? = nil,
        branding: CreatorBranding = .default,
        subscriptionTiers: SubscriptionConfiguration = .default,
        isPublished: Bool = false,
        customProfileURL: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.memberId = memberId
        self.displayName = displayName
        self.username = username
        self.biography = biography
        self.location = location
        self.websiteLinks = websiteLinks
        self.socialLinks = socialLinks
        self.profilePhotoPath = profilePhotoPath
        self.coverPhotoPath = coverPhotoPath
        self.branding = branding
        self.subscriptionTiers = subscriptionTiers
        self.isPublished = isPublished
        self.customProfileURL = customProfileURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var fanPageURL: String {
        let slug = customProfileURL.isEmpty ? username : customProfileURL
        return "aixcam.app/@\(slug)"
    }
}

struct WebsiteLink: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), title: String = "", url: String = "") {
        self.id = id
        self.title = title
        self.url = url
    }
}

struct SocialLink: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var platform: SocialPlatform
    var handle: String

    init(id: UUID = UUID(), platform: SocialPlatform, handle: String = "") {
        self.id = id
        self.platform = platform
        self.handle = handle
    }

    static var defaultPlatforms: [SocialLink] {
        SocialPlatform.allCases.map { SocialLink(platform: $0) }
    }
}

enum SocialPlatform: String, CaseIterable, Codable, Identifiable, Sendable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case twitter = "X"
    case youtube = "YouTube"
    case onlyfans = "OnlyFans"
    case patreon = "Patreon"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .instagram: "camera"
        case .tiktok: "music.note"
        case .twitter: "at"
        case .youtube: "play.rectangle"
        case .onlyfans: "heart.circle"
        case .patreon: "dollarsign.circle"
        }
    }
}

struct CreatorBranding: Codable, Equatable, Sendable {
    var themeColorHex: String
    var accentColorHex: String
    var fontStyle: BrandFontStyle
    var layoutStyle: BrandLayoutStyle
    var showSubscriberCount: Bool
    var showTipButton: Bool

    static let `default` = CreatorBranding(
        themeColorHex: "14B8A6",
        accentColorHex: "A855F7",
        fontStyle: .rounded,
        layoutStyle: .modern,
        showSubscriberCount: true,
        showTipButton: true
    )

    var themeColor: Color {
        Color(hex: themeColorHex) ?? .teal
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .purple
    }
}

enum BrandFontStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case rounded = "Rounded"
    case serif = "Serif"
    case modern = "Modern"

    var id: String { rawValue }
}

enum BrandLayoutStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case modern = "Modern"
    case classic = "Classic"
    case minimal = "Minimal"

    var id: String { rawValue }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6, let intValue = UInt64(hexSanitized, radix: 16) else {
            return nil
        }
        let red = Double((intValue >> 16) & 0xFF) / 255
        let green = Double((intValue >> 8) & 0xFF) / 255
        let blue = Double(intValue & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "14B8A6"
        }
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}
