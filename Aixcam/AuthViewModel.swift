import Combine
import Foundation

struct Member: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String
    let accountType: AccountType
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        accountType: AccountType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accountType = accountType
        self.createdAt = createdAt
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }
}

enum AuthStatus: Equatable {
    case idle
    case success(String)
    case error(String)
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var members: [Member] = []
    @Published var status: AuthStatus = .idle

    private let storageKey = "aixcam.members"

    init() {
        loadMembers()
    }

    func signUp(name: String, email: String, accountType: AccountType, password: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = normalize(email)

        guard validate(name: cleanedName, email: cleanedEmail, password: password) else {
            return
        }

        guard members.contains(where: { $0.email == cleanedEmail }) == false else {
            status = .error("That email is already signed up. Please log in instead.")
            return
        }

        members.append(Member(name: cleanedName, email: cleanedEmail, accountType: accountType))
        saveMembers()
        status = .success("Your Aixcam account was created. You can now log in as a member.")
    }

    func login(email: String, password: String) {
        let cleanedEmail = normalize(email)

        guard validate(email: cleanedEmail, password: password) else {
            return
        }

        guard let member = members.first(where: { $0.email == cleanedEmail }) else {
            status = .error("We could not find that member email. Create a new account to join Aixcam.")
            return
        }

        status = .success("Welcome back, \(member.name). Your Aixcam member account is ready.")
    }

    func resetStatus() {
        status = .idle
    }

    private func validate(name: String, email: String, password: String) -> Bool {
        guard name.isEmpty == false else {
            status = .error("Enter your full name to create an account.")
            return false
        }

        return validate(email: email, password: password)
    }

    private func validate(email: String, password: String) -> Bool {
        guard email.contains("@"), email.contains(".") else {
            status = .error("Enter a valid email address.")
            return false
        }

        guard password.count >= 8 else {
            status = .error("Use a password with at least 8 characters.")
            return false
        }

        return true
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func loadMembers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            members = try JSONDecoder().decode([Member].self, from: data)
        } catch {
            members = []
        }
    }

    private func saveMembers() {
        do {
            let data = try JSONEncoder().encode(members)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            status = .error("We could not save the new member account. Please try again.")
        }
    }
}
