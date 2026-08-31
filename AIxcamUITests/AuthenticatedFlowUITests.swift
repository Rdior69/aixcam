//
//  AuthenticatedFlowUITests.swift
//  AIxcamUITests
//
//  Signs in as a dedicated test account and exercises the surface behind auth:
//  the main tabs, profile, and sign out.
//
//  These tests hit the real Firebase project, so they need credentials. Supply
//  them either as UITEST_EMAIL / UITEST_PASSWORD environment variables, or in a
//  gitignored TestCredentials.plist bundled into this target — see
//  TestCredentials.plist.template for the full setup. Without credentials every
//  test here skips, so the suite stays green on a fresh checkout.
//

import XCTest

// MARK: - Credentials

enum UITestAccount {

    struct Credentials {
        let email: String
        let password: String
    }

    static let emailKey = "UITEST_EMAIL"
    static let passwordKey = "UITEST_PASSWORD"

    /// Environment first so CI can inject without touching a tracked file, then
    /// the gitignored plist for local runs.
    static func load(from bundle: Bundle) -> Credentials? {
        if let fromEnvironment = loadFromEnvironment() { return fromEnvironment }
        return loadFromPlist(in: bundle)
    }

    private static func loadFromEnvironment() -> Credentials? {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment[emailKey]?.trimmed, !email.isEmpty,
              let password = environment[passwordKey], !password.isEmpty else { return nil }
        return Credentials(email: email, password: password)
    }

    private static func loadFromPlist(in bundle: Bundle) -> Credentials? {
        guard let url = bundle.url(forResource: "TestCredentials", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization
                  .propertyList(from: data, format: nil) as? [String: Any],
              let email = (plist["email"] as? String)?.trimmed,
              let password = plist["password"] as? String,
              !email.isEmpty, !password.isEmpty,
              // Guard against someone copying the template without editing it.
              !email.hasPrefix("REPLACE_ME"), !password.hasPrefix("REPLACE_ME")
        else { return nil }

        return Credentials(email: email, password: password)
    }

    static let missingCredentialsMessage = """
        No UI test account configured. Set \(emailKey)/\(passwordKey), or add a \
        TestCredentials.plist to the AIxcamUITests bundle. See \
        TestCredentials.plist.template.
        """
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Harness

/// Adds sign-in on top of the signed-out harness.
class AuthenticatedUITestCase: AuthFlowUITestCase {

    /// Sign in reaches Firebase, so it needs longer than a local screen transition.
    private let signInTimeout: TimeInterval = 45

    private enum PostSignInScreen {
        case mainTabs
        case profileSetup
        case stillOnSignIn
    }

    /// Throws `XCTSkip` when no account is configured.
    @MainActor
    func requireCredentials() throws -> UITestAccount.Credentials {
        let bundle = Bundle(for: type(of: self))
        guard let credentials = UITestAccount.load(from: bundle) else {
            throw XCTSkip(UITestAccount.missingCredentialsMessage)
        }
        return credentials
    }

    /// Launches signed out, signs in through the real form, and waits for the
    /// main tabs. Doubles as end-to-end coverage of the sign-in path.
    @MainActor
    @discardableResult
    func signInWithTestAccount(file: StaticString = #filePath,
                               line: UInt = #line) throws -> UITestAccount.Credentials {
        let credentials = try requireCredentials()

        launchSignedOut()
        openSignIn(file: file, line: line)

        fill(emailField, with: credentials.email, file: file, line: line)
        fill(passwordField, with: credentials.password, file: file, line: line)

        let submit = app.buttons["Sign In"]
        XCTAssertTrue(submit.isEnabled, "Sign In stayed disabled with both fields filled",
                      file: file, line: line)
        submit.tap()

        switch waitForPostSignInScreen() {
        case .mainTabs:
            break

        case .profileSetup:
            XCTFail("""
                Signed in, but the account landed in profile setup. ContentView gates \
                the main tabs on ViewerProfile.isComplete — give the test account a \
                display name and an 18+ birthdate. See TestCredentials.plist.template.
                """, file: file, line: line)

        case .stillOnSignIn:
            XCTFail("""
                Sign in never completed. Check the credentials are correct and that \
                the account is enabled in Firebase Console → Authentication.
                """, file: file, line: line)
        }

        return credentials
    }

    /// Polls for whichever screen sign-in resolves to, rather than waiting out the
    /// full timeout on the failure paths.
    @MainActor
    private func waitForPostSignInScreen() -> PostSignInScreen {
        let deadline = Date().addingTimeInterval(signInTimeout)

        while Date() < deadline {
            if app.staticTexts["Ready to go live?"].exists { return .mainTabs }
            // Header of ViewerProfileEditView, shown when the profile is incomplete.
            if app.staticTexts["About you"].exists { return .profileSetup }
            Thread.sleep(forTimeInterval: 0.5)
        }

        return .stillOnSignIn
    }

    // MARK: Tabs

    /// Tab items are reachable through the tab bar, but fall back to a plain
    /// button lookup so this keeps working if the bar's representation changes.
    @MainActor
    func tabButton(_ title: String) -> XCUIElement {
        let inTabBar = app.tabBars.buttons[title]
        return inTabBar.exists ? inTabBar : app.buttons[title]
    }

    @MainActor
    func selectTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabButton(title)
        XCTAssertTrue(tab.waitForExistence(timeout: defaultTimeout),
                      "No \(title) tab found", file: file, line: line)
        tab.tap()
    }
}

// MARK: - Tests

final class AuthenticatedFlowUITests: AuthenticatedUITestCase {

