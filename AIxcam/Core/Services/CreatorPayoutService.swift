import Foundation

/// Errors from the Stripe Connect payout backend.
enum PayoutError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid payout service configuration.")
        case .requestFailed(let code):
            return String(localized: "The payout service returned an error (\(code)).")
        case .decodingFailed:
            return String(localized: "We couldn’t read the payout service response.")
        case .network(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - DTOs

/// A Stripe connected (Express) account belonging to a creator.
struct ConnectedAccount: Codable, Sendable {
    let accountID: String          // Stripe "acct_..."
    let payoutsEnabled: Bool
    let detailsSubmitted: Bool
}

/// A single-use onboarding link the app opens in a browser / ASWebAuthenticationSession.
struct OnboardingLink: Codable, Sendable {
    let url: URL
    let expiresAt: Date
}

/// Read-only snapshot of a creator's available/pending balance.
struct PayoutBalance: Codable, Sendable {
    let availableMinorUnits: Int
    let pendingMinorUnits: Int
    let currency: String
}

/// Abstraction so the ViewModel layer can be tested against a mock.
protocol CreatorPayoutServicing: Sendable {
    func createConnectedAccount(creatorID: String) async throws -> ConnectedAccount
    func onboardingLink(for accountID: String, returnURL: URL, refreshURL: URL) async throws -> OnboardingLink
    func fetchBalance(for accountID: String) async throws -> PayoutBalance
}

/// Client for YOUR backend, which holds the Stripe secret key and calls Stripe.
/// The secret key must NEVER live in the app. These are integration stubs that
/// call your backend's Connect endpoints.
final class CreatorPayoutService: CreatorPayoutServicing {

    private let baseURL: URL
    private let session: URLSession
    private let authTokenProvider: @Sendable () async -> String?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    // MARK: - Connect Account Creation

    func createConnectedAccount(creatorID: String) async throws -> ConnectedAccount {
        try await post(
            path: "connect/accounts",
            body: ["creator_id": creatorID],
            // Idempotency key prevents duplicate Stripe accounts on retry.
            idempotencyKey: "create-account-\(creatorID)"
        )
    }

    // MARK: - Onboarding Link

    func onboardingLink(
        for accountID: String,
        returnURL: URL,
        refreshURL: URL
    ) async throws -> OnboardingLink {
        // Account links are single-use and short-lived; a fresh key each call.
        try await post(
            path: "connect/onboarding-links",
            body: [
                "account_id": accountID,
                "return_url": returnURL.absoluteString,
                "refresh_url": refreshURL.absoluteString
            ],
            idempotencyKey: UUID().uuidString
        )
    }

    // MARK: - Balance

    func fetchBalance(for accountID: String) async throws -> PayoutBalance {
        try await get(path: "connect/accounts/\(accountID)/balance")
    }

    // MARK: - Networking Core

    private func get<Response: Decodable>(path: String) async throws -> Response {
        try await send(makeRequest(path: path, method: "GET"))
    }

    private func post<Response: Decodable>(
        path: String,
        body: [String: String],
        idempotencyKey: String
    ) async throws -> Response {
        var request = try makeRequest(path: path, method: "POST")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw PayoutError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        var request = request
        if let token = await authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PayoutError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PayoutError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PayoutError.requestFailed(statusCode: http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw PayoutError.decodingFailed
        }
    }
}
