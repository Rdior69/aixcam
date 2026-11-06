import Foundation
import StoreKit

/// Errors surfaced by the StoreKit 2 purchase pipeline.
enum PaymentError: LocalizedError {
    case productsUnavailable
    case purchasePending
    case userCancelled
    case failedVerification
    /// The buyer→creator mapping could not be recorded, so the purchase was not
    /// attempted. Charging here would take the money with no way to credit the
    /// creator — see `PaymentService.purchase(_:creatorID:)`.
    case attributionFailed
    case missingCreator
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return String(localized: "The store is currently unavailable. Please try again later.")
        case .purchasePending:
            return String(localized: "Your purchase is pending approval and will complete shortly.")
        case .userCancelled:
            return String(localized: "Purchase cancelled.")
        case .failedVerification:
            return String(localized: "We couldn’t verify this purchase with the App Store.")
        case .attributionFailed:
            return String(localized: "We couldn’t link this payment to the creator, so nothing was charged. Please try again.")
        case .missingCreator:
            return String(localized: "This payment isn’t linked to a creator, so nothing was charged.")
        case .unknown(let error):
            // Through AppError rather than `localizedDescription`: StoreKit and
            // network errors here are rarely phrased for a buyer to read.
            return AppError(error).message
        }
    }
}

/// The result of attempting a purchase, surfaced to the ViewModel layer.
enum PurchaseOutcome: Sendable {
    case success(Transaction)
    case pending
    case cancelled
}

/// Product identifiers configured in App Store Connect.
/// Consumables = tips; auto-renewables = recurring creator subscriptions.
enum ProductID {
    static let tips: Set<String> = [
        "com.aixcam.tip.small",
        "com.aixcam.tip.medium",
        "com.aixcam.tip.large"
    ]
    static let subscriptions: Set<String> = [
        "com.aixcam.sub.monthly",
        "com.aixcam.sub.annual"
    ]

    static var all: Set<String> { tips.union(subscriptions) }
}

/// StoreKit 2 manager. Owns product loading, purchasing, verification,
/// and the long-lived transaction listener that catches out-of-band updates
/// (Ask to Buy approvals, renewals, refunds, purchases made on other devices).
@MainActor
@Observable
final class PaymentService {

    // MARK: - Published State

    private(set) var tipProducts: [Product] = []
    private(set) var subscriptionProducts: [Product] = []

    /// Product IDs the user currently owns / is entitled to (active subscriptions).
    private(set) var activeEntitlements: Set<String> = []

    private(set) var isLoadingProducts = false

    // MARK: - Private

    @ObservationIgnored
    // nonisolated(unsafe) so deinit can cancel this without MainActor
    // .assumeIsolated, which would crash if deinit ran off the main thread.
    // Safe because the task is written once in start() and read once in deinit,
    // with no concurrent access. Mirrors AppRouter's auth listener handle.
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    @ObservationIgnored
    private let backend: PaymentBackend

    // MARK: - Lifecycle

    /// Constructing the service does nothing observable. StoreKit work is
    /// deferred to `start()` so a test (or a preview) can hold a
    /// `PaymentService` without a transaction listener and a product fetch
    /// firing off the moment it is initialised.
    init(backend: PaymentBackend = FirebasePaymentBackend()) {
        self.backend = backend
    }

    /// Begins listening for transactions and loads the catalogue. Idempotent,
    /// so it is safe to call from a SwiftUI `.task` that may re-run.
    ///
    /// Call this once, as early as possible: the listener must be running
    /// BEFORE any purchase can occur so no transaction is missed.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = listenForTransactions()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: ProductID.all)
            tipProducts = products
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
            subscriptionProducts = products
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }
        } catch {
            tipProducts = []
            subscriptionProducts = []
        }
    }

    // MARK: - Purchasing

    /// Purchase a product. A fresh per-purchase `appAccountToken` is generated so
    /// each transaction can be attributed to the specific creator being supported.
    /// When `creatorID` is provided, the buyer→creator mapping is recorded server
    /// side (`attributions/{token}`) before the purchase, so the backend ledger can
    /// credit the right creator when it verifies the resulting transaction.
    func purchase(_ product: Product, creatorID: String? = nil) async throws -> PurchaseOutcome {
        let token = UUID()

        // Attribution must succeed BEFORE the charge. This used to be a
        // fire-and-forget call whose failures were swallowed, which meant a
        // rules rejection or a dropped connection produced a completed payment
        // with no buyer→creator mapping: the money was taken and the creator
        // could never be credited, with nothing for the ledger to reconcile
        // against. Failing here costs the buyer a retry; failing silently cost
        // the creator their tip.
        if let creatorID {
            let trimmed = creatorID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PaymentError.missingCreator }
            try await backend.registerAttribution(token: token, creatorID: trimmed)
        }

        let options: Set<Product.PurchaseOption> = [.appAccountToken(token)]

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch {
            throw PaymentError.unknown(error)
        }

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await deliver(jws: verification.jwsRepresentation)
            await transaction.finish()
            return .success(transaction)

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            throw PaymentError.unknown(
                NSError(domain: "PaymentService", code: -1)
            )
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Recompute active entitlements from `Transaction.currentEntitlements`.
    /// This is the source of truth for whether a subscription is active.
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            // Skip revoked or lapsed entitlements.
            if transaction.revocationDate != nil { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }

            active.insert(transaction.productID)
        }
        activeEntitlements = active
    }

    func hasActiveSubscription() -> Bool {
        !activeEntitlements.isDisjoint(with: ProductID.subscriptions)
    }

    // MARK: - Transaction Listener

    /// Long-lived loop for transactions that arrive outside a direct purchase:
    /// renewals, Ask-to-Buy approvals, refunds, cross-device purchases.
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                // End the loop once the service is deallocated.
                guard let self else { break }
                guard let transaction = try? self.checkVerified(update) else { continue }
                await self.deliver(jws: update.jwsRepresentation)
                await transaction.finish()
            }
        }
    }

    // MARK: - Delivery & Verification

    /// Grant the purchase locally and inform the backend so the creator ledger
    /// is credited. Backend should re-verify the signed transaction server-side.
    private func deliver(jws: String) async {
        await refreshEntitlements()
        // Forward the signed transaction to the backend for authoritative
        // server-side verification. Local entitlements drive UI only; creator
        // payouts and durable subscription state MUST be decided server-side from
        // this JWS (and App Store Server Notifications), never from the client's word.
        await backend.forwardTransaction(jws: jws)
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Unwrap a `VerificationResult`, throwing on a failed StoreKit signature check.
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaymentError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
