//
//  IdentityVerificationTests.swift
//  AIxcamTests
//
//  Covers the gate that keeps unverified accounts off the broadcast path.
//

import Testing
@testable import AIxcam
import Foundation

// MARK: - Status semantics

@Suite("IdentityVerificationStatus")
struct IdentityVerificationStatusTests {

    @Test func onlyApprovedAllowsBroadcasting() {
        #expect(IdentityVerificationStatus.approved.allowsBroadcasting)

        // Everything else must fail closed — pending especially, since a
        // submitted-but-unreviewed creator is not a verified one.
        for status in [IdentityVerificationStatus.unverified, .pending, .rejected] {
            #expect(!status.allowsBroadcasting, "\(status.rawValue) must not permit broadcasting")
        }
    }

    @Test func approvedIsTheOnlyStatusWithoutABlockedReason() {
        #expect(IdentityVerificationStatus.approved.broadcastBlockedReason == nil)

        for status in [IdentityVerificationStatus.unverified, .pending, .rejected] {
            let reason = status.broadcastBlockedReason
            #expect(reason?.isEmpty == false,
                    "\(status.rawValue) must explain why broadcasting is blocked")
        }
    }

    @Test func everyStatusHasANonEmptyLabel() {
        for status in IdentityVerificationStatus.allCases {
            #expect(!status.label.isEmpty)
        }
    }

    /// Raw values are the wire contract with getIdentityVerificationStatus, and
    /// are persisted by the KYC webhook. Renaming one silently breaks the gate.
    @Test func rawValuesMatchTheBackendContract() {
        #expect(IdentityVerificationStatus.unverified.rawValue == "unverified")
        #expect(IdentityVerificationStatus.pending.rawValue == "pending")
        #expect(IdentityVerificationStatus.approved.rawValue == "approved")
        #expect(IdentityVerificationStatus.rejected.rawValue == "rejected")
    }

    @Test func unrecognisedRawValueDoesNotDecode() {
        // The provider maps a nil init back to .unverified; this asserts the
        // enum itself does not quietly accept something unexpected.
        #expect(IdentityVerificationStatus(rawValue: "verified") == nil)
        #expect(IdentityVerificationStatus(rawValue: "APPROVED") == nil)
        #expect(IdentityVerificationStatus(rawValue: "") == nil)
    }
}

// MARK: - Service

@Suite("IdentityVerificationService")
@MainActor
struct IdentityVerificationServiceTests {

    private struct FailingProvider: IdentityVerificationProviding {
        func fetchStatus() async throws -> IdentityVerificationStatus {
            throw IdentityVerificationError.requestFailed(statusCode: 500)
        }
    }

    @Test func startsUnverifiedBeforeAnyFetch() {
        let service = IdentityVerificationService(
            provider: StaticIdentityVerificationProvider(status: .approved)
        )
        // Not yet refreshed: must not report approved on the strength of the
        // provider alone.
        #expect(service.status == .unverified)
    }

    @Test func refreshAdoptsTheBackendStatus() async {
        let service = IdentityVerificationService(
            provider: StaticIdentityVerificationProvider(status: .approved)
        )
        await service.refresh()

        #expect(service.status == .approved)
        #expect(!service.loadFailed)
    }

    /// A network failure must not demote a creator who is already approved —
    /// that would kick them off air mid-session.
    @Test func refreshFailureKeepsTheLastKnownStatus() async {
        let service = IdentityVerificationService(
            provider: StaticIdentityVerificationProvider(status: .approved)
        )
        await service.refresh()
        #expect(service.status == .approved)

        let failing = IdentityVerificationService(provider: FailingProvider())
        await failing.refresh()

        #expect(failing.status == .unverified, "A failed first fetch must stay closed")
        #expect(failing.loadFailed)
    }

    @Test func resetClearsStatusForTheNextAccount() async {
        let service = IdentityVerificationService(
            provider: StaticIdentityVerificationProvider(status: .approved)
        )
        await service.refresh()
        #expect(service.status == .approved)

        service.reset()

        #expect(service.status == .unverified,
                "Signing out must not leave the next person holding this status")
    }
}

// MARK: - Broadcast gate

@Suite("LiveBroadcastViewModel verification gate")
@MainActor
struct LiveBroadcastVerificationGateTests {

    private func viewModel(status: IdentityVerificationStatus) -> LiveBroadcastViewModel {
        LiveBroadcastViewModel(
            creatorID: "creator1",
            streamingService: MockStreamingService(),
            verificationProvider: StaticIdentityVerificationProvider(status: status)
        )
    }

    @Test func startsUnverifiedSoTheGateIsClosedByDefault() {
        let vm = viewModel(status: .approved)
        #expect(!vm.isIdentityVerified)
        #expect(!vm.canStartLive)
    }

    @Test func approvedCreatorClearsTheVerificationGate() async {
        let vm = viewModel(status: .approved)
        await vm.refreshVerificationStatus()

        #expect(vm.isIdentityVerified)
        #expect(vm.verificationBlockedReason == nil)
    }

    @Test func unapprovedStatusesBlockWithAReason() async {
        for status in [IdentityVerificationStatus.unverified, .pending, .rejected] {
            let vm = viewModel(status: status)
            await vm.refreshVerificationStatus()

            #expect(!vm.isIdentityVerified, "\(status.rawValue) should not clear the gate")
            #expect(vm.verificationBlockedReason?.isEmpty == false,
                    "\(status.rawValue) should say why")
            #expect(!vm.canStartLive)
        }
    }

    /// canStartLive drives a disabled button, which is only an affordance.
    /// goLive() is the actual boundary and must refuse on its own.
    @Test func goLiveRefusesAnUnverifiedCreatorAndExplainsWhy() async {
        let vm = viewModel(status: .unverified)
        vm.hasPermission = true
        vm.infrastructureStatus = StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "ready"
        )

        await vm.goLive()

        #expect(!vm.isLive, "An unverified creator must not reach the air")
        #expect(vm.errorMessage == IdentityVerificationStatus.unverified.broadcastBlockedReason)
    }

    @Test func goLiveRefusesWhileVerificationIsStillPending() async {
        let vm = viewModel(status: .pending)
        vm.hasPermission = true
        vm.infrastructureStatus = StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "ready"
        )

        await vm.goLive()

        #expect(!vm.isLive)
        #expect(vm.errorMessage == IdentityVerificationStatus.pending.broadcastBlockedReason)
    }

    @Test func verifiedCreatorWithEverythingElseReadyCanStart() async {
        let vm = viewModel(status: .approved)
        await vm.refreshVerificationStatus()
        vm.hasPermission = true
        vm.infrastructureStatus = StreamingInfrastructureStatus(
            isReady: true,
            securityLevel: .secure,
            description: "ready"
        )

        #expect(vm.canStartLive)
    }
}
