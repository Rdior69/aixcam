//
//  NetworkedServiceTests.swift
//  AIxcamTests
//
//  Covers the request/response paths that used to be unreachable. Every one of
//  these services reached for `Auth.auth().currentUser` and `URLSession.shared`
//  inline, so a test could only ever exercise the pure helpers beside them —
//  which is all the older suites do. With `AuthTokenProviding` and an injected
//  session, the actual behaviour (status handling, error mapping, request
//  shape) now runs under test.
//

import Testing
@testable import AIxcam
import Foundation

// MARK: - Live channel discovery

@Suite("FirebaseLiveChannelProvider")
struct LiveChannelProviderTests {

    private func provider(
        _ stub: StubHTTP,
        auth: StaticAuthTokenProvider = StaticAuthTokenProvider()
    ) -> FirebaseLiveChannelProvider {
        FirebaseLiveChannelProvider(
            endpoint: stub.endpoint,
            session: stub.session,
            authTokenProvider: auth
        )
    }

    @Test func decodesTheLiveFeed() async throws {
        let stub = StubHTTP()
        stub.enqueue(.ok(json: """
        {"result":{"channels":[
          {"streamId":"s1","creatorId":"c1","displayName":"Ada",
           "startedAt":"2026-08-30T12:00:00.000Z",
           "playbackURL":"https://live.example.com/s1.m3u8"}
        ]}}
        """))

        let channels = try await provider(stub).fetchLiveChannels()

        #expect(channels.count == 1)
        #expect(channels.first?.streamID == "s1")
        #expect(channels.first?.title == "Ada")
        #expect(channels.first?.startedAt != nil)
    }

