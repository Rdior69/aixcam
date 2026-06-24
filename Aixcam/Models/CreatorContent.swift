import Foundation

struct CreatorMediaItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var mediaType: MediaType
    var localPath: String?
    var remoteURL: String?
    var thumbnailPath: String?
    var category: ContentCategory
    var albumId: UUID?
    var sortOrder: Int
    var createdAt: Date
    var aiEnhancements: [AIEnhancement]

    init(
        id: UUID = UUID(),
        title: String = "",
        mediaType: MediaType = .photo,
        localPath: String? = nil,
        remoteURL: String? = nil,
        thumbnailPath: String? = nil,
        category: ContentCategory = .general,
        albumId: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        aiEnhancements: [AIEnhancement] = []
    ) {
        self.id = id
        self.title = title
        self.mediaType = mediaType
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.thumbnailPath = thumbnailPath
        self.category = category
        self.albumId = albumId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.aiEnhancements = aiEnhancements
    }
}

enum MediaType: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo = "Photo"
    case video = "Video"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        }
    }
}

enum ContentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case behindTheScenes = "Behind the Scenes"
    case exclusive = "Exclusive"
    case livestream = "Livestream"
    case tutorials = "Tutorials"
    case lifestyle = "Lifestyle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "square.grid.2x2"
        case .behindTheScenes: "film"
        case .exclusive: "lock.fill"
        case .livestream: "dot.radiowaves.left.and.right"
        case .tutorials: "book"
        case .lifestyle: "sparkles"
        }
    }
}

struct ContentAlbum: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var coverMediaId: UUID?
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        coverMediaId: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverMediaId = coverMediaId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

struct AIEnhancement: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var type: AIEnhancementType
    var appliedAt: Date
    var isProcessing: Bool

    init(id: UUID = UUID(), type: AIEnhancementType, appliedAt: Date = Date(), isProcessing: Bool = false) {
        self.id = id
        self.type = type
        self.appliedAt = appliedAt
        self.isProcessing = isProcessing
    }
}

enum AIEnhancementType: String, CaseIterable, Codable, Identifiable, Sendable {
    case backgroundRemoval = "Background Removal"
    case imageEnhancement = "Image Enhancement"
    case aiFilter = "AI Filter"
    case captionGeneration = "Caption Generator"
    case thumbnailCreation = "Thumbnail Creator"
    case imageUpscaling = "Image Upscaling"
    case batchEditing = "Batch Editing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .backgroundRemoval: "person.and.background.dotted"
        case .imageEnhancement: "wand.and.rays"
        case .aiFilter: "camera.filters"
        case .captionGeneration: "text.bubble"
        case .thumbnailCreation: "rectangle.on.rectangle"
        case .imageUpscaling: "arrow.up.left.and.arrow.down.right"
        case .batchEditing: "square.stack.3d.up"
        }
    }

    var description: String {
        switch self {
        case .backgroundRemoval: "Remove backgrounds instantly with AI precision"
        case .imageEnhancement: "Auto-adjust lighting, contrast, and clarity"
        case .aiFilter: "Apply trending creative filters"
        case .captionGeneration: "Generate engaging captions for posts"
        case .thumbnailCreation: "Create click-worthy thumbnails"
        case .imageUpscaling: "Upscale images up to 4x resolution"
        case .batchEditing: "Apply edits across multiple images"
        }
    }
}
