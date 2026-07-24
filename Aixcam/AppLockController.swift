import Combine
import Foundation
import SwiftUI

@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var policy: AppLockPolicy
    @Published private(set) var hasPIN: Bool
    @Published var statusMessage: String?
    @Published private(set) var failedPINAttempts = 0

    let biometricService: BiometricAuthenticating

    private let store: AppLockStore
    private var backgroundedAt: Date?

    init(
        store: AppLockStore = AppLockStore(),
        biometricService: BiometricAuthenticating = BiometricAuthService()
    ) {
        self.store = store
        self.biometricService = biometricService
        self.policy = store.loadPolicy()
        self.hasPIN = store.hasPIN
    }

    var isAppLockActive: Bool {
        policy.isEnabled && hasPIN
    }

    var biometryName: String {
        biometricService.biometryDisplayName
    }

    var canOfferBiometrics: Bool {
        policy.biometricEnabled && biometricService.canUseBiometrics && isAppLockActive
    }

    /// Call when session becomes authenticated (after bootstrap / login).
    func evaluateAuthenticatedEntry() {
        refreshFromStore()
        if AppLockPolicy.shouldLockOnAuthenticatedLaunch(policy: policy, hasPIN: hasPIN) {
            isLocked = true
        }
    }

    func handleScenePhase(_ phase: ScenePhase, isAuthenticated: Bool) {
        guard isAuthenticated, isAppLockActive else {
            if phase == .active {
                backgroundedAt = nil
            }
            return
        }

        switch phase {
        case .background, .inactive:
            if backgroundedAt == nil {
                backgroundedAt = Date()
            }
            if policy.backgroundTimeout == .immediate {
                isLocked = true
            }
        case .active:
            if AppLockPolicy.shouldLockAfterBackground(
                policy: policy,
                hasPIN: hasPIN,
                backgroundedAt: backgroundedAt
            ) {
                isLocked = true
            }
            backgroundedAt = nil
        @unknown default:
            break
        }
    }

    func unlockWithPIN(_ pin: String) -> Bool {
        guard store.verifyPIN(pin) else {
            failedPINAttempts += 1
            statusMessage = "Incorrect PIN."
            return false
        }
        failedPINAttempts = 0
        statusMessage = nil
        isLocked = false
        return true
    }

    func unlockWithBiometrics() async {
        guard canOfferBiometrics else {
            statusMessage = "Biometrics unavailable. Enter your PIN."
            return
        }
        do {
            try await biometricService.authenticate(reason: "Unlock Aixcam")
            failedPINAttempts = 0
            statusMessage = nil
            isLocked = false
        } catch BiometricAuthError.cancelled {
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func enableLock(withPIN pin: String, biometricEnabled: Bool, timeout: AppLockBackgroundTimeout) throws {
        try store.setPIN(pin)
        var next = store.loadPolicy()
        next.isEnabled = true
        next.biometricEnabled = biometricEnabled
        next.backgroundTimeout = timeout
        try store.savePolicy(next)
        refreshFromStore()
        statusMessage = "App Lock enabled."
    }

    func updateSettings(biometricEnabled: Bool, timeout: AppLockBackgroundTimeout) throws {
        var next = store.loadPolicy()
        next.biometricEnabled = biometricEnabled
        next.backgroundTimeout = timeout
        if hasPIN {
            next.isEnabled = true
        }
        try store.savePolicy(next)
        refreshFromStore()
    }

    func disableLock() throws {
        try store.clearPIN()
        refreshFromStore()
        isLocked = false
        statusMessage = "App Lock disabled."
    }

    func clearStatus() {
        statusMessage = nil
    }

    private func refreshFromStore() {
        policy = store.loadPolicy()
        hasPIN = store.hasPIN
    }
}