    @Test func signedOutThrowsWithoutSendingARequest() async {
        let stub = StubHTTP()

        await #expect(throws: LiveChannelError.self) {
            try await provider(stub, auth: .signedOut).fetchLiveChannels()
        }
        #expect(stub.requestCount == 0)
    }

    @Test(arguments: [401, 403, 500])
    func aNonSuccessStatusThrows(_ code: Int) async {
        let stub = StubHTTP()
        stub.enqueue(.status(code))

        await #expect(throws: LiveChannelError.self) {
            try await provider(stub).fetchLiveChannels()
        }
    }

    @Test func aTransportFailureThrows() async {
        let stub = StubHTTP()
        stub.enqueue(.transportFailure())

        await #expect(throws: LiveChannelError.self) {
            try await provider(stub).fetchLiveChannels()
        }
    }

    @Test func theRequestCarriesTheBearerToken() async throws {
        let stub = StubHTTP()
        stub.enqueue(.ok(json: #"{"result":{"channels":[]}}"#))

        _ = try await provider(stub, auth: StaticAuthTokenProvider(idToken: "tok-abc"))
            .fetchLiveChannels()

        #expect(stub.lastRequest?.authorizationHeader == "Bearer tok-abc")
    }
}

// MARK: - Payment attribution (money-critical)

/// True for `PaymentError.attributionFailed`. Needed because `PaymentError`
/// carries an `Error` payload and so cannot be `Equatable`, which rules out the
/// value form of `#expect(throws:)`.
private func isAttributionFailed(_ error: any Error) -> Bool {
    if case .attributionFailed? = error as? PaymentError { return true }
    return false
}

@Suite("FirebasePaymentBackend")
struct PaymentBackendTests {

    private func backend(
        _ stub: StubHTTP,
        auth: StaticAuthTokenProvider = StaticAuthTokenProvider()
    ) -> FirebasePaymentBackend {
        FirebasePaymentBackend(
            firestoreDocumentsURL: stub.baseURL,
            recordTransactionURL: stub.endpoint,
            session: stub.session,
            authTokenProvider: auth
        )
    }

    /// Apple lowercases `appAccountToken` in the signed payload and the backend
    /// looks the mapping up by that value, so an uppercase document id would
    /// leave the payment unattributable.
    @Test func attributionDocumentIDIsTheLowercasedToken() async throws {
        let stub = StubHTTP()
        let token = UUID()

        try await backend(stub).registerAttribution(token: token, creatorID: "creator-1")

        let url = try #require(stub.lastRequest?.url.absoluteString)
        #expect(url.contains("documentId=\(token.uuidString.lowercased())"))
        #expect(!url.contains(token.uuidString.uppercased()))
    }

    @Test func attributionRecordsBothCreatorAndBuyer() async throws {
        let stub = StubHTTP()

        try await backend(stub, auth: StaticAuthTokenProvider(userID: "buyer-9"))
            .registerAttribution(token: UUID(), creatorID: "creator-1")

        #expect(stub.lastRequest?.method == "POST")
        #expect(stub.lastRequest?.firestoreString("creatorId") == "creator-1")
        #expect(stub.lastRequest?.firestoreString("buyerUid") == "buyer-9")
    }

    /// Regression: URLSession does not throw on 4xx, so a rules rejection read
    /// as success — the buyer was charged with no mapping recorded and the
    /// creator could never be credited.
    @Test(arguments: [400, 401, 403, 409, 500])
    func aNonSuccessStatusThrowsAttributionFailed(_ code: Int) async {
        let stub = StubHTTP()
        stub.enqueue(.status(code))

        await #expect {
            try await backend(stub).registerAttribution(token: UUID(), creatorID: "c1")
        } throws: { isAttributionFailed($0) }
    }

    @Test func aTransportFailureThrowsAttributionFailed() async {
        let stub = StubHTTP()
        stub.enqueue(.transportFailure())

        await #expect {
            try await backend(stub).registerAttribution(token: UUID(), creatorID: "c1")
        } throws: { isAttributionFailed($0) }
    }

    @Test func signedOutThrowsAttributionFailedWithoutSendingARequest() async {
        let stub = StubHTTP()

        await #expect {
            try await backend(stub, auth: .signedOut)
                .registerAttribution(token: UUID(), creatorID: "c1")
        } throws: { isAttributionFailed($0) }

        #expect(stub.requestCount == 0)
    }

    @Test func forwardingSendsTheSignedTransaction() async {
        let stub = StubHTTP()

        await backend(stub).forwardTransaction(jws: "signed.jws.payload")

        let data = stub.lastRequest?.bodyObject?["data"] as? [String: Any]
        #expect(data?["signedTransaction"] as? String == "signed.jws.payload")
    }

    /// Forwarding must never throw: the buyer has already paid, and the backend
    /// reconciles via App Store Server Notifications.
    @Test func forwardingSwallowsFailures() async {
        let stub = StubHTTP()
        stub.enqueue(.transportFailure())

        await backend(stub).forwardTransaction(jws: "signed.jws.payload")

        #expect(stub.requestCount == 1)
    }

    @Test func forwardingIsSkippedWhenSignedOut() async {
        let stub = StubHTTP()

        await backend(stub, auth: .signedOut).forwardTransaction(jws: "x")

        #expect(stub.requestCount == 0)
    }
}

// MARK: - Stream history writes

@Suite("StreamHistoryService network")
@MainActor
struct StreamHistoryNetworkTests {

    private func service(
        _ stub: StubHTTP,
        auth: StaticAuthTokenProvider = StaticAuthTokenProvider()
    ) -> StreamHistoryService {
        StreamHistoryService(
            baseURL: stub.baseURL,
            session: stub.session,
            authTokenProvider: auth
        )
    }

    @Test func startSessionReturnsTheNewDocumentID() async throws {
        let stub = StubHTTP()

        let documentID = await service(stub).startSession(creatorID: "creator-1")

        let id = try #require(documentID)
        #expect(UUID(uuidString: id) != nil)
        #expect(stub.lastRequest?.url.absoluteString.contains("documentId=\(id)") == true)
        #expect(stub.lastRequest?.method == "POST")
    }

