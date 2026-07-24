import XCTest
@testable import Aixcam

final class FirebaseBootstrapTests: XCTestCase {
    func testFactoryDefaultsToLocalWithoutFirebasePlist() {
        // In this CI/dev tree, GoogleService-Info.plist is not bundled.
        XCTAssertEqual(CreatorBackendFactory.activeKind, .local)
        XCTAssertTrue(CreatorBackendFactory.makeService() is LocalCreatorBackendService)
    }

    func testPlistDetectionUsesBundleResourceName() {
        // Bundle.main in unit tests does not include a GoogleService-Info.plist.
        XCTAssertFalse(FirebaseBootstrap.hasGoogleServiceInfoPlist(in: .main))
        XCTAssertFalse(FirebaseBootstrap.configureIfPossible(bundle: .main))
    }

    func testAuthErrorMapperMapsDuplicateEmail() {
        let error = NSError(domain: FirebaseAuthErrorMapper.authErrorDomain, code: 17007)
        XCTAssertEqual(FirebaseAuthErrorMapper.map(error), .duplicateEmail)
    }

    func testAuthErrorMapperMapsWrongPassword() {
        let error = NSError(domain: FirebaseAuthErrorMapper.authErrorDomain, code: 17009)
        XCTAssertEqual(FirebaseAuthErrorMapper.map(error), .invalidCredentials)
    }

    func testAuthErrorMapperIgnoresUnknownDomains() {
        let error = NSError(domain: "SomeOtherDomain", code: 17007)
        XCTAssertNil(FirebaseAuthErrorMapper.map(error))
        XCTAssertEqual(FirebaseAuthErrorMapper.mapOrUnknown(error), .unknown)
    }
}
