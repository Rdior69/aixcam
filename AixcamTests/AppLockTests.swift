import XCTest
@testable import Aixcam

final class AppLockPolicyTests: XCTestCase {
    func testValidPINRequiresFourDigits() {
        XCTAssertTrue(AppLockPolicy.isValidPIN("1234"))
        XCTAssertFalse(AppLockPolicy.isValidPIN("123"))
        XCTAssertFalse(AppLockPolicy.isValidPIN("12a4"))
        XCTAssertFalse(AppLockPolicy.isValidPIN("12345"))
    }

    func testShouldNotLockWhenDisabled() {
        let policy = AppLockPolicy(isEnabled: false, biometricEnabled: true, backgroundTimeout: .immediate)
        XCTAssertFalse(
            AppLockPolicy.shouldLockAfterBackground(
                policy: policy,
                hasPIN: true,
                backgroundedAt: Date().addingTimeInterval(-10)
            )
        )
        XCTAssertFalse(AppLockPolicy.shouldLockOnAuthenticatedLaunch(policy: policy, hasPIN: true))
    }

    func testImmediateTimeoutLocksOnAnyBackground() {
        let policy = AppLockPolicy(isEnabled: true, biometricEnabled: true, backgroundTimeout: .immediate)
        XCTAssertTrue(
            AppLockPolicy.shouldLockAfterBackground(
                policy: policy,
                hasPIN: true,
                backgroundedAt: Date()
            )
        )
    }

    func testOneMinuteTimeoutRespectsElapsedTime() {
        let policy = AppLockPolicy(isEnabled: true, biometricEnabled: true, backgroundTimeout: .oneMinute)
        let now = Date()
        XCTAssertFalse(
            AppLockPolicy.shouldLockAfterBackground(
                policy: policy,
                hasPIN: true,
                backgroundedAt: now.addingTimeInterval(-30),
                now: now
            )
        )
        XCTAssertTrue(
            AppLockPolicy.shouldLockAfterBackground(
                policy: policy,
                hasPIN: true,
                backgroundedAt: now.addingTimeInterval(-61),
                now: now
            )
        )
    }

    func testLaunchLockRequiresPINAndEnabled() {
        let enabled = AppLockPolicy(isEnabled: true, biometricEnabled: true, backgroundTimeout: .oneMinute)
        XCTAssertTrue(AppLockPolicy.shouldLockOnAuthenticatedLaunch(policy: enabled, hasPIN: true))
        XCTAssertFalse(AppLockPolicy.shouldLockOnAuthenticatedLaunch(policy: enabled, hasPIN: false))
    }
}

final class AppLockStoreTests: XCTestCase {
    func testSetAndVerifyPIN() throws {
        let store = AppLockStore(credentialStore: MemoryCredentialStore())
        XCTAssertFalse(store.hasPIN)

        try store.setPIN("2468")
        XCTAssertTrue(store.hasPIN)
        XCTAssertTrue(store.verifyPIN("2468"))
        XCTAssertFalse(store.verifyPIN("0000"))
        XCTAssertTrue(store.loadPolicy().isEnabled)
    }

    func testClearPINDisablesLock() throws {
        let store = AppLockStore(credentialStore: MemoryCredentialStore())
        try store.setPIN("1357")
        try store.clearPIN()
        XCTAssertFalse(store.hasPIN)
        XCTAssertFalse(store.loadPolicy().isEnabled)
        XCTAssertFalse(store.verifyPIN("1357"))
    }

    func testRejectsInvalidPINLength() {
        let store = AppLockStore(credentialStore: MemoryCredentialStore())
        XCTAssertThrowsError(try store.setPIN("12"))
    }
}

@MainActor
final class AppLockControllerTests: XCTestCase {
    func testUnlockWithPIN() throws {
        let memory = MemoryCredentialStore()
        let store = AppLockStore(credentialStore: memory)
        try store.setPIN("9999")
        let controller = AppLockController(
            store: store,
            biometricService: StubBiometricAuthService(canUseBiometrics: false)
        )
        controller.evaluateAuthenticatedEntry()
        XCTAssertTrue(controller.isLocked)
        XCTAssertTrue(controller.unlockWithPIN("9999"))
        XCTAssertFalse(controller.isLocked)
    }

    func testBiometricUnlock() async throws {
        let memory = MemoryCredentialStore()
        let store = AppLockStore(credentialStore: memory)
        try store.setPIN("1111")
        let biometrics = StubBiometricAuthService(canUseBiometrics: true, shouldSucceed: true)
        let controller = AppLockController(store: store, biometricService: biometrics)
        controller.evaluateAuthenticatedEntry()
        XCTAssertTrue(controller.isLocked)
        await controller.unlockWithBiometrics()
        XCTAssertEqual(biometrics.authenticateCallCount, 1)
        XCTAssertFalse(controller.isLocked)
    }
}
