//
//  AIxcamTests.swift
//  AIxcamTests
//

import Testing
@testable import AIxcam
import Foundation

// MARK: - StreamRecord

@Suite("StreamRecord")
struct StreamRecordTests {

    private func record(startedAt: Date, endedAt: Date? = nil, peakViewers: Int = 0) -> StreamRecord {
        StreamRecord(id: UUID().uuidString, startedAt: startedAt, endedAt: endedAt, peakViewers: peakViewers)
    }

    @Test func durationSeconds_nilWhenNoEndDate() {
        #expect(record(startedAt: Date()).durationSeconds == nil)
    }

    @Test func durationSeconds_computesCorrectly() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 125)
        #expect(record(startedAt: start, endedAt: end).durationSeconds == 125)
    }

    @Test func durationSeconds_clampsToZeroWhenEndBeforeStart() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let end   = Date(timeIntervalSinceReferenceDate: 50)
        #expect(record(startedAt: start, endedAt: end).durationSeconds == 0)
    }

    @Test func formattedDuration_ongoingWhenNoEnd() {
        #expect(record(startedAt: Date()).formattedDuration == "Ongoing")
    }

    @Test func formattedDuration_secondsOnly() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 45)
        #expect(record(startedAt: start, endedAt: end).formattedDuration == "45s")
    }

    @Test func formattedDuration_minutesAndSeconds() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 125) // 2m 5s
        #expect(record(startedAt: start, endedAt: end).formattedDuration == "2m 5s")
    }

    @Test func formattedDate_nonEmpty() {
        #expect(!record(startedAt: Date()).formattedDate.isEmpty)
    }
}

// MARK: - StreamingSecurityPolicy

@Suite("StreamingSecurityPolicy")
struct StreamingSecurityPolicyTests {

    private func policy(url: String, hosts: Set<String> = ["stream.example.com"]) -> StreamingSecurityPolicy {
        StreamingSecurityPolicy(ingestURL: URL(string: url)!, allowedHosts: hosts)
    }

    @Test func validate_httpsURL_succeeds() throws {
        try policy(url: "https://stream.example.com/ingest").validate()
    }

    @Test func validate_wssURL_succeeds() throws {
        try policy(url: "wss://stream.example.com/live").validate()
    }

    @Test func validate_rtmpsURL_succeeds() throws {
        try policy(url: "rtmps://stream.example.com/live").validate()
    }

    @Test func validate_httpURL_throwsInsecure() {
        #expect(throws: StreamingError.insecureIngestURL) {
            try policy(url: "http://stream.example.com/ingest").validate()
        }
    }

    @Test func validate_ipv4Host_throwsIPAddressBlocked() {
        let p = StreamingSecurityPolicy(
            ingestURL: URL(string: "https://192.168.1.1/ingest")!,
            allowedHosts: ["192.168.1.1"]
        )
        #expect(throws: StreamingError.ipAddressHostBlocked) {
            try p.validate()
        }
    }

    @Test func validate_disallowedHost_throwsDisallowedHost() {
        #expect(throws: StreamingError.disallowedHost) {
            try policy(url: "https://evil.example.com/ingest").validate()
        }
    }

    @Test func defaultPolicy_hasSecureScheme() {
        let scheme = StreamingSecurityPolicy.default.ingestURL.scheme?.lowercased() ?? ""
        #expect(["https", "wss", "rtmps"].contains(scheme))
    }
}

// MARK: - MockStreamingService

@Suite("MockStreamingService")
struct MockStreamingServiceTests {

    @Test func prepareInfrastructure_returnsReadyStatus() async throws {
        let svc = MockStreamingService()
        let status = try await svc.prepareInfrastructure()
        #expect(status.isReady)
        #expect(status.securityLevel == .secure)
    }