    /// Regression: `endedAt` must be written as an explicit null. Firestore's
    /// `== null` matches only documents where the field exists, so omitting it
    /// makes the stream invisible to the "currently live" query.
    @Test func startSessionWritesAnExplicitNullEndedAt() async {
        let stub = StubHTTP()

        _ = await service(stub).startSession(creatorID: "creator-1")

        let endedAt = stub.lastRequest?.firestoreFields?["endedAt"] as? [String: Any]
        #expect(endedAt?.keys.contains("nullValue") == true)
        #expect(stub.lastRequest?.firestoreString("creatorID") == "creator-1")
    }

    /// URLSession does not throw on 4xx/5xx, so a permission-denied write would
    /// otherwise report a live stream that was never recorded.
    @Test(arguments: [403, 404, 500])
    func startSessionReturnsNilOnANonSuccessStatus(_ code: Int) async {
        let stub = StubHTTP()
        stub.enqueue(.status(code))

        #expect(await service(stub).startSession(creatorID: "creator-1") == nil)
    }

    @Test func startSessionReturnsNilOnATransportFailure() async {
        let stub = StubHTTP()
        stub.enqueue(.transportFailure())

        #expect(await service(stub).startSession(creatorID: "c1") == nil)
    }

    @Test func startSessionSkipsTheRequestWhenSignedOut() async {
        let stub = StubHTTP()

        let documentID = await service(stub, auth: .signedOut).startSession(creatorID: "c1")

        #expect(documentID == nil)
        #expect(stub.requestCount == 0)
    }

    /// The update mask is what stops the PATCH from wiping creatorID/startedAt.
    @Test func endSessionPatchesOnlyEndedAtAndPeakViewers() async {
        let stub = StubHTTP()

        await service(stub).endSession(documentID: "doc-1", peakViewers: 42)

        let request = stub.lastRequest
        #expect(request?.method == "PATCH")

        let url = request?.url.absoluteString ?? ""
        #expect(url.contains("/streams/doc-1"))
        #expect(url.contains("updateMask.fieldPaths=endedAt"))
        #expect(url.contains("updateMask.fieldPaths=peakViewers"))

        let fields = request?.firestoreFields
        #expect(fields?.count == 2)
        #expect((fields?["peakViewers"] as? [String: Any])?["integerValue"] as? String == "42")
    }

    @Test func endSessionSkipsTheRequestWhenSignedOut() async {
        let stub = StubHTTP()

        await service(stub, auth: .signedOut).endSession(documentID: "doc-1", peakViewers: 1)

        #expect(stub.requestCount == 0)
    }

    @Test func fetchHistoryParsesTheQueryResults() async {
        let stub = StubHTTP()
        stub.enqueue(.ok(json: """
        [{"document":{
            "name":"projects/p/databases/(default)/documents/streams/doc-1",
            "fields":{
              "startedAt":{"timestampValue":"2026-08-30T12:00:00Z"},
              "endedAt":{"timestampValue":"2026-08-30T12:05:30Z"},
              "peakViewers":{"integerValue":"7"}
            }}}]
        """))
        let service = service(stub)

        await service.fetchHistory(creatorID: "creator-1")

        #expect(service.recentStreams.count == 1)
        #expect(service.recentStreams.first?.id == "doc-1")
        #expect(service.recentStreams.first?.peakViewers == 7)
        #expect(service.recentStreams.first?.durationSeconds == 330)
        #expect(!service.isLoading)
    }

    @Test func fetchHistoryQueriesOnlyTheGivenCreator() async {
        let stub = StubHTTP()
        stub.enqueue(.ok(json: "[]"))

        await service(stub).fetchHistory(creatorID: "creator-7")

        let query = stub.lastRequest?.bodyObject?["structuredQuery"] as? [String: Any]
        let filter = (query?["where"] as? [String: Any])?["fieldFilter"] as? [String: Any]
        #expect((filter?["value"] as? [String: Any])?["stringValue"] as? String == "creator-7")
        #expect(stub.lastRequest?.url.absoluteString.hasSuffix(":runQuery") == true)
    }

