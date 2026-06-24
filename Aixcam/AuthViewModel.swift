import Combine
import Foundation

struct Member: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String
    let accountType: AccountType
    let createdAt: Date
    let passwordHash: String?

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        accountType: AccountType,
        createdAt: Date = Date(),
        passwordHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accountType = accountType
        self.createdAt = createdAt
        self.passwordHash = passwordHash
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }
}

enum AuthStatus: Equatable {
    case idle
    case success(String)
    case error(String)
}

enum CreatorSetupStep: String, CaseIterable, Codable, Identifiable {
    case profile
    case branding
    case content
    case subscriptions
    case aiStudio
    case dashboard
    case publish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile Information"
        case .branding: return "Creator Branding"
        case .content: return "Content Creation"
        case .subscriptions: return "Fan Subscriptions"
        case .aiStudio: return "AI Studio"
        case .dashboard: return "Creator Dashboard"
        case .publish: return "Publish"
        }
    }

    var eyebrow: String {
        "Step \(index + 1) of \(Self.allCases.count)"
    }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle.badge.plus"
        case .branding: return "paintpalette.fill"
        case .content: return "photo.on.rectangle.angled"
        case .subscriptions: return "crown.fill"
        case .aiStudio: return "sparkles"
        case .dashboard: return "chart.xyaxis.line"
        case .publish: return "paperplane.fill"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var progress: Double {
        Double(index + 1) / Double(Self.allCases.count)
    }

    var nextTitle: String {
        self == .publish ? "Publish creator profile" : "Continue"
    }
}

enum CreatorTheme: String, CaseIterable, Codable, Identifiable {
    case aurora = "Aurora Teal"
    case neon = "Neon Violet"
    case sunset = "Sunset Coral"
    case luxe = "Luxe Gold"

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .aurora: return "#2DD4BF"
        case .neon: return "#A855F7"
        case .sunset: return "#FB7185"
        case .luxe: return "#FBBF24"
        }
    }
}

enum MediaKind: String, CaseIterable, Codable, Identifiable {
    case photo = "Photo"
    case video = "Video"
    case album = "Album"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .photo: return "photo.fill"
        case .video: return "play.rectangle.fill"
        case .album: return "rectangle.stack.fill"
        }
    }
}

struct CreatorMediaItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var kind: MediaKind
    var category: String
    var storagePath: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        kind: MediaKind,
        category: String,
        storagePath: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.category = category
        self.storagePath = storagePath
        self.sortOrder = sortOrder
    }
}

struct SubscriptionTier: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var monthlyPrice: Double
    var benefits: [String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        monthlyPrice: Double,
        benefits: [String],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.monthlyPrice = monthlyPrice
        self.benefits = benefits
        self.isEnabled = isEnabled
    }
}

struct CreatorAnalytics: Codable, Equatable {
    var monthlyRevenue: Double
    var subscribers: Int
    var profileViews: Int
    var engagementRate: Double
    var topContent: String

    static let preview = CreatorAnalytics(
        monthlyRevenue: 6840,
        subscribers: 1240,
        profileViews: 38200,
        engagementRate: 12.8,
        topContent: "VIP behind-the-scenes album"
    )
}

