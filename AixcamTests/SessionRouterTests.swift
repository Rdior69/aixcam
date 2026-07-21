import XCTest
@testable import Aixcam

final class SessionRouterTests: XCTestCase {
    func testSignedOutRoutesToUnauthenticated() {
        XCTAssertEqual(SessionRouter.route(for: nil), .unauthenticated)
    }

    func testCreatorWithoutPublishNeedsOnboarding() {
        let user = makeUser(type: .creator, published: false)
        XCTAssertEqual(SessionRouter.route(for: user), .creatorNeedsOnboarding)
    }

    func testPublishedCreatorRoutesHome() {
        let user = makeUser(type: .creator, published: true)
        XCTAssertEqual(SessionRouter.route(for: user), .creatorHome)
    }

    func testFanWithoutSubscriberOnboarding() {
        let user = makeUser(type: .fan, published: false, subscriberOnboarding: false)
        XCTAssertEqual(SessionRouter.route(for: user), .subscriberNeedsOnboarding)
    }

    func testFanWithSubscriberOnboarding() {
        let user = makeUser(type: .fan, published: false, subscriberOnboarding: true)
        XCTAssertEqual(SessionRouter.route(for: user), .subscriberHome)
    }

    func testSuspendedAccountIsBlocked() {
        let user = makeUser(type: .creator, published: true, status: .suspended)
        XCTAssertEqual(SessionRouter.route(for: user), .accountBlocked(.suspended))
    }

    func testRestrictedAccountIsBlocked() {
        let user = makeUser(type: .fan, published: false, status: .restricted)
        XCTAssertEqual(SessionRouter.route(for: user), .accountBlocked(.restricted))
    }

    private func makeUser(
        type: AccountType,
        published: Bool,
        subscriberOnboarding: Bool = false,
        status: AccountStatus = .active
    ) -> AppUser {
        AppUser(
            id: "user-1",
            name: "Test User",
            email: "test@example.com",
            accountType: type,
            createdAt: Date(timeIntervalSince1970: 0),
            hasPublishedCreatorProfile: published,
            accountStatus: status,
            hasCompletedSubscriberOnboarding: subscriberOnboarding
        )
    }
}