    @Test func fetchHistorySkipsTheRequestWhenSignedOut() async {
        let stub = StubHTTP()

        await service(stub, auth: .signedOut).fetchHistory(creatorID: "c1")

        #expect(stub.requestCount == 0)
    }
}

// MARK: - Broadcast lifecycle recording

/// Reachable now that `LiveBroadcastViewModel` takes its history service: these
/// paths previously wrote to the live Firestore REST API from any test that
/// called `goLive()`.
@Suite("LiveBroadcastViewModel history recording")
@MainActor
struct LiveBroadcastHistoryTests {

    // Held for the lifetime of the test: the stub deregisters its channel when
    // it deallocates.
    private let stub = StubHTTP()

    private func viewModel() -> LiveBroadcastViewModel {
        LiveBroadcastViewModel(
            creatorID: "creator-1",
            streamingService: MockStreamingService(),
            historyService: StreamHistoryService(
                baseURL: stub.baseURL,
                session: stub.session,
                authTokenProvider: StaticAuthTokenProvider()
            )
        )
    }

    /// Brings the view model to the state `goLive()` requires without touching
    /// the camera or the real permission prompt.
    private func readyToGoLive() async -> LiveBroadcastViewModel {
        let vm = viewModel()
        vm.hasPermission = true
        await vm.retryInfrastructure()
        return vm
    }

    @Test func goLiveRecordsAStreamSession() async {
        let vm = await readyToGoLive()

        await vm.goLive()

        #expect(vm.isLive)
        let write = stub.capturedRequests.first { $0.method == "POST" }
        #expect(write?.firestoreString("creatorID") == "creator-1")
    }

    /// The viewer count is unknown until provider polling is wired up. It used to be
    /// seeded by a random walk whose peaks were written to history as real.
    @Test func goLiveLeavesTheViewerCountUnknown() async {
        let vm = await readyToGoLive()

        await vm.goLive()

        #expect(vm.viewerCount == nil)
    }

    @Test func endLiveStampsTheSameDocument() async {
        let vm = await readyToGoLive()
        await vm.goLive()

        await vm.endLive()

        #expect(!vm.isLive)
        let patch = stub.capturedRequests.last { $0.method == "PATCH" }
        #expect(patch != nil, "Ending a stream must close out its history record")
        #expect((patch?.firestoreFields?["endedAt"] as? [String: Any])?
            .keys.contains("timestampValue") == true)
    }

    /// A failed history write must not stop the creator going live — the
    /// broadcast is the product, the record is bookkeeping.
    @Test func aFailedHistoryWriteStillGoesLive() async {
        stub.setFallback(.status(403))
        let vm = await readyToGoLive()

        await vm.goLive()

        #expect(vm.isLive)
        #expect(vm.error == nil)
    }

    @Test func endLiveWithoutGoingLiveWritesNothing() async {
        let vm = viewModel()

        await vm.endLive()

        #expect(stub.requestCount == 0)
    }
}

// MARK: - Viewer profile loading (the screen every sign-in passes through)

/// `ContentView` gates the whole app on this load, so every branch of it is
/// user-visible: one wrong classification and a signed-in creator is stuck on a
/// full-screen error telling them to check a connection that was never down.
@Suite("ViewerProfileService loading")
@MainActor
struct ViewerProfileServiceLoadingTests {

    private let stub = StubHTTP()

    private func service(
        auth: StaticAuthTokenProvider = StaticAuthTokenProvider()
    ) -> ViewerProfileService {
        ViewerProfileService(baseURL: stub.baseURL, session: stub.session, authTokenProvider: auth)
    }

