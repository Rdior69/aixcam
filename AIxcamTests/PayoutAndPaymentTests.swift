//
//  PayoutAndPaymentTests.swift
//  AIxcamTests
//
//  Covers the payment/payout defects that were only reachable once these
//  services were actually called — none of this code had ever executed.
//

import Testing
@testable import AIxcam
import Foundation

// MARK: - Payout DTO decoding

@Suite("CreatorPayoutService decoding")
struct CreatorPayoutDecodingTests {

    /// Mirrors the decoder configured in `CreatorPayoutService.send`.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Regression: `.convertFromSnakeCase` maps `account_id` to `accountId`,
    /// which did not match the synthesized `accountID` key, so every
    /// createConnectedAccount call failed with .decodingFailed.
    @Test func connectedAccountDecodesSnakeCaseAccountID() throws {
        let json = """
        {
          "account_id": "acct_123",
          "payouts_enabled": true,
          "details_submitted": false
        }
        """.data(using: .utf8)!

        let account = try decoder().decode(ConnectedAccount.self, from: json)

        #expect(account.accountID == "acct_123")
        #expect(account.payoutsEnabled)
        #expect(!account.detailsSubmitted)
    }

    @Test func payoutBalanceDecodesSnakeCaseFields() throws {
        let json = """
        {
          "available_minor_units": 12345,
          "pending_minor_units": 250,
          "currency": "usd"
        }
        """.data(using: .utf8)!

        let balance = try decoder().decode(PayoutBalance.self, from: json)

        #expect(balance.availableMinorUnits == 12345)
        #expect(balance.pendingMinorUnits == 250)
        #expect(balance.currency == "usd")
    }

    @Test func onboardingLinkDecodesURLAndExpiry() throws {
        let json = """
        {
          "url": "https://connect.stripe.com/setup/abc",
          "expires_at": "2026-08-30T12:00:00Z"
        }
        """.data(using: .utf8)!

        let link = try decoder().decode(OnboardingLink.self, from: json)

        let expected = ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z")

        #expect(link.url.absoluteString == "https://connect.stripe.com/setup/abc")
        #expect(link.expiresAt == expected)
    }
}

// MARK: - Endpoint construction

@Suite("CreatorPayoutService endpoints")
struct CreatorPayoutEndpointTests {

    /// Regression: `URL(string:relativeTo:)` performs RFC 3986 relative
    /// resolution, which replaces the final path segment — so a versioned base
    /// URL silently lost its version prefix on every request.
    @Test func endpointPreservesAVersionedBasePath() {
        let base = URL(string: "https://api.example.com/v1")!
        let url = CreatorPayoutService.endpointURL(base: base, path: "connect/accounts")

        #expect(url.absoluteString == "https://api.example.com/v1/connect/accounts")
    }

    @Test func endpointHandlesATrailingSlashOnTheBase() {
        let base = URL(string: "https://api.example.com/v1/")!
        let url = CreatorPayoutService.endpointURL(base: base, path: "connect/accounts")

        #expect(url.absoluteString == "https://api.example.com/v1/connect/accounts")
    }

    @Test func endpointHandlesABareHost() {
        let base = URL(string: "https://api.example.com")!
        let url = CreatorPayoutService.endpointURL(base: base, path: "connect/accounts")

        #expect(url.absoluteString == "https://api.example.com/connect/accounts")
    }

    @Test func balancePathIncludesTheAccountID() {
        let base = URL(string: "https://api.example.com/v1")!
        let url = CreatorPayoutService.endpointURL(
            base: base,
            path: "connect/accounts/acct_123/balance"
        )

        #expect(url.absoluteString == "https://api.example.com/v1/connect/accounts/acct_123/balance")
    }
}

// MARK: - Payment errors and product catalogue

@Suite("PaymentService catalogue and errors")
struct PaymentServiceCatalogueTests {

    @Test func tipAndSubscriptionIDsDoNotOverlap() {
        #expect(ProductID.tips.isDisjoint(with: ProductID.subscriptions),
                "A product cannot be both a tip and a subscription")
        #expect(ProductID.all.count == ProductID.tips.count + ProductID.subscriptions.count)
    }

    /// These strings are the App Store Connect contract — a typo here means the
    /// product silently fails to load and the tip sheet renders empty.
    @Test func productIDsUseTheExpectedNamespace() {
        for id in ProductID.all {
            #expect(id.hasPrefix("com.aixcam."), "Unexpected product namespace: \(id)")
        }
        for id in ProductID.tips {
            #expect(id.hasPrefix("com.aixcam.tip."))
        }
        for id in ProductID.subscriptions {
            #expect(id.hasPrefix("com.aixcam.sub."))
        }
    }

    @Test func everyPaymentErrorHasADescription() {
        let errors: [PaymentError] = [
            .productsUnavailable,
            .purchasePending,
            .userCancelled,
            .failedVerification,
            .attributionFailed,
            .missingCreator,
            .unknown(NSError(domain: "test", code: 1))
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    /// The attribution failure message has to make clear no money moved,
    /// otherwise a buyer retries thinking they were charged twice.
    @Test func attributionFailureSaysNothingWasCharged() {
        let message = PaymentError.attributionFailed.errorDescription ?? ""
        #expect(message.lowercased().contains("nothing was charged"))

        let missing = PaymentError.missingCreator.errorDescription ?? ""
        #expect(missing.lowercased().contains("nothing was charged"))
    }

    @Test func everyPayoutErrorHasADescription() {
        let errors: [PayoutError] = [
            .invalidURL,
            .requestFailed(statusCode: 500),
            .decodingFailed,
            .network(NSError(domain: "test", code: 1))
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
