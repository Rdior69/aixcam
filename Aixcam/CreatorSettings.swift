import Foundation

struct CreatorSettings: Codable, Equatable {
    var isProfilePublic: Bool
    var allowFanMessages: Bool
    var emailNotificationsEnabled: Bool
    var pushNotificationsEnabled: Bool
    var creatorTipsEnabled: Bool

    init(
        isProfilePublic: Bool = false,
        allowFanMessages: Bool = true,
        emailNotificationsEnabled: Bool = true,
        pushNotificationsEnabled: Bool = false,
        creatorTipsEnabled: Bool = true
    ) {
        self.isProfilePublic = isProfilePublic
        self.allowFanMessages = allowFanMessages
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.creatorTipsEnabled = creatorTipsEnabled
    }
}
