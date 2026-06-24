import Foundation

struct CreatorProfile: Codable, Equatable, Identifiable {
    let id: String
    let ownerMemberId: String
    var displayName: String
    var username: String
    var email: String
    var aboutMe: String
    var location: String
    var websiteLink: String
    var instagramLink: String
    var tiktokLink: String
    var twitterLink: String
    var profilePhotoURL: String?
    var coverImageURL: String?
    var completedSteps: [CreatorSetupStep]
    var isPublished: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        ownerMemberId: String,
        displayName: String,
        username: String = "",
        email: String,
        aboutMe: String = "",
        location: String = "",
        websiteLink: String = "",
        instagramLink: String = "",
        tiktokLink: String = "",
        twitterLink: String = "",
        profilePhotoURL: String? = nil,
        coverImageURL: String? = nil,
        completedSteps: [CreatorSetupStep] = [],
        isPublished: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerMemberId = ownerMemberId
        self.displayName = displayName
        self.username = username
        self.email = email
        self.aboutMe = aboutMe
        self.location = location
        self.websiteLink = websiteLink
        self.instagramLink = instagramLink
        self.tiktokLink = tiktokLink
        self.twitterLink = twitterLink
        self.profilePhotoURL = profilePhotoURL
        self.coverImageURL = coverImageURL
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
        var data: [String: Any] = [
            "id": id,
            "ownerMemberId": ownerMemberId,
            "displayName": displayName,
            "username": username,
            "email": email,
            "aboutMe": aboutMe,
            "location": location,
            "websiteLink": websiteLink,
            "instagramLink": instagramLink,
            "tiktokLink": tiktokLink,
            "twitterLink": twitterLink,
            "completedSteps": completedSteps.map(\.rawValue),
            "isPublished": isPublished,
            "createdAt": Self.dateFormatter.string(from: createdAt),
            "updatedAt": Self.dateFormatter.string(from: updatedAt)
        ]

        if let profilePhotoURL {
            data["profilePhotoURL"] = profilePhotoURL
        }

        if let coverImageURL {
            data["coverImageURL"] = coverImageURL
        }

        return data
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
            username: firebaseData["username"] as? String ?? "",
            email: email,
            aboutMe: firebaseData["aboutMe"] as? String ?? "",
            location: firebaseData["location"] as? String ?? "",
            websiteLink: firebaseData["websiteLink"] as? String ?? "",
            instagramLink: firebaseData["instagramLink"] as? String ?? "",
            tiktokLink: firebaseData["tiktokLink"] as? String ?? "",
            twitterLink: firebaseData["twitterLink"] as? String ?? "",
            profilePhotoURL: firebaseData["profilePhotoURL"] as? String,
            coverImageURL: firebaseData["coverImageURL"] as? String,
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