struct CreatorProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerId: UUID
    var profilePhotoPath: String
    var coverImagePath: String
    var displayName: String
    var username: String
    var biography: String
    var location: String
    var websiteLinks: [String]
    var socialLinks: [String]
    var theme: CreatorTheme
    var customProfileURL: String
    var appearanceNotes: String
    var mediaItems: [CreatorMediaItem]
    var categories: [String]
    var subscriptionTiers: [SubscriptionTier]
    var aiTools: [String]
    var analytics: CreatorAnalytics
    var completedSteps: Set<CreatorSetupStep>
    var isPublished: Bool
    var updatedAt: Date

    init(member: Member) {
        let username = member.name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "")

        id = UUID()
        ownerId = member.id
        profilePhotoPath = "creators/\(member.id.uuidString)/profile/avatar.jpg"
        coverImagePath = "creators/\(member.id.uuidString)/profile/banner.jpg"
        displayName = member.name
        self.username = username.isEmpty ? "creator\(member.id.uuidString.prefix(6).lowercased())" : username
        biography = "Building premium fan experiences on Aixcam."
        location = ""
        websiteLinks = ["https://aixcam.app"]
        socialLinks = ["@aixcamcreator"]
        theme = .aurora
        customProfileURL = "aixcam.app/\(self.username)"
        appearanceNotes = "Glass cards, bold creator banner, mobile-first fan conversion layout."
        mediaItems = [
            CreatorMediaItem(title: "Launch teaser", kind: .video, category: "Featured", storagePath: "creators/\(member.id.uuidString)/media/launch-teaser.mov", sortOrder: 0),
            CreatorMediaItem(title: "Behind the scenes", kind: .album, category: "VIP", storagePath: "creators/\(member.id.uuidString)/albums/behind-the-scenes", sortOrder: 1)
        ]
        categories = ["Featured", "VIP", "Lifestyle"]
        subscriptionTiers = [
            SubscriptionTier(name: "Free", monthlyPrice: 0, benefits: ["Public posts", "Live previews", "Community updates"]),
            SubscriptionTier(name: "Premium", monthlyPrice: 9.99, benefits: ["Premium posts", "Subscriber-only livestreams", "Monthly content drops"]),
            SubscriptionTier(name: "VIP", monthlyPrice: 29.99, benefits: ["1:1 fan moments", "VIP albums", "Priority replies", "Early access"])
        ]
        aiTools = AIStudioTool.defaultTools.map(\.title)
        analytics = .preview
        completedSteps = []
        isPublished = false
        updatedAt = Date()
    }
}

struct AIStudioTool: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String

    static let defaultTools = [
        AIStudioTool(title: "AI photo editor", icon: "wand.and.stars", description: "Retouch and restyle photos before publishing."),
        AIStudioTool(title: "Background removal", icon: "person.crop.square", description: "Cut clean creator product and portrait assets."),
        AIStudioTool(title: "Image enhancement", icon: "camera.filters", description: "Improve contrast, detail, and lighting."),
        AIStudioTool(title: "AI filters", icon: "circle.hexagongrid.fill", description: "Apply branded fan page looks in batches."),
        AIStudioTool(title: "Caption generator", icon: "text.bubble.fill", description: "Generate high-converting post copy."),
        AIStudioTool(title: "Thumbnail creator", icon: "rectangle.badge.plus", description: "Create scroll-stopping video thumbnails."),
        AIStudioTool(title: "Image upscaling", icon: "arrow.up.left.and.arrow.down.right", description: "Prepare images for premium downloads."),
        AIStudioTool(title: "Batch editing", icon: "square.stack.3d.up.fill", description: "Apply edits to full albums at once.")
    ]
}

struct FirebaseCreatorBlueprint {
    static let firestoreCollections = [
        "users/{uid}",
        "creatorProfiles/{uid}",
        "creatorProfiles/{uid}/media/{mediaId}",
        "creatorProfiles/{uid}/subscriptionTiers/{tierId}",
        "creatorProfiles/{uid}/analytics/daily",
        "creatorProfiles/{uid}/aiJobs/{jobId}"
    ]

    static func storageRoots(for userId: UUID) -> [String] {
        [
            "creators/\(userId.uuidString)/profile/",
            "creators/\(userId.uuidString)/covers/",
            "creators/\(userId.uuidString)/media/photos/",
            "creators/\(userId.uuidString)/media/videos/",
            "creators/\(userId.uuidString)/ai-output/"
        ]
    }
}

protocol CreatorBackendServicing {
    func profile(for member: Member) -> CreatorProfile
    func save(profile: CreatorProfile) throws
    func publish(profile: CreatorProfile) throws -> CreatorProfile
}

final class LocalCreatorBackendService: CreatorBackendServicing {
    private let storageKey = "aixcam.creatorProfiles"

