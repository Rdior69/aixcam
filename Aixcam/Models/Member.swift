import Foundation

struct Member: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let email: String
    let accountType: AccountType
    let createdAt: Date
    var onboardingComplete: Bool
    var currentSetupStep: Int

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        accountType: AccountType,
        createdAt: Date = Date(),
        onboardingComplete: Bool = false,
        currentSetupStep: Int = 0
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accountType = accountType
        self.createdAt = createdAt
        self.onboardingComplete = onboardingComplete
        self.currentSetupStep = currentSetupStep
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable, Sendable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }
}

enum AuthStatus: Equatable {
    case idle
    case loading
    case success(String)
    case error(String)
}
