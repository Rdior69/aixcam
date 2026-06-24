import Foundation

struct CreatorProfile: Codable, Equatable, Identifiable {
    let id: String
    let ownerMemberId: String
    var displayName: String
    var email: String
    var completedSteps: [CreatorSetupStep]
    var isPublished: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        ownerMemberId: String,
        displayName: String,
        email: String,
        completedSteps: [CreatorSetupStep] = [],
        isPublished: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerMemberId = ownerMemberId
        self.displayName = displayName
        self.email = email
        self.completedSteps = completedSteps
        self.isPublished = isPublished
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(member: Member) {
        self.init(
            id: member.id.uuidString,
            ownerMemberId: member.id.uuidString,
            displayName: member.name,
            email: member.email
        )
    }
}

extension CreatorProfile {
    var firebaseData: [String: Any] {
        [
            "id": id,
            "ownerMemberId": ownerMemberId,
            "displayName": displayName,
            "email": email,
            "completedSteps": completedSteps.map(\.rawValue),
            "isPublished": isPublished,
            "createdAt": Self.dateFormatter.string(from: createdAt),
            "updatedAt": Self.dateFormatter.string(from: updatedAt)
        ]
    }

    init?(firebaseData: [String: Any]) {
        guard
            let id = firebaseData["id"] as? String,
            let ownerMemberId = firebaseData["ownerMemberId"] as? String,
            let displayName = firebaseData["displayName"] as? String,
            let email = firebaseData["email"] as? String,
            let isPublished = firebaseData["isPublished"] as? Bool
        else {
            return nil
        }

        let completedStepValues = firebaseData["completedSteps"] as? [String] ?? []
        let completedSteps = completedStepValues.compactMap(CreatorSetupStep.init(rawValue:))
        let createdAt = Self.date(from: firebaseData["createdAt"]) ?? Date()
        let updatedAt = Self.date(from: firebaseData["updatedAt"]) ?? createdAt

        self.init(
            id: id,
            ownerMemberId: ownerMemberId,
            displayName: displayName,
            email: email,
            completedSteps: completedSteps,
            isPublished: isPublished,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static let dateFormatter = ISO8601DateFormatter()

    private static func date(from value: Any?) -> Date? {
        guard let string = value as? String else {
            return nil
        }

        return dateFormatter.date(from: string)
    }
}
