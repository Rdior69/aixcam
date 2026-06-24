import Combine
import Foundation

@MainActor
final class CreatorSettingsViewModel: ObservableObject {
    @Published var settings: CreatorSettings
    @Published private(set) var statusMessage: String?

    let profile: CreatorProfile

    init(profile: CreatorProfile, settings: CreatorSettings = CreatorSettings()) {
        self.profile = profile
        self.settings = settings
    }

    var profileStatusText: String {
        settings.isProfilePublic ? "Public profile" : "Draft profile"
    }

    var notificationSummary: String {
        let enabledCount = [
            settings.emailNotificationsEnabled,
            settings.pushNotificationsEnabled,
            settings.creatorTipsEnabled
        ].filter { $0 }.count

        return "\(enabledCount) notification options enabled"
    }

    func saveLocalSettings() {
        statusMessage = "Creator settings saved locally for this prototype."
    }
}
