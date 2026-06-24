import Foundation

enum CreatorSetupStep: String, CaseIterable, Codable, Identifiable {
    case profileInfo
    case photos
    case fanSubscriptions
    case aiPhotoEditor
    case creatorDashboard
    case publishProfile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profileInfo:
            return "Profile Info"
        case .photos:
            return "Photos"
        case .fanSubscriptions:
            return "Fan Subscriptions"
        case .aiPhotoEditor:
            return "AI Photo Editor"
        case .creatorDashboard:
            return "Creator Dashboard"
        case .publishProfile:
            return "Publish Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .profileInfo:
            return "person.text.rectangle"
        case .photos:
            return "photo.on.rectangle"
        case .fanSubscriptions:
            return "creditcard"
        case .aiPhotoEditor:
            return "sparkles"
        case .creatorDashboard:
            return "chart.bar.xaxis"
        case .publishProfile:
            return "paperplane"
        }
    }

    var placeholderDescription: String {
        switch self {
        case .profileInfo:
            return "Add your profile photo, banner, display name, username, bio, location, and social links."
        case .photos:
            return "Prepare profile, gallery, and verification photo upload slots."
        case .fanSubscriptions:
            return "Reserve setup space for tiers, pricing, benefits, and billing copy."
        case .aiPhotoEditor:
            return "Reserve entry point for AI-assisted creator photo tools."
        case .creatorDashboard:
            return "Preview the future dashboard shell for profile health and next actions."
        case .publishProfile:
            return "Review onboarding progress before making the creator profile public."
        }
    }
}
