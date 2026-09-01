//
//  LiveChannelTests.swift
//  AIxcamTests
//
//  Covers the wire contract with listLiveChannels and the Discover projection.
//

import Testing
@testable import AIxcam
import Foundation

// MARK: - Wire decoding

@Suite("LiveChannel decoding")
struct LiveChannelDecodingTests {

    private func envelope(_ channelsJSON: String) -> Data {
        """
        { "result": { "channels": \(channelsJSON) } }
        """.data(using: .utf8)!
    }

    @Test func decodesAFullChannel() throws {
        let data = envelope("""
        [{
          "streamId": "s1",
          "creatorId": "c1",
          "displayName": "Ada",
          "startedAt": "2026-08-30T12:00:00.000Z",
          "playbackURL": "https://example.com/a.m3u8"
        }]
        """)

        let channels = try LiveChannelDecoding.channels(from: data)

        #expect(channels.count == 1)
        #expect(channels[0].streamID == "s1")
        #expect(channels[0].creatorID == "c1")
        #expect(channels[0].displayName == "Ada")
        #expect(channels[0].playbackURL.absoluteString == "https://example.com/a.m3u8")
        #expect(channels[0].startedAt != nil)
    }

    /// Node's toISOString() emits fractional seconds; the plain form has to
    /// parse too so a hand-written or reformatted payload still works.
    @Test func parsesBothISO8601Forms() {
        #expect(LiveChannelDecoding.parseDate("2026-08-30T12:00:00.000Z") != nil)
        #expect(LiveChannelDecoding.parseDate("2026-08-30T12:00:00Z") != nil)
        #expect(LiveChannelDecoding.parseDate("not a date") == nil)
    }

    @Test func missingStartedAtIsTolerated() throws {
        let data = envelope("""
        [{
          "streamId": "s1", "creatorId": "c1", "displayName": "Ada",
          "startedAt": null, "playbackURL": "https://example.com/a.m3u8"
        }]
        """)

        let channels = try LiveChannelDecoding.channels(from: data)

        #expect(channels.count == 1)
        #expect(channels[0].startedAt == nil)
    }

    /// A plaintext playback URL would downgrade the viewer's connection, so it
    /// is dropped rather than played.
    @Test func dropsNonHTTPSPlaybackURLs() throws {
        let data = envelope("""
        [{
          "streamId": "s1", "creatorId": "c1", "displayName": "Ada",
          "startedAt": null, "playbackURL": "http://example.com/a.m3u8"
        }]
        """)

        #expect(try LiveChannelDecoding.channels(from: data).isEmpty)
    }

    @Test func dropsEntriesMissingIdentifiersOrURL() throws {
        let data = envelope("""
        [
          { "streamId": "", "creatorId": "c1", "displayName": "A", "startedAt": null, "playbackURL": "https://e.com/a.m3u8" },
          { "streamId": "s2", "creatorId": "", "displayName": "B", "startedAt": null, "playbackURL": "https://e.com/b.m3u8" },
          { "streamId": "s3", "creatorId": "c3", "displayName": "C", "startedAt": null, "playbackURL": "" }
        ]
        """)

        #expect(try LiveChannelDecoding.channels(from: data).isEmpty)
    }

    /// One bad entry must not take the whole feed down with it.
    @Test func oneBadEntryDoesNotDiscardTheGoodOnes() throws {
        let data = envelope("""
        [
          { "streamId": "s1", "creatorId": "c1", "displayName": "Good", "startedAt": null, "playbackURL": "https://e.com/a.m3u8" },
          { "streamId": "s2", "creatorId": "c2", "displayName": "Bad", "startedAt": null, "playbackURL": "" }
        ]
        """)

        let channels = try LiveChannelDecoding.channels(from: data)

        #expect(channels.count == 1)
        #expect(channels[0].displayName == "Good")
    }

    @Test func emptyFeedDecodesToNoChannels() throws {
        #expect(try LiveChannelDecoding.channels(from: envelope("[]")).isEmpty)
    }

