import Foundation

struct CreatorProfile: Codable, Equatable, Identifiable {
    let id: String
    let ownerMemberId: String
    var displayName: String
    var email: String
    var username: String
    var aboutMe: String
    var location: String
    var websiteURL: String
    var instagramURL: String
    var tiktokURL: String
    var xTwitterURL: String
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
        email: String,
        username: String = "",
        aboutMe: String = "",
        location: String = "",
        websiteURL: String = "",
        instagramURL: String = "",
        tiktokURL: String = "",
        xTwitterURL: String = "",
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
        self.email = email
        self.username = username
        self.aboutMe = aboutMe
        self.location = location
        self.websiteURL = websiteURL
        self.instagramURL = instagramURL
        self.tiktokURL = tiktokURL
        self.xTwitterURL = xTwitterURL
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
        [
            "id": id,
            "ownerMemberId": ownerMemberId,
            "displayName": displayName,
            "email": email,
            "username": username,
            "aboutMe": aboutMe,
            "location": location,
            "websiteURL": websiteURL,
            "instagramURL": instagramURL,
            "tiktokURL": tiktokURL,
            "xTwitterURL": xTwitterURL,
            "profilePhotoURL": profilePhotoURL ?? "",
            "coverImageURL": coverImageURL ?? "",
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
        let username = firebaseData["username"] as? String ?? ""
        let aboutMe = firebaseData["aboutMe"] as? String ?? ""
        let location = firebaseData["location"] as? String ?? ""
        let websiteURL = firebaseData["websiteURL"] as? String ?? ""
        let instagramURL = firebaseData["instagramURL"] as? String ?? ""
        let tiktokURL = firebaseData["tiktokURL"] as? String ?? ""
        let xTwitterURL = firebaseData["xTwitterURL"] as? String ?? ""
        let profilePhotoURL = firebaseData["profilePhotoURL"] as? String
        let coverImageURL = firebaseData["coverImageURL"] as? String

        self.init(
            id: id,
            ownerMemberId: ownerMemberId,
            displayName: displayName,
            email: email,
            username: username,
            aboutMe: aboutMe,
            location: location,
            websiteURL: websiteURL,
            instagramURL: instagramURL,
            tiktokURL: tiktokURL,
            xTwitterURL: xTwitterURL,
            profilePhotoURL: profilePhotoURL,
            coverImageURL: coverImageURL,
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