    @MainActor
    func testSignInReachesTheMainTabs() throws {
        try signInWithTestAccount()

        XCTAssertTrue(app.staticTexts["Ready to go live?"].exists,
                      "Home should greet the signed-in creator")
        XCTAssertTrue(app.staticTexts["Start Live Stream"].exists,
                      "Home should offer the go-live entry point")

        for tab in ["Home", "Discover", "Profile"] {
            XCTAssertTrue(tabButton(tab).exists, "Missing the \(tab) tab")
        }
    }

    @MainActor
    func testHomeShowsThePastStreamsSection() throws {
        try signInWithTestAccount()

        XCTAssertTrue(app.staticTexts["Past Streams"].waitForExistence(timeout: defaultTimeout),
                      "Home should show the stream history section")
    }

    @MainActor
    func testDiscoverTabShowsItsEmptyState() throws {
        try signInWithTestAccount()

        selectTab("Discover")

        // There is no public stream index yet, so the empty state is the
        // expected content rather than a failure mode.
        XCTAssertTrue(
            app.staticTexts["No live streams right now"].waitForExistence(timeout: defaultTimeout),
            "Discover should show its empty state"
        )
    }

    @MainActor
    func testProfileTabShowsTheSignedInAccount() throws {
        let credentials = try signInWithTestAccount()

        selectTab("Profile")

        XCTAssertTrue(app.staticTexts[credentials.email].waitForExistence(timeout: defaultTimeout),
                      "Profile should show the signed-in account's email")
        XCTAssertTrue(app.staticTexts["Your Profile"].exists)
        XCTAssertTrue(app.staticTexts["ID Verification"].exists)
        XCTAssertTrue(app.buttons["Sign Out"].exists)
    }

    /// ID verification gates live broadcasting, so an unverified account must be
    /// told so rather than being left to discover it at go-live time.
    @MainActor
    func testUnverifiedAccountSeesTheIDVerificationPrompt() throws {
        try signInWithTestAccount()

        selectTab("Profile")

        XCTAssertTrue(
            app.staticTexts["ID Verification"].waitForExistence(timeout: defaultTimeout),
            "Profile should surface ID verification"
        )
        XCTAssertTrue(app.staticTexts["Required for live broadcasting"].exists,
                      "An unverified test account should be prompted to verify")
    }

    @MainActor
    func testSignOutReturnsToOnboarding() throws {
        try signInWithTestAccount()

        selectTab("Profile")

        let signOut = app.buttons["Sign Out"]
        XCTAssertTrue(signOut.waitForExistence(timeout: defaultTimeout))
        signOut.tap()

        XCTAssertTrue(app.staticTexts["Go live in seconds."].waitForExistence(timeout: defaultTimeout),
                      "Signing out should return to onboarding")
    }
}