    @Test func startBroadcast_withoutPrepare_throwsNotPrepared() async {
        let svc = MockStreamingService()
        await #expect(throws: StreamingError.infrastructureNotPrepared) {
            try await svc.startBroadcast(creatorID: "user1")
        }
    }

    @Test func startBroadcast_afterPrepare_returnsValidSession() async throws {
        let svc = MockStreamingService()
        _ = try await svc.prepareInfrastructure()
        let session = try await svc.startBroadcast(creatorID: "user1")
        #expect(!session.streamID.isEmpty)
        #expect(session.startedAt <= Date())
    }

    @Test func startBroadcast_twiceWithoutEnd_throwsAlreadyActive() async throws {
        let svc = MockStreamingService()
        _ = try await svc.prepareInfrastructure()
        let session = try await svc.startBroadcast(creatorID: "user1")
        await #expect(throws: StreamingError.broadcastAlreadyActive) {
            try await svc.startBroadcast(creatorID: "user1")
        }
        try await svc.endBroadcast(streamID: session.streamID)
    }

    @Test func endBroadcast_withoutActive_throwsNoActiveBroadcast() async throws {
        let svc = MockStreamingService()
        _ = try await svc.prepareInfrastructure()
        await #expect(throws: StreamingError.noActiveBroadcast) {
            try await svc.endBroadcast(streamID: "nonexistent")
        }
    }

    @Test func fullLifecycle_prepareStartEndRepeat() async throws {
        let svc = MockStreamingService()
        _ = try await svc.prepareInfrastructure()
        let s1 = try await svc.startBroadcast(creatorID: "user1")
        try await svc.endBroadcast(streamID: s1.streamID)
        // After ending, a second broadcast should succeed.
        let s2 = try await svc.startBroadcast(creatorID: "user1")
        #expect(s2.streamID != s1.streamID)
        try await svc.endBroadcast(streamID: s2.streamID)
    }

    @Test func prepareInfrastructure_withInsecurePolicy_throwsInsecureURL() async {
        let bad = StreamingSecurityPolicy(
            ingestURL: URL(string: "http://stream.example.com/ingest")!,
            allowedHosts: ["stream.example.com"]
        )
        let svc = MockStreamingService(policy: bad)
        await #expect(throws: StreamingError.insecureIngestURL) {
            try await svc.prepareInfrastructure()
        }
    }

    @Test func chatRoomARN_isNonEmpty() {
        #expect(!MockStreamingService().chatRoomARN.isEmpty)
    }
}

// MARK: - Error Descriptions

@Suite("Error Descriptions")
struct ErrorDescriptionTests {

