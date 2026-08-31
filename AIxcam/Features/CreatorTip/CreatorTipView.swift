import SwiftUI
import StoreKit

struct CreatorTipView: View {
    @State private var viewModel: TipOrSubscribeViewModel

    init(viewModel: TipOrSubscribeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                default:
                    if viewModel.hasNoProducts {
                        unavailableState
                    } else {
                        content
                    }
                }
            }
            .navigationTitle("Support This Creator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await viewModel.restore() }
                    }
                }
            }
        }
        .task { await viewModel.onAppear() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            ),
            presenting: viewModel.alertMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert("Thank you!", isPresented: $viewModel.showThankYou) {
            Button("You’re welcome", role: .cancel) {}
        } message: {
            Text("Your support means a lot to this creator.")
        }
    }

    // MARK: - Sections

    private var content: some View {
        List {
            tipsSection
            subscriptionSection
        }
        .listStyle(.insetGrouped)
    }

    private var tipsSection: some View {
        Section("Send a Tip") {
            ForEach(viewModel.tipProducts, id: \.id) { product in
                purchaseRow(product, badge: nil)
            }
        }
    }

    /// Shown when the store returned nothing, so the screen explains itself and
    /// offers a way out instead of presenting an empty list.
    private var unavailableState: some View {
        ContentUnavailableView {
            Label("Support unavailable", systemImage: "creditcard.trianglebadge.exclamationmark")
        } description: {
            Text("We couldn’t load tips or subscriptions right now. Check your connection and try again.")
        } actions: {
            Button("Try Again") {
                Task { await viewModel.reload() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var subscriptionSection: some View {
        Section {
            ForEach(viewModel.subscriptionProducts, id: \.id) { product in
                purchaseRow(
                    product,
                    badge: viewModel.isEntitled(to: product) ? "Active" : nil
                )
            }
        } header: {
            Text("Subscribe")
        } footer: {
            Text("Subscriptions renew automatically. Manage or cancel anytime in Settings.")
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func purchaseRow(_ product: Product, badge: String?) -> some View {
        let isThisPurchasing = viewModel.state == .purchasing(productID: product.id)
        let isAnyPurchasing: Bool = {
            if case .purchasing = viewModel.state { return true }
            return false
        }()
        // Already owned: showing an enabled row invites buying it twice.
        let isOwned = badge != nil

        Button {
            Task { await viewModel.buy(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isThisPurchasing {
                    ProgressView()
                } else if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(product.displayPrice)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAnyPurchasing || isOwned)
    }
}
