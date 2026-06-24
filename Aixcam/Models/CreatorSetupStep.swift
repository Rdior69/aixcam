import Foundation

enum CreatorSetupStep: Int, CaseIterable, Identifiable, Sendable {
    case profileInformation = 0
    case creatorBranding = 1
    case contentCreation = 2
    case fanSubscriptions = 3
    case aiStudio = 4
    case creatorDashboard = 5
    case publish = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .profileInformation: "Profile"
        case .creatorBranding: "Branding"
        case .contentCreation: "Content"
        case .fanSubscriptions: "Subscriptions"
        case .aiStudio: "AI Studio"
        case .creatorDashboard: "Dashboard"
        case .publish: "Publish"
        }
    }

    var subtitle: String {
        switch self {
        case .profileInformation: "Tell fans who you are"
        case .creatorBranding: "Define your visual identity"
        case .contentCreation: "Upload and organize media"
        case .fanSubscriptions: "Set up membership tiers"
        case .aiStudio: "Enhance content with AI"
        case .creatorDashboard: "Preview your analytics"
        case .publish: "Review and go live"
        }
    }

    var icon: String {
        switch self {
        case .profileInformation: "person.crop.circle"
        case .creatorBranding: "paintpalette"
        case .contentCreation: "photo.on.rectangle.angled"
        case .fanSubscriptions: "crown"
        case .aiStudio: "wand.and.stars"
        case .creatorDashboard: "chart.bar.xaxis"
        case .publish: "globe"
        }
    }

    var stepNumber: Int { rawValue + 1 }
    static var totalSteps: Int { allCases.count }

    var next: CreatorSetupStep? {
        CreatorSetupStep(rawValue: rawValue + 1)
    }

    var previous: CreatorSetupStep? {
        CreatorSetupStep(rawValue: rawValue - 1)
    }
}
