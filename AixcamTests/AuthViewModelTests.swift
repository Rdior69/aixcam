import XCTest
@testable import Aixcam

final class AuthViewModelTests: XCTestCase {
    func testSignUpStoresMemberAndStartsSession() {
        let viewModel = AuthViewModel(memberStore: MemoryMemberStore())

        let didSignUp = viewModel.signUp(
            name: "Taylor Creator",
            email: "Taylor@Example.com",
            accountType: .creator,
            password: "correct-password"
        )

        XCTAssertTrue(didSignUp)
        XCTAssertEqual(viewModel.members.count, 1)
        XCTAssertEqual(viewModel.members.first?.email, "taylor@example.com")
        XCTAssertEqual(viewModel.currentMember?.name, "Taylor Creator")
        XCTAssertTrue(viewModel.isAuthenticated)
    }

    func testLoginRequiresMatchingPassword() {
        let viewModel = AuthViewModel(memberStore: MemoryMemberStore())
        XCTAssertTrue(viewModel.signUp(
            name: "Jordan Fan",
            email: "jordan@example.com",
            accountType: .fan,
            password: "correct-password"
        ))
        viewModel.logout()

        XCTAssertFalse(viewModel.login(email: "jordan@example.com", password: "wrong-password"))
        XCTAssertNil(viewModel.currentMember)

        XCTAssertTrue(viewModel.login(email: "jordan@example.com", password: "correct-password"))
        XCTAssertEqual(viewModel.currentMember?.email, "jordan@example.com")
    }

    func testInvalidEmailIsRejected() {
        let viewModel = AuthViewModel(memberStore: MemoryMemberStore())

        XCTAssertFalse(viewModel.signUp(
            name: "Invalid Email",
            email: "@.",
            accountType: .brand,
            password: "correct-password"
        ))
        XCTAssertTrue(viewModel.members.isEmpty)
    }

    func testDeleteCurrentAccountRemovesStoredMember() {
        let store = MemoryMemberStore()
        let viewModel = AuthViewModel(memberStore: store)
        XCTAssertTrue(viewModel.signUp(
            name: "Delete Me",
            email: "delete@example.com",
            accountType: .creator,
            password: "correct-password"
        ))

        XCTAssertTrue(viewModel.deleteCurrentAccount())

        XCTAssertTrue(viewModel.members.isEmpty)
        XCTAssertNil(viewModel.currentMember)
        XCTAssertTrue(store.dataByKey.isEmpty)
    }
}

private final class MemoryMemberStore: SecureMemberStoring {
    var dataByKey: [String: Data] = [:]

    func loadData(for key: String) -> Data? {
        dataByKey[key]
    }

    func saveData(_ data: Data, for key: String) throws {
        dataByKey[key] = data
    }

    func deleteData(for key: String) throws {
        dataByKey.removeValue(forKey: key)
    }
}
