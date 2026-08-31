import Foundation

// MARK: — Gender

/// Gender identity options.
///
/// The list is intentionally broad, but no fixed list can be complete — that is
/// why `.selfDescribe` exists and carries free text. Identity is stored
/// separately from `Pronouns`: knowing someone's gender does not tell you how to
/// refer to them, and it is the pronouns that prevent misgendering in chat and UI.
enum Gender: String, CaseIterable, Codable, Sendable, Identifiable {
    case woman
    case man
    case transWoman
    case transMan
    case transfeminine
    case transmasculine
    case nonBinary
    case genderfluid
    case genderqueer
    case agender
    case bigender
    case pangender
    case demigirl
    case demiboy
    case twoSpirit
    case intersex
    case questioning
    case selfDescribe
    case preferNotToSay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .woman:          return "Woman"
        case .man:            return "Man"
        case .transWoman:     return "Trans woman"
        case .transMan:       return "Trans man"
        case .transfeminine:  return "Transfeminine"
        case .transmasculine: return "Transmasculine"
        case .nonBinary:      return "Non-binary"
        case .genderfluid:    return "Genderfluid"
        case .genderqueer:    return "Genderqueer"
        case .agender:        return "Agender"
        case .bigender:       return "Bigender"
        case .pangender:      return "Pangender"
        case .demigirl:       return "Demigirl"
        case .demiboy:        return "Demiboy"
        case .twoSpirit:      return "Two-Spirit"
        case .intersex:       return "Intersex"
        case .questioning:    return "Questioning"
        case .selfDescribe:   return "Let me describe it"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    /// Whether choosing this option requires the free-text companion field.
    var requiresCustomText: Bool { self == .selfDescribe }
}

// MARK: — Pronouns

/// Pronoun sets. `.custom` carries free text so nobody is forced into a set that
/// does not fit. This is the field the rest of the app should read when it needs
/// to refer to a person.
enum Pronouns: String, CaseIterable, Codable, Sendable, Identifiable {
    case sheHer
    case heHim
    case theyThem
    case sheThey
    case heThey
    case xeXem
    case zeZir
    case eyEm
    case faeFaer
    case itIts
    case anyPronouns
    case askMe
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sheHer:       return "she/her"
        case .heHim:        return "he/him"
        case .theyThem:     return "they/them"
        case .sheThey:      return "she/they"
        case .heThey:       return "he/they"
        case .xeXem:        return "xe/xem"
        case .zeZir:        return "ze/zir"
        case .eyEm:         return "ey/em"
        case .faeFaer:      return "fae/faer"
        case .itIts:        return "it/its"
        case .anyPronouns:  return "any pronouns"
        case .askMe:        return "ask me"
        case .custom:       return "custom"
        }
    }

    var requiresCustomText: Bool { self == .custom }
}

// MARK: — Interest catalogs

/// Preset tags offered for the "turn ons" and "fetishes" pickers.
///
/// These are starting points only — both fields accept custom tags. Every entry
/// describes activity between consenting adults; the platform is 18+ and the
/// catalogs are curated to keep it that way.
enum InterestCatalog {

    static let turnOns: [String] = [
        "Flirting", "Teasing", "Dirty talk", "Sexting", "Roleplay",
        "Romance", "Girlfriend experience", "Boyfriend experience",
        "Dominance", "Submission", "Switch", "Praise", "Edging",
        "Striptease", "Lingerie", "Cosplay", "Uniforms", "Costumes",
        "Massage", "Sensory play", "Toys", "Voyeurism", "Exhibitionism",
        "Mutual masturbation", "JOI", "Body worship", "Muscles", "Curves",
        "Tattoos", "Piercings", "Glasses", "Accents", "Long hair",
        "Confidence", "Intelligence", "Humour", "Singing", "Dancing",
        "Gaming together", "Slow burn", "Age gap (18+)"
    ]

    static let fetishes: [String] = [
        "BDSM", "Bondage", "Rope / Shibari", "Impact play", "Spanking",
        "Flogging", "Wax play", "Ice play", "Temperature play",
        "Sensory deprivation", "Blindfolds", "Gags", "Collars", "Leashes",
        "Chastity", "Orgasm control", "Tease and denial", "Humiliation",
        "Degradation", "Financial domination", "Findom tributes",
        "Foot fetish", "Shoe and heel fetish", "Stockings", "Pantyhose",
        "Latex", "Leather", "PVC", "Corsets", "Cross-dressing",
        "Pet play", "Primal play", "Medical roleplay", "Teacher roleplay",
        "Boss roleplay", "Cuckolding", "Hotwife", "Voyeur scenes",
        "Exhibitionist scenes", "Tickling", "Hair pulling", "Smoking",
        "Food play", "Body writing", "Furry", "Anime and hentai", "ASMR"
    ]
}

/// How widely a sensitive profile field is shared.
enum FieldVisibility: String, CaseIterable, Codable, Sendable, Identifiable {
    case everyone
    case creatorsOnly
    case onlyMe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyone:     return "Everyone"
        case .creatorsOnly: return "Creators I watch"
        case .onlyMe:       return "Only me"
        }
    }

    var systemImage: String {
        switch self {
        case .everyone:     return "globe"
        case .creatorsOnly: return "person.2.fill"
        case .onlyMe:       return "lock.fill"
        }
    }
}

// MARK: — Viewer profile

