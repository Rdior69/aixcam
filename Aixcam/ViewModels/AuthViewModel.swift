import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var members: [Member] = []
    @Published private(set) var currentMember: Member?
    @Published var status: AuthStatus = .idle

    private let storageKey = "aixcam.members"
    private let sessionKey = "aixcam.currentMemberId"

    var isAuthenticated: Bool { currentMember != nil }

    var needsCreatorSetup: Bool {
        guard let member = currentMember else { return false }
        return member.accountType == .creator && !member.onboardingComplete
    }

    init() {
        loadMembers()
        restoreSession()
    }

    func signUp(name: String, email: String, accountType: AccountType, password: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = normalize(email)

        guard validate(name: cleanedName, email: cleanedEmail, password: password) else { return }

        guard !members.contains(where: { $0.email == cleanedEmail }) else {
            status = .error("That email is already signed up. Please log in instead.")
            return
        }

        let member = Member(name: cleanedName, email: cleanedEmail, accountType: accountType)
        members.append(member)
        saveMembers()
        establishSession(with: member)

        if accountType == .creator {
            status = .success("Welcome to Aixcam! Let's set up your creator profile.")
        } else {
            status = .success("Your Aixcam account was created successfully.")
        }
    }

    func login(email: String, password: String) {
        let cleanedEmail = normalize(email)
        guard validate(email: cleanedEmail, password: password) else { return }

        guard let member = members.first(where: { $0.email == cleanedEmail }) else {
            status = .error("We could not find that account. Create a new account to join Aixcam.")
            return
        }

        establishSession(with: member)

        if member.accountType == .creator && !member.onboardingComplete {
            status = .success("Welcome back! Continue setting up your creator profile.")
        } else {
            status = .success("Welcome back, \(member.name)!")
        }
    }

    func logout() {
        currentMember = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        status = .idle
    }

    func completeOnboarding() {
        guard var member = currentMember else { return }
        member.onboardingComplete = true
        member.currentSetupStep = CreatorSetupStep.publish.rawValue
        updateMember(member)
        status = .success("Your creator profile is live!")
    }

    func updateSetupStep(_ step: Int) {
        guard var member = currentMember else { return }
        member.currentSetupStep = step
        updateMember(member)
    }

    func resetStatus() {
        status = .idle
    }

    private func establishSession(with member: Member) {
        currentMember = member
        UserDefaults.standard.set(member.id.uuidString, forKey: sessionKey)
    }

    private func updateMember(_ member: Member) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index] = member
            saveMembers()
            currentMember = member
            UserDefaults.standard.set(member.id.uuidString, forKey: sessionKey)
        }
    }

    private func restoreSession() {
        guard let idString = UserDefaults.standard.string(forKey: sessionKey),
              let id = UUID(uuidString: idString),
              let member = members.first(where: { $0.id == id }) else { return }
        currentMember = member
    }

    private func validate(name: String, email: String, password: String) -> Bool {
        guard !name.isEmpty else {
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
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        members = (try? JSONDecoder().decode([Member].self, from: data)) ?? []
    }

    private func saveMembers() {
        do {
            let data = try JSONEncoder().encode(members)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            status = .error("We could not save your account. Please try again.")
        }
    }
}