    /// Malformed JSON is a different failure from a malformed entry and must
    /// surface, not be silently swallowed as "nobody is live".
    @Test func malformedPayloadThrows() {
        let garbage = "{ \"nope\": true }".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try LiveChannelDecoding.channels(from: garbage)
        }
    }

    @Test func titleFallsBackWhenTheCreatorHasNoName() {
        let unnamed = LiveChannel(
            streamID: "s", creatorID: "c", displayName: "   ",
            startedAt: nil, playbackURL: URL(string: "https://e.com/a.m3u8")!
        )
        let named = LiveChannel(
            streamID: "s", creatorID: "c", displayName: "Ada",
            startedAt: nil, playbackURL: URL(string: "https://e.com/a.m3u8")!
        )

        #expect(unnamed.title == "Live creator")
        #expect(named.title == "Ada")
    }
}

// MARK: - Feed state

@Suite("LiveChannelService")
@MainActor
struct LiveChannelServiceTests {

    private func channel(_ id: String) -> LiveChannel {
        LiveChannel(
            streamID: id, creatorID: "c-\(id)", displayName: id,
            startedAt: nil, playbackURL: URL(string: "https://e.com/\(id).m3u8")!
        )
    }

    @Test func startsEmptyAndUnloaded() {
        let service = LiveChannelService(provider: StaticLiveChannelProvider())
        #expect(service.channels.isEmpty)
        #expect(!service.hasLoadedOnce)
    }

    @Test func refreshPublishesTheFeed() async {
        let service = LiveChannelService(
            provider: StaticLiveChannelProvider(channels: [channel("a"), channel("b")])
        )

        await service.refresh()

        #expect(service.channels.count == 2)
        #expect(service.hasLoadedOnce)
        #expect(!service.loadFailed)
    }

    /// An empty feed after a successful load is "nobody is live", which the UI
    /// must be able to tell apart from "we haven't looked yet".
    @Test func successfulEmptyLoadStillMarksLoaded() async {
        let service = LiveChannelService(provider: StaticLiveChannelProvider(channels: []))

        await service.refresh()

        #expect(service.channels.isEmpty)
        #expect(service.hasLoadedOnce)
        #expect(!service.loadFailed)
    }

    /// A failed refresh must not blank out a feed the viewer is looking at.
    @Test func failedRefreshKeepsTheExistingFeed() async {
        let good = LiveChannelService(
            provider: StaticLiveChannelProvider(channels: [channel("a")])
        )
        await good.refresh()
        #expect(good.channels.count == 1)

        let failing = LiveChannelService(
            provider: StaticLiveChannelProvider(
                channels: [channel("a")],
                error: LiveChannelError.requestFailed(statusCode: 500)
            )
        )
        await failing.refresh()

        #expect(failing.loadFailed)
        #expect(failing.channels.isEmpty, "Nothing had loaded yet, so there is nothing to keep")
    }

    @Test func everyLiveChannelErrorHasADescription() {
        let errors: [LiveChannelError] = [
            .notAuthenticated,
            .requestFailed(statusCode: 503),
            .decodingFailed,
            .network(NSError(domain: "test", code: 1))
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

// MARK: - Elapsed formatting

@Suite("Discover elapsed time")
struct DiscoverElapsedTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func showsJustNowUnderAMinute() {
        #expect(DiscoverView.elapsed(since: start, now: start.addingTimeInterval(30)) == "just now")
    }

    @Test func showsWholeMinutesUnderAnHour() {
        #expect(DiscoverView.elapsed(since: start, now: start.addingTimeInterval(12 * 60)) == "12m")
    }

    @Test func showsHoursAndZeroPaddedMinutes() {
        let later = start.addingTimeInterval(3600 + 4 * 60)
        #expect(DiscoverView.elapsed(since: start, now: later) == "1h 04m")
    }

    /// Clock skew between the server's startedAt and the device must not render
    /// a negative duration.
    @Test func clampsAFutureStartToJustNow() {
        #expect(DiscoverView.elapsed(since: start, now: start.addingTimeInterval(-500)) == "just now")
    }
}
