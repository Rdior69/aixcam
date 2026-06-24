import Combine
import Foundation
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum ProfileInformationField: String, CaseIterable, Identifiable {
    case displayName
    case username
    case profilePhoto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .displayName:
            return "Display name"
        case .username:
            return "Username"
        case .profilePhoto:
            return "Profile photo"
        }
    }
}

@MainActor
final class ProfileInformationViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var username = ""
    @Published var aboutMe = ""
    @Published var location = ""
    @Published var websiteLink = ""
    @Published var instagramLink = ""
    @Published var tiktokLink = ""
    @Published var twitterLink = ""
    @Published var profilePhotoItem: PhotosPickerItem?
    @Published var coverImageItem: PhotosPickerItem?
    @Published private(set) var profilePhotoPreview: Image?
    @Published private(set) var coverImagePreview: Image?
    @Published private(set) var validationErrors: [ProfileInformationField: String] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    private let profileID: String
    private var existingProfilePhotoURL: String?
    private var existingCoverImageURL: String?
    private var pendingProfilePhotoData: Data?
    private var pendingCoverImageData: Data?

    private let profileService: CreatorProfileServicing
    private let mediaService: CreatorMediaUploadServicing

    init(
        profile: CreatorProfile,
        profileService: CreatorProfileServicing,
        mediaService: CreatorMediaUploadServicing
    ) {
        profileID = profile.id
        self.profileService = profileService
        self.mediaService = mediaService
        apply(profile: profile)
    }

    func apply(profile: CreatorProfile) {
        displayName = profile.displayName
        username = profile.username
        aboutMe = profile.aboutMe
        location = profile.location
        websiteLink = profile.websiteLink
        instagramLink = profile.instagramLink
        tiktokLink = profile.tiktokLink
        twitterLink = profile.twitterLink
        existingProfilePhotoURL = profile.profilePhotoURL
        existingCoverImageURL = profile.coverImageURL
    }

    func handleProfilePhotoSelection() async {
        await loadImage(from: profilePhotoItem, assignPreview: { self.profilePhotoPreview = $0 }, assignData: { self.pendingProfilePhotoData = $0 })
    }

    func handleCoverImageSelection() async {
        await loadImage(from: coverImageItem, assignPreview: { self.coverImagePreview = $0 }, assignData: { self.pendingCoverImageData = $0 })
    }

    func saveAndContinue(baseProfile: CreatorProfile) async -> CreatorProfile? {
        validationErrors = [:]
        errorMessage = nil

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = normalizeUsername(username)

        if trimmedDisplayName.isEmpty {
            validationErrors[.displayName] = "Enter the name fans will see on your profile."
        }

        if trimmedUsername.isEmpty {
            validationErrors[.username] = "Choose a public username."
        } else if isValidUsername(trimmedUsername) == false {
            validationErrors[.username] = "Use 3–30 letters, numbers, or underscores."
        }

        let hasProfilePhoto = pendingProfilePhotoData != nil || existingProfilePhotoURL?.isEmpty == false
        if hasProfilePhoto == false {
            validationErrors[.profilePhoto] = "Add a profile photo to continue."
        }

        if let websiteError = validateOptionalURL(websiteLink, fieldName: "Website") {
            errorMessage = websiteError
        } else if let instagramError = validateOptionalURL(instagramLink, fieldName: "Instagram") {
            errorMessage = instagramError
        } else if let tiktokError = validateOptionalURL(tiktokLink, fieldName: "TikTok") {
            errorMessage = tiktokError
        } else if let twitterError = validateOptionalURL(twitterLink, fieldName: "X/Twitter") {
            errorMessage = twitterError
        }

        guard validationErrors.isEmpty, errorMessage == nil else {
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var updatedProfile = baseProfile
            updatedProfile.displayName = trimmedDisplayName
            updatedProfile.username = trimmedUsername
            updatedProfile.aboutMe = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedProfile.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedProfile.websiteLink = normalizeURL(websiteLink)
            updatedProfile.instagramLink = normalizeURL(instagramLink)
            updatedProfile.tiktokLink = normalizeURL(tiktokLink)
            updatedProfile.twitterLink = normalizeURL(twitterLink)

            if let pendingProfilePhotoData {
                let url = try await mediaService.uploadProfilePhoto(data: pendingProfilePhotoData, profileID: profileID)
                updatedProfile.profilePhotoURL = url.absoluteString
                existingProfilePhotoURL = url.absoluteString
            }

            if let pendingCoverImageData {
                let url = try await mediaService.uploadCoverImage(data: pendingCoverImageData, profileID: profileID)
                updatedProfile.coverImageURL = url.absoluteString
                existingCoverImageURL = url.absoluteString
            }

            if updatedProfile.completedSteps.contains(.profileInfo) == false {
                updatedProfile.completedSteps.append(.profileInfo)
            }

            updatedProfile.updatedAt = Date()
            try await profileService.saveProfile(updatedProfile)
            return updatedProfile
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func loadImage(
        from item: PhotosPickerItem?,
        assignPreview: (Image?) -> Void,
        assignData: (Data?) -> Void
    ) async {
        guard let item else {
            assignPreview(nil)
            assignData(nil)
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), data.isEmpty == false else {
                assignPreview(nil)
                assignData(nil)
                return
            }

#if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                assignPreview(Image(uiImage: uiImage))
                assignData(compressedJPEGData(from: uiImage))
                return
            }
#endif

            assignPreview(Image(systemName: "photo"))
            assignData(data)
        } catch {
            errorMessage = "We could not load the selected image."
            assignPreview(nil)
            assignData(nil)
        }
    }

#if canImport(UIKit)
    private func compressedJPEGData(from image: UIImage, maxBytes: Int = 1_500_000) -> Data? {
        var compression: CGFloat = 0.9
        var data = image.jpegData(compressionQuality: compression)

        while let currentData = data, currentData.count > maxBytes, compression > 0.2 {
            compression -= 0.1
            data = image.jpegData(compressionQuality: compression)
        }

        return data
    }
#endif

    private func normalizeUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidUsername(_ value: String) -> Bool {
        let pattern = "^[a-z0-9_]{3,30}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func normalizeURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateOptionalURL(_ value: String, fieldName: String) -> String? {
        let trimmed = normalizeURL(value)
        guard trimmed.isEmpty == false else {
            return nil
        }

        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            return "\(fieldName) link must start with http:// or https://."
        }

        return nil
    }
}
