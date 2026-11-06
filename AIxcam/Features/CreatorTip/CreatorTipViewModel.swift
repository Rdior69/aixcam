import Foundation
import OSLog
import StoreKit

@MainActor
@Observable
final class CreatorTipViewModel {

    // MARK: - View State

    enum ViewState: Equatable {
        case idle
        case loading
        case purchasing(productID: String)
        case ready
    }

    private(set) var state: ViewState = .idle
    var error: AppError?           // Presented by `.errorAlert` in the view.
    var isShowingThankYou = false

    var tipProducts: [Product] { payment.tipProducts }
    var subscriptionProducts: [Product] { payment.subscriptionProducts }
    var isSubscribed: Bool { payment.hasActiveSubscription() }

    /// True only for the subscription the buyer actually owns. `isSubscribed`
    /// alone badged *every* tier as "Active" and left them all tappable, so a
    /// subscriber could be sold a second, different tier.
    func isEntitled(to product: Product) -> Bool {
        payment.activeEntitlements.contains(product.id)
    }

    /// Nothing purchasable came back. `PaymentService.loadProducts()` swallows
    /// its error and empties both lists, so without this the screen renders as
    /// a blank list with no explanation.
    var hasNoProducts: Bool {
        tipProducts.isEmpty && subscriptionProducts.isEmpty
    }

    func reload() async {
        state = .loading
        await payment.loadProducts()
        await payment.refreshEntitlements()
        state = .ready
    }

    // MARK: - Dependencies

    private let payment: PaymentService
    private let creatorID: String

    init(payment: PaymentService, creatorID: String) {
        self.payment = payment
        self.creatorID = creatorID
    }

    // MARK: - Intents

    func onAppear() async {
        state = .loading
        if payment.tipProducts.isEmpty && payment.subscriptionProducts.isEmpty {
            await payment.loadProducts()
        }
        await payment.refreshEntitlements()
        state = .ready
    }

    func buy(_ product: Product) async {
        // Ignore taps while a purchase is already in flight.
        if case .purchasing = state { return }
        state = .purchasing(productID: product.id)
        await performPurchase(product)
    }

    func restore() async {
        do {
            try await payment.restorePurchases()
        } catch {
            report(error)
        }
    }

    // MARK: - Private

    private func performPurchase(_ product: Product) async {
        defer { state = .ready }
        do {
            let outcome = try await payment.purchase(product, creatorID: creatorID)
            switch outcome {
            case .success:
                isShowingThankYou = true
            case .pending:
                // Not a failure, but it needs the same acknowledgement, so it
                // reuses the alert rather than adding a second presentation.
                error = AppError(PaymentError.purchasePending)
            case .cancelled:
                break   // Silent — user chose to back out.
            }
        } catch {
            report(error)
        }
    }

    /// Records a failure for the UI and logs the detail.
    ///
    /// `AppError` already prefers a `LocalizedError`'s own wording, so
    /// `PaymentError` needs no special case here.
    private func report(_ failure: Error) {
        guard let presentable = AppError.presentable(failure) else { return }
        error = presentable
        AppLog.payments.error("\(presentable.diagnostic, privacy: .public)")
    }
}