/// A viewer's public-facing profile.
///
/// `birthdate` is the source of truth for age — an app storing a plain "age"
/// integer silently goes stale and cannot be used to prove an 18+ gate was
/// enforced. Age is always derived.
struct ViewerProfile: Codable, Sendable, Equatable {

    /// Minimum age for the platform. Enforced at entry, not just displayed.
    static let minimumAge = 18

    static let displayNameMaxLength = 30
    static let aboutMeMaxLength = 600
    static let maxTags = 20

    var displayName: String = ""
    var birthdate: Date?

    var gender: Gender?
    var genderSelfDescription: String = ""

    var pronouns: Pronouns?
    var pronounsCustom: String = ""

    var aboutMe: String = ""
    var turnOns: [String] = []
    var fetishes: [String] = []

    var turnOnsVisibility: FieldVisibility = .everyone
    var fetishesVisibility: FieldVisibility = .creatorsOnly

    var updatedAt: Date?

    // MARK: Derived

    /// Whole years since `birthdate`, or nil if no birthdate is set.
    var age: Int? {
        Self.age(from: birthdate)
    }

    /// Age in whole years on `referenceDate`. Static and injectable so tests do
    /// not depend on today's date.
    static func age(from birthdate: Date?, on referenceDate: Date = Date()) -> Int? {
        guard let birthdate, birthdate <= referenceDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: referenceDate).year
    }

    /// The latest birthdate that still satisfies the 18+ gate.
    static func latestAllowedBirthdate(on referenceDate: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .year, value: -minimumAge, to: referenceDate) ?? referenceDate
    }

    var isOfAge: Bool {
        guard let age else { return false }
        return age >= Self.minimumAge
    }

    /// Human-readable gender, resolving the self-described case.
    var genderLabel: String? {
        guard let gender else { return nil }
        if gender.requiresCustomText {
            let trimmed = genderSelfDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return gender.label
    }

    /// Human-readable pronouns, resolving the custom case.
    var pronounsLabel: String? {
        guard let pronouns else { return nil }
        if pronouns.requiresCustomText {
            let trimmed = pronounsCustom.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return pronouns.label
    }

    // MARK: Validation

    enum ValidationError: LocalizedError, Equatable {
        case displayNameEmpty
        case displayNameTooLong
        case birthdateMissing
        case underage
        case genderSelfDescriptionEmpty
        case pronounsCustomEmpty
        case aboutMeTooLong
        case tooManyTags

        var errorDescription: String? {
            switch self {
            case .displayNameEmpty:
                return "Pick a display name so creators know what to call you."
            case .displayNameTooLong:
                return "Display names are limited to \(ViewerProfile.displayNameMaxLength) characters."
            case .birthdateMissing:
                return "Enter your date of birth."
            case .underage:
                return "You must be at least \(ViewerProfile.minimumAge) to use AIxcam."
            case .genderSelfDescriptionEmpty:
                return "Add a word or two describing your gender, or pick another option."
            case .pronounsCustomEmpty:
                return "Type the pronouns you'd like people to use."
            case .aboutMeTooLong:
                return "About me is limited to \(ViewerProfile.aboutMeMaxLength) characters."
            case .tooManyTags:
                return "Pick up to \(ViewerProfile.maxTags) tags per list."
            }
        }
    }

    /// All validation problems with the profile, in display order. Empty means valid.
    func validationErrors(on referenceDate: Date = Date()) -> [ValidationError] {
        var errors: [ValidationError] = []

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            errors.append(.displayNameEmpty)
        } else if name.count > Self.displayNameMaxLength {
            errors.append(.displayNameTooLong)
        }

        if birthdate == nil {
            errors.append(.birthdateMissing)
        } else if (Self.age(from: birthdate, on: referenceDate) ?? 0) < Self.minimumAge {
            errors.append(.underage)
        }

        if gender?.requiresCustomText == true,
           genderSelfDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.genderSelfDescriptionEmpty)
        }

        if pronouns?.requiresCustomText == true,
           pronounsCustom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.pronounsCustomEmpty)
        }

        if aboutMe.count > Self.aboutMeMaxLength {
            errors.append(.aboutMeTooLong)
        }

        if turnOns.count > Self.maxTags || fetishes.count > Self.maxTags {
            errors.append(.tooManyTags)
        }

        return errors
    }

    var isValid: Bool { validationErrors().isEmpty }

    /// A profile is "complete" once the required identity fields are filled in.
    /// Optional expression fields (about me, tags) are deliberately excluded —
    /// the app must not hold a viewer hostage for declining to list a kink.
    var isComplete: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isOfAge
    }

    /// Trimmed, de-duplicated, length-capped copy suitable for persistence.
    func sanitized() -> ViewerProfile {
        var copy = self
        copy.displayName = String(
            displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.displayNameMaxLength)
        )
        copy.genderSelfDescription = genderSelfDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.pronounsCustom = pronounsCustom.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.aboutMe = String(
            aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.aboutMeMaxLength)
        )
        copy.turnOns = Self.normalizeTags(turnOns)
        copy.fetishes = Self.normalizeTags(fetishes)
        return copy
    }

    /// Trims, drops blanks, removes case-insensitive duplicates (keeping the first
    /// spelling the person typed), and caps the list length.
    static func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
            if result.count == maxTags { break }
        }
        return result
    }
}