    @Test func streamingError_allCasesHaveDescriptions() {
        let cases: [StreamingError] = [
            .infrastructureNotPrepared, .insecureIngestURL, .disallowedHost,
            .ipAddressHostBlocked, .broadcastAlreadyActive, .noActiveBroadcast
        ]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func chatError_allCasesHaveDescriptions() {
        let cases: [ChatError] = [.notAuthenticated, .tokenFetchFailed]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

// MARK: - TransportSecurityLevel

@Suite("TransportSecurityLevel")
struct TransportSecurityLevelTests {

    @Test func rawValues_areCorrect() {
        #expect(TransportSecurityLevel.initializing.rawValue == "INIT")
        #expect(TransportSecurityLevel.secure.rawValue == "SECURE")
        #expect(TransportSecurityLevel.degraded.rawValue == "DEGRADED")
    }
}

// MARK: - ChatService parsing

@Suite("ChatService")
@MainActor
struct ChatServiceTests {

    @Test func region_extractedFromARN() {
        #expect(ChatService.region(from: "arn:aws:ivschat:us-east-1:123456789012:room/abc") == "us-east-1")
        #expect(ChatService.region(from: "arn:aws:ivschat:eu-west-2:1:room/x") == "eu-west-2")
    }

    @Test func region_malformedARN_fallsBackToUSEast1() {
        #expect(ChatService.region(from: "not-an-arn") == "us-east-1")
    }

    @Test func parseMessage_validMessage_usesDisplayName() {
        let json = """
        {"Type":"MESSAGE","Id":"m1","Content":"hello","SendTime":"2026-01-01T00:00:00Z",\
        "Sender":{"UserId":"u1","Attributes":{"displayName":"Alice"}}}
        """
        let msg = ChatService.parseMessage(json)
        #expect(msg?.id == "m1")
        #expect(msg?.sender == "Alice")
        #expect(msg?.text == "hello")
    }

    @Test func parseMessage_noDisplayName_fallsBackToUserId() {
        let json = """
        {"Type":"MESSAGE","Id":"m2","Content":"hi","Sender":{"UserId":"u2"}}
        """
        #expect(ChatService.parseMessage(json)?.sender == "u2")
    }

    @Test func parseMessage_nonMessageEvent_returnsNil() {
        let json = #"{"Type":"CONNECT","Id":"c1"}"#
        #expect(ChatService.parseMessage(json) == nil)
    }
}

// MARK: - StreamHistoryService parsing

@Suite("StreamHistoryService")
@MainActor
struct StreamHistoryServiceTests {

    private func result(endedAt: String? = "2026-01-01T00:05:00Z", peak: String = "42") -> [String: Any] {
        var fields: [String: Any] = [
            "startedAt": ["timestampValue": "2026-01-01T00:00:00Z"],
            "peakViewers": ["integerValue": peak]
        ]
        if let endedAt { fields["endedAt"] = ["timestampValue": endedAt] }
        return ["document": [
            "name": "projects/p/databases/(default)/documents/streams/DOC1",
            "fields": fields
        ]]
    }

    @Test func parseRecord_fullDocument_mapsAllFields() {
        let record = StreamHistoryService.parseRecord(result())
        #expect(record?.id == "DOC1")
        #expect(record?.peakViewers == 42)
        #expect(record?.durationSeconds == 300)
    }

    @Test func parseRecord_ongoing_hasNilDuration() {
        let record = StreamHistoryService.parseRecord(result(endedAt: nil))
        #expect(record?.endedAt == nil)
        #expect(record?.durationSeconds == nil)
    }

    @Test func parseRecord_missingDocument_returnsNil() {
        #expect(StreamHistoryService.parseRecord(["readTime": "2026-01-01T00:00:00Z"]) == nil)
    }
}

// MARK: - ViewerProfile age & 18+ gate

@Suite("ViewerProfile age")
struct ViewerProfileAgeTests {

    /// Fixed reference date so these never break on a future run.
    private let today = Date(timeIntervalSinceReferenceDate: 800_000_000) // 2026-05-08

    private func birthday(yearsAgo: Int, daysOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .year, value: -yearsAgo, to: today)!
        return calendar.date(byAdding: .day, value: daysOffset, to: base)!
    }

    @Test func age_nilWhenNoBirthdate() {
        #expect(ViewerProfile.age(from: nil, on: today) == nil)
    }

    @Test func age_nilForFutureBirthdate() {
        #expect(ViewerProfile.age(from: birthday(yearsAgo: -5), on: today) == nil)
    }

    @Test func age_computesWholeYears() {
        #expect(ViewerProfile.age(from: birthday(yearsAgo: 25), on: today) == 25)
    }

    @Test func age_dayBeforeBirthdayIsStillPreviousYear() {
        // One day short of turning 18 must read as 17, not 18.
        #expect(ViewerProfile.age(from: birthday(yearsAgo: 18, daysOffset: 1), on: today) == 17)
    }

    @Test func isOfAge_falseWithoutBirthdate() {
        #expect(ViewerProfile().isOfAge == false)
    }

    @Test func validation_underageIsRejected() {
        var profile = ViewerProfile()
        profile.displayName = "Sam"
        profile.birthdate = birthday(yearsAgo: 17)
        #expect(profile.validationErrors(on: today).contains(.underage))
    }

    @Test func validation_exactlyEighteenIsAccepted() {
        var profile = ViewerProfile()
        profile.displayName = "Sam"
        profile.birthdate = birthday(yearsAgo: 18)
        #expect(!profile.validationErrors(on: today).contains(.underage))
    }

    @Test func latestAllowedBirthdate_isExactlyEighteenYearsBack() {
        #expect(ViewerProfile.age(from: ViewerProfile.latestAllowedBirthdate(on: today), on: today) == 18)
    }
}

// MARK: - ViewerProfile validation & completeness

@Suite("ViewerProfile validation")
struct ViewerProfileValidationTests {

    private let today = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func adult(name: String = "Sam") -> ViewerProfile {
        var profile = ViewerProfile()
        profile.displayName = name
        profile.birthdate = Calendar.current.date(byAdding: .year, value: -30, to: today)
        return profile
    }

    @Test func emptyProfile_reportsNameAndBirthdate() {
        let errors = ViewerProfile().validationErrors(on: today)
        #expect(errors.contains(.displayNameEmpty))
        #expect(errors.contains(.birthdateMissing))
    }

    @Test func whitespaceOnlyName_countsAsEmpty() {
        var profile = adult(name: "   ")
        profile.displayName = "   "
        #expect(profile.validationErrors(on: today).contains(.displayNameEmpty))
    }

    @Test func overlongName_isRejected() {
        let profile = adult(name: String(repeating: "a", count: ViewerProfile.displayNameMaxLength + 1))
        #expect(profile.validationErrors(on: today).contains(.displayNameTooLong))
    }

    @Test func selfDescribedGender_requiresText() {
        var profile = adult()
        profile.gender = .selfDescribe
        #expect(profile.validationErrors(on: today).contains(.genderSelfDescriptionEmpty))

        profile.genderSelfDescription = "Genderflux"
        #expect(!profile.validationErrors(on: today).contains(.genderSelfDescriptionEmpty))
    }

    @Test func presetGender_doesNotRequireText() {
        var profile = adult()
        profile.gender = .nonBinary
        #expect(profile.validationErrors(on: today).isEmpty)
    }

    @Test func customPronouns_requireText() {
        var profile = adult()
        profile.pronouns = .custom
        #expect(profile.validationErrors(on: today).contains(.pronounsCustomEmpty))

        profile.pronounsCustom = "ve/ver"
        #expect(!profile.validationErrors(on: today).contains(.pronounsCustomEmpty))
    }

    @Test func overlongAboutMe_isRejected() {
        var profile = adult()
        profile.aboutMe = String(repeating: "x", count: ViewerProfile.aboutMeMaxLength + 1)
        #expect(profile.validationErrors(on: today).contains(.aboutMeTooLong))
    }

    @Test func tooManyTags_isRejected() {
        var profile = adult()
        profile.fetishes = (0...ViewerProfile.maxTags).map { "tag\($0)" }
        #expect(profile.validationErrors(on: today).contains(.tooManyTags))
    }

    /// Interests are optional on purpose — nobody is blocked from using the app
    /// for declining to list a kink.
    @Test func isComplete_doesNotRequireInterestsOrAboutMe() {
        var profile = ViewerProfile()
        profile.displayName = "Sam"
        profile.birthdate = Calendar.current.date(byAdding: .year, value: -22, to: Date())
        #expect(profile.isComplete)
        #expect(profile.turnOns.isEmpty)
        #expect(profile.aboutMe.isEmpty)
    }

    @Test func isComplete_falseWhenUnderage() {
        var profile = ViewerProfile()
        profile.displayName = "Sam"
        profile.birthdate = Calendar.current.date(byAdding: .year, value: -12, to: Date())
        #expect(!profile.isComplete)
    }
}

// MARK: - ViewerProfile labels & sanitisation

@Suite("ViewerProfile labels")
struct ViewerProfileLabelTests {

    @Test func genderLabel_usesSelfDescriptionWhenSelfDescribing() {
        var profile = ViewerProfile()
        profile.gender = .selfDescribe
        profile.genderSelfDescription = "  Genderflux  "
        #expect(profile.genderLabel == "Genderflux")
    }

    @Test func genderLabel_nilWhenSelfDescribingWithBlankText() {
        var profile = ViewerProfile()
        profile.gender = .selfDescribe
        profile.genderSelfDescription = "   "
        #expect(profile.genderLabel == nil)
    }

    @Test func pronounsLabel_usesCustomTextWhenCustom() {
        var profile = ViewerProfile()
        profile.pronouns = .custom
        profile.pronounsCustom = "ve/ver"
        #expect(profile.pronounsLabel == "ve/ver")
    }

    @Test func pronounsLabel_usesPresetLabelOtherwise() {
        var profile = ViewerProfile()
        profile.pronouns = .theyThem
        #expect(profile.pronounsLabel == "they/them")
    }

    @Test func everyGenderHasANonEmptyLabel() {
        for gender in Gender.allCases {
            #expect(!gender.label.isEmpty)
        }
    }

    @Test func everyPronounSetHasANonEmptyLabel() {
        for pronouns in Pronouns.allCases {
            #expect(!pronouns.label.isEmpty)
        }
    }

    @Test func onlySelfDescribeAndCustomRequireFreeText() {
        #expect(Gender.allCases.filter(\.requiresCustomText) == [.selfDescribe])
        #expect(Pronouns.allCases.filter(\.requiresCustomText) == [.custom])
    }
}

@Suite("ViewerProfile tag normalisation")
struct ViewerProfileTagTests {

    @Test func normalizeTags_trimsAndDropsBlanks() {
        #expect(ViewerProfile.normalizeTags(["  Latex ", "", "   "]) == ["Latex"])
    }

    @Test func normalizeTags_removesCaseInsensitiveDuplicatesKeepingFirst() {
        #expect(ViewerProfile.normalizeTags(["Latex", "latex", "LATEX"]) == ["Latex"])
    }

    @Test func normalizeTags_capsAtMaxTags() {
        let many = (0..<(ViewerProfile.maxTags + 10)).map { "tag\($0)" }
        #expect(ViewerProfile.normalizeTags(many).count == ViewerProfile.maxTags)
    }

    @Test func sanitized_truncatesOverlongFields() {
        var profile = ViewerProfile()
        profile.displayName = String(repeating: "a", count: 100)
        profile.aboutMe = String(repeating: "b", count: 1000)
        let clean = profile.sanitized()
        #expect(clean.displayName.count == ViewerProfile.displayNameMaxLength)
        #expect(clean.aboutMe.count == ViewerProfile.aboutMeMaxLength)
    }

    @Test func sanitized_isIdempotent() {
        var profile = ViewerProfile()
        profile.displayName = "  Sam  "
        profile.turnOns = ["Flirting", "flirting", " Roleplay "]
        let once = profile.sanitized()
        #expect(once.sanitized() == once)
    }
}

// MARK: - ViewerProfileService Firestore mapping

@Suite("ViewerProfileService")
@MainActor
struct ViewerProfileServiceTests {

    private func fullProfile() -> ViewerProfile {
        var profile = ViewerProfile()
        profile.displayName = "Sam"
        profile.birthdate = Date(timeIntervalSinceReferenceDate: 0)
        profile.gender = .nonBinary
        profile.pronouns = .theyThem
        profile.aboutMe = "Here to watch."
        profile.turnOns = ["Flirting", "Roleplay"]
        profile.fetishes = ["Latex"]
        profile.turnOnsVisibility = .everyone
        profile.fetishesVisibility = .onlyMe
        return profile
    }

    @Test func encodeDecode_roundTripsAllFields() throws {
        let original = fullProfile()
        let encoded = ViewerProfileService.encode(original, uid: "user-1")
        let decoded = try #require(ViewerProfileService.decode(document: encoded))

        #expect(decoded.displayName == original.displayName)
        #expect(decoded.gender == .nonBinary)
        #expect(decoded.pronouns == .theyThem)
        #expect(decoded.aboutMe == original.aboutMe)
        #expect(decoded.turnOns == original.turnOns)
        #expect(decoded.fetishes == original.fetishes)
        #expect(decoded.turnOnsVisibility == .everyone)
        #expect(decoded.fetishesVisibility == .onlyMe)
        #expect(decoded.birthdate == original.birthdate)
    }

    /// The rules pin ownership on this field, so it must always be written.
    @Test func encode_stampsOwnerUID() {
        let fields = ViewerProfileService.encode(fullProfile(), uid: "user-1")["fields"] as? [String: Any]
        let uid = (fields?["uid"] as? [String: Any])?["stringValue"] as? String
        #expect(uid == "user-1")
    }

    @Test func encode_omitsUnsetOptionalFields() {
        let fields = ViewerProfileService.encode(ViewerProfile(), uid: "user-1")["fields"] as? [String: Any]
        #expect(fields?["birthdate"] == nil)
        #expect(fields?["gender"] == nil)
        #expect(fields?["pronouns"] == nil)
    }

    @Test func decode_missingFieldsReturnsNil() {
        #expect(ViewerProfileService.decode(document: ["name": "docs/user-1"]) == nil)
    }

    @Test func decode_emptyDocumentYieldsEmptyProfile() throws {
        let decoded = try #require(ViewerProfileService.decode(document: ["fields": [:]]))
        #expect(decoded.displayName.isEmpty)
        #expect(decoded.gender == nil)
        #expect(!decoded.isComplete)
    }

    /// An enum case removed or renamed server-side must not crash the decode.
    @Test func decode_unknownEnumRawValuesAreIgnored() throws {
        let document: [String: Any] = ["fields": [
            "displayName": ["stringValue": "Sam"],
            "gender": ["stringValue": "not-a-real-gender"],
            "pronouns": ["stringValue": "zzz"],
            "turnOnsVisibility": ["stringValue": "nope"]
        ]]
        let decoded = try #require(ViewerProfileService.decode(document: document))
        #expect(decoded.gender == nil)
        #expect(decoded.pronouns == nil)
        #expect(decoded.turnOnsVisibility == .everyone) // falls back to the default
    }
}

// MARK: - AuthValidation

@Suite("AuthValidation")
struct AuthValidationTests {

    @Test(arguments: [
        "viewer@example.com",
        "first.last+tag@sub.example.co.uk",
        "  spaced@example.com  "
    ])
    func validEmails(_ email: String) {
        #expect(AuthValidation.isValidEmail(email))
    }

    @Test(arguments: [
        "", "no-at-sign", "@example.com", "user@", "user@example",
        "user@.com", "two @example.com"
    ])
    func invalidEmails(_ email: String) {
        #expect(!AuthValidation.isValidEmail(email))
    }

    @Test func strength_shortPasswordIsTooShort() {
        #expect(AuthValidation.strength(of: "Ab1!") == .tooShort)
        #expect(!AuthValidation.isAcceptablePassword("Ab1!"))
    }

    @Test func strength_singleCharacterClassIsWeak() {
        #expect(AuthValidation.strength(of: "aaaaaaaaa") == .weak)
    }

    @Test func strength_twoClassesIsFair() {
        #expect(AuthValidation.strength(of: "abcdefg1") == .fair)
    }

    @Test func strength_longMultiClassIsStrong() {
        #expect(AuthValidation.strength(of: "Correct1Horse!") == .strong)
    }

    @Test func strength_longButOnlyTwoClassesIsNotStrong() {
        #expect(AuthValidation.strength(of: "abcdefghijkl1") == .fair)
    }

    @Test func acceptable_onceLengthFloorIsCleared() {
        #expect(AuthValidation.isAcceptablePassword("aaaaaaaa"))
    }

    @Test func strengthOrdering_isMonotonic() {
        #expect(AuthValidation.PasswordStrength.tooShort < .weak)
        #expect(AuthValidation.PasswordStrength.weak < .fair)
        #expect(AuthValidation.PasswordStrength.fair < .strong)
    }
}