    func profile(for member: Member) -> CreatorProfile {
        var profiles = loadProfiles()

        if let existing = profiles[member.id.uuidString] {
            return existing
        }

        let profile = CreatorProfile(member: member)
        profiles[member.id.uuidString] = profile
        saveProfiles(profiles)
        return profile
    }

    func save(profile: CreatorProfile) throws {
        var updated = profile
        updated.updatedAt = Date()
        var profiles = loadProfiles()
        profiles[profile.ownerId.uuidString] = updated
        saveProfiles(profiles)
    }

    func publish(profile: CreatorProfile) throws -> CreatorProfile {
        var published = profile
        published.isPublished = true
        published.completedSteps = Set(CreatorSetupStep.allCases)
        published.updatedAt = Date()
        try save(profile: published)
        return published
    }

    private func loadProfiles() -> [String: CreatorProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: CreatorProfile].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveProfiles(_ profiles: [String: CreatorProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

final class AuthViewModel: ObservableObject {
    @Published private(set) var members: [Member] = []
    @Published private(set) var currentMember: Member?
    @Published var status: AuthStatus = .idle

    var isAuthenticated: Bool {
        currentMember != nil
    }

    private let storageKey = "aixcam.members"
    private let sessionKey = "aixcam.currentMemberId"

    init() {
        loadMembers()
        restoreSession()
    }

    func signUp(name: String, email: String, accountType: AccountType, password: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = normalize(email)

        guard validate(name: cleanedName, email: cleanedEmail, password: password) else {
            return
        }

        guard members.contains(where: { $0.email == cleanedEmail }) == false else {
            status = .error("That email is already signed up. Please log in instead.")
            return
        }

        let member = Member(
            name: cleanedName,
            email: cleanedEmail,
            accountType: accountType,
            passwordHash: hash(password)
        )
        members.append(member)
        saveMembers()
        startSession(for: member)
        status = .success("Account created. Creator setup is ready.")
    }

    func login(email: String, password: String) {
        let cleanedEmail = normalize(email)

        guard validate(email: cleanedEmail, password: password) else {
            return
        }

        guard let member = members.first(where: { $0.email == cleanedEmail }) else {
            status = .error("We could not find that member email. Create a new account to join Aixcam.")
            return
        }

        guard member.passwordHash == nil || member.passwordHash == hash(password) else {
            status = .error("That password does not match this account.")
            return
        }

        startSession(for: member)
        status = .success("Welcome back, \(member.name).")
    }

    func logout() {
        currentMember = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        status = .idle
    }

    func resetStatus() {
        status = .idle
    }

    private func startSession(for member: Member) {
        currentMember = member
        UserDefaults.standard.set(member.id.uuidString, forKey: sessionKey)
    }

    private func restoreSession() {
        guard
            let sessionId = UserDefaults.standard.string(forKey: sessionKey),
            let uuid = UUID(uuidString: sessionId),
            let member = members.first(where: { $0.id == uuid })
        else {
            return
        }

        currentMember = member
    }

    private func validate(name: String, email: String, password: String) -> Bool {
        guard name.isEmpty == false else {
            status = .error("Enter your full name to create an account.")
            return false
        }

        return validate(email: email, password: password)
    }

    private func validate(email: String, password: String) -> Bool {
        guard email.contains("@"), email.contains(".") else {
            status = .error("Enter a valid email address.")
            return false
        }

        guard password.count >= 8 else {
            status = .error("Use a password with at least 8 characters.")
            return false
        }

        return true
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hash(_ password: String) -> String {
        String(password.reversed()) + ".aixcam"
    }

    private func loadMembers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            members = try JSONDecoder().decode([Member].self, from: data)
        } catch {
            members = []
        }
    }

    private func saveMembers() {
        do {
            let data = try JSONEncoder().encode(members)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            status = .error("We could not save the new member account. Please try again.")
        }
    }
}

final class CreatorSetupViewModel: ObservableObject {
    @Published var profile: CreatorProfile
    @Published var currentStep: CreatorSetupStep = .profile
    @Published var status: AuthStatus = .idle
    @Published var isSaving = false

    let member: Member
    private let backend: CreatorBackendServicing

    var isPublished: Bool {
        profile.isPublished
    }

    var currentStepIndex: Int {
        currentStep.index
    }

    init(member: Member, backend: CreatorBackendServicing = LocalCreatorBackendService()) {
        self.member = member
        self.backend = backend
        profile = backend.profile(for: member)
        currentStep = nextIncompleteStep(in: profile)
    }

    func goBack() {
        guard currentStepIndex > 0 else {
            return
        }

        currentStep = CreatorSetupStep.allCases[currentStepIndex - 1]
        status = .idle
    }

    func continueFromCurrentStep() {
        guard validateCurrentStep() else {
            return
        }

        profile.completedSteps.insert(currentStep)
        saveDraft(message: "\(currentStep.title) saved.")

        if currentStep == .publish {
            publish()
        } else {
            currentStep = CreatorSetupStep.allCases[currentStepIndex + 1]
        }
    }

    func saveDraft(message: String = "Draft saved.") {
        isSaving = true
        do {
            try backend.save(profile: profile)
            status = .success(message)
        } catch {
            status = .error("We could not save this creator profile. Please try again.")
        }
        isSaving = false
    }

    func publish() {
        guard validatePublish() else {
            return
        }

        isSaving = true
        do {
            profile = try backend.publish(profile: profile)
            status = .success("Your creator profile is published and live for fans.")
        } catch {
            status = .error("Publishing failed. Please review your setup and try again.")
        }
        isSaving = false
    }

    func addWebsiteLink() {
        profile.websiteLinks.append("https://")
    }

    func addSocialLink() {
        profile.socialLinks.append("@")
    }

    func addMediaItem(kind: MediaKind) {
        let item = CreatorMediaItem(
            title: "\(kind.rawValue) drop \(profile.mediaItems.count + 1)",
            kind: kind,
            category: profile.categories.first ?? "Featured",
            storagePath: "creators/\(member.id.uuidString)/media/\(UUID().uuidString)",
            sortOrder: profile.mediaItems.count
        )
        profile.mediaItems.append(item)
    }

    func moveMedia(from source: IndexSet, to destination: Int) {
        let movingItems = source.map { profile.mediaItems[$0] }

        for index in source.sorted(by: >) {
            profile.mediaItems.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, profile.mediaItems.count))
        profile.mediaItems.insert(contentsOf: movingItems, at: insertionIndex)

        for index in profile.mediaItems.indices {
            profile.mediaItems[index].sortOrder = index
        }
    }

    func addCategory() {
        profile.categories.append("New category")
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .profile:
            guard profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                status = .error("Add a display name.")
                return false
            }
            guard profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                status = .error("Choose a username.")
                return false
            }
        case .branding:
            guard profile.customProfileURL.contains("/") else {
                status = .error("Add a custom profile URL.")
                return false
            }
        case .content:
            guard profile.mediaItems.isEmpty == false else {
                status = .error("Add at least one photo, video, or album.")
                return false
            }
        case .subscriptions:
            guard profile.subscriptionTiers.contains(where: { $0.isEnabled }) else {
                status = .error("Enable at least one subscription tier.")
                return false
            }
        case .aiStudio, .dashboard, .publish:
            break
        }

        return true
    }

    private func validatePublish() -> Bool {
        let missing = CreatorSetupStep.allCases.filter { step in
            step != .publish && profile.completedSteps.contains(step) == false
        }

        if missing.isEmpty == false {
            status = .error("Finish \(missing.first?.title ?? "all steps") before publishing.")
            currentStep = missing.first ?? .profile
            return false
        }

        return true
    }

    private func nextIncompleteStep(in profile: CreatorProfile) -> CreatorSetupStep {
        guard profile.isPublished == false else {
            return .dashboard
        }

        return CreatorSetupStep.allCases.first { profile.completedSteps.contains($0) == false } ?? .publish
    }
}