    @Test func loadRequestsTheCallersOwnDocumentWithABearerToken() async {
        let service = self.service(auth: StaticAuthTokenProvider(userID: "creator-9", idToken: "tok"))
        stub.enqueue(.ok(json: #"{"fields":{"displayName":{"stringValue":"Ada"}}}"#))

        await service.load()

        #expect(stub.lastRequest?.url.path.hasSuffix("/viewerProfiles/creator-9") == true)
        #expect(stub.lastRequest?.authorizationHeader == "Bearer tok")
        #expect(service.profile?.displayName == "Ada")
        #expect(service.loadFailure == nil)
    }

    /// First run: no document yet. That is not an error — it is what sends a new
    /// account into the setup form.
    @Test func aMissingDocumentYieldsAnEmptyProfileNotAFailure() async {
        let service = self.service()
        stub.enqueue(.status(404, json: #"{"error":{"status":"NOT_FOUND"}}"#))

        await service.load()

        #expect(service.profile == ViewerProfile())
        #expect(service.loadFailure == nil)
    }

    /// The bug this suite was written for: a rules rejection was reported as
    /// "Couldn't load your profile / Check your connection", which is both wrong
    /// and unactionable. 403 has to be its own case.
    @Test func aRulesRejectionIsReportedAsPermissionDeniedAndIsNotRetryable() async {
        let service = self.service()
        stub.enqueue(.status(403, json: #"{"error":{"status":"PERMISSION_DENIED"}}"#))

        await service.load()

        #expect(service.loadFailure == .permissionDenied)
        #expect(service.loadFailure?.isRetryable == false)
        #expect(!(service.loadFailure?.guidance.contains("connection") ?? true))
    }

    @Test(arguments: [401, 429, 500, 503])
    func otherNonSuccessStatusesCarryTheirCode(_ code: Int) async {
        let service = self.service()
        stub.enqueue(.status(code))

        await service.load()

        #expect(service.loadFailure == .server(status: code))
    }

    @Test func aTransportFailureIsReportedAsSuch() async {
        let service = self.service()
        stub.enqueue(.transportFailure())

        await service.load()

        #expect(service.loadFailure == .transport)
        #expect(service.loadFailure?.guidance.contains("connection") == true)
    }

    @Test func signedOutSkipsTheRequestEntirely() async {
        let service = self.service(auth: .signedOut)

        await service.load()

        #expect(service.loadFailure == .notSignedIn)
        #expect(stub.requestCount == 0)
    }

    /// A failed reload used to blank `profile` before it even had a token, so a
    /// blip replaced a working session with the error screen. The last good
    /// profile has to survive.
    @Test func aFailedReloadKeepsTheProfileAlreadyOnScreen() async {
        let service = self.service()
        stub.enqueue(.ok(json: #"{"fields":{"displayName":{"stringValue":"Ada"}}}"#))
        await service.load()

        stub.enqueue(.transportFailure())
        await service.load()

        #expect(service.profile?.displayName == "Ada")
        #expect(service.loadFailure == .transport)
    }

    /// …but a *different* person's profile must never linger.
    @Test func loadingAsSomeoneElseDropsThePreviousProfile() async {
        let first = service(auth: StaticAuthTokenProvider(userID: "creator-1"))
        stub.enqueue(.ok(json: #"{"fields":{"displayName":{"stringValue":"Ada"}}}"#))
        await first.load()

        stub.enqueue(.status(403))
        await first.load()

        // Same service, same person, so the held profile is still theirs.
        #expect(first.profile?.displayName == "Ada")

        let second = service(auth: StaticAuthTokenProvider(userID: "creator-2"))
        stub.enqueue(.status(403))
        await second.load()

        #expect(second.profile == nil)
    }

    @Test func resetClearsEverythingForTheNextAccount() async {
        let service = self.service()
        stub.enqueue(.ok(json: #"{"fields":{"displayName":{"stringValue":"Ada"}}}"#))
        await service.load()

        service.reset()

        #expect(service.profile == nil)
        #expect(service.loadFailure == nil)
    }

    @Test func everyLoadFailureExplainsItselfWithoutRepeatingTheHeadline() {
        let failures: [ViewerProfileLoadFailure] = [
            .notSignedIn, .permissionDenied, .server(status: 500), .transport, .malformedResponse
        ]
        for failure in failures {
            #expect(!failure.message.isEmpty)
            #expect(!failure.guidance.isEmpty)
            #expect(!failure.systemImage.isEmpty)
        }
    }
}
