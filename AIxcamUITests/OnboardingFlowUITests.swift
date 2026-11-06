//
//  OnboardingFlowUITests.swift
//  AIxcamUITests
//
//  Exercises the signed-out surface: onboarding, sign in, sign up and password
//  reset. Everything asserted here is client-side — navigation, field state and
//  the local validation in AuthValidation. No test taps a button that would
//  reach Firebase, so the suite never creates an account or sends an email.
//

import XCTest

// MARK: - Shared harness

/// Base class that launches the app in a known signed-out state and provides
/// the element lookups the auth screens share.
class AuthFlowUITestCase: XCTestCase {

    /// Must match `AIxcamApp.signedOutLaunchArgument`.
    private static let signedOutLaunchArgument = "-uitest-signed-out"

    /// Generous because the app configures Firebase and registers the RTMP
    /// session factory before the first screen renders.
    let defaultTimeout: TimeInterval = 15

    private var launchedApp: XCUIApplication?

    /// The running app. Tests call `launchSignedOut()` first; launching from the
    /// test body rather than `setUp` keeps everything on the main actor without
    /// changing the isolation of an inherited XCTestCase override.
    @MainActor
    var app: XCUIApplication {
        guard let launchedApp else {
            fatalError("Call launchSignedOut() before touching the app")
        }
        return launchedApp
    }

    /// Launches the app with the session cleared, so the first screen is always
    /// onboarding regardless of who was signed in on this device.
    @MainActor
    func launchSignedOut() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments.append(Self.signedOutLaunchArgument)
        app.launch()
        launchedApp = app
    }

    // MARK: Elements

    @MainActor var signInEntryPoint: XCUIElement { app.buttons["Sign In"] }
    @MainActor var createAccountEntryPoint: XCUIElement { app.buttons["Create Account"] }
    @MainActor var backButton: XCUIElement { app.buttons["Back"] }
    @MainActor var forgotPasswordLink: XCUIElement { app.buttons["Forgot password?"] }

    @MainActor var emailField: XCUIElement { app.textFields["Email address"] }
    @MainActor var passwordField: XCUIElement { app.secureTextFields["Password"] }
    @MainActor var confirmPasswordField: XCUIElement { app.secureTextFields["Confirm password"] }

    // MARK: Typing helpers

    /// Waits for `element`, taps it, types `value`, then dismisses the keyboard.
    ///
    /// The auth forms are a centred ZStack rather than a scroll view, so a raised
    /// keyboard can leave the next field or the submit button unhittable. Sending
    /// a newline resigns focus and brings the rest of the form back on screen.
    /// Pass `dismissKeyboard: false` on a field whose return key submits the
    /// form — see `dismissKeyboard()`.
    @MainActor
    func fill(_ element: XCUIElement,
              with value: String,
              dismissKeyboard shouldDismissKeyboard: Bool = true,
              file: StaticString = #filePath,
              line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: defaultTimeout),
            "Expected the field to exist before typing into it",
            file: file, line: line
        )
        element.tap()
        dismissStrongPasswordPromptIfPresent()
        element.typeText(value)
        if shouldDismissKeyboard { dismissKeyboard() }
    }

    /// Clears `element` and types `value` in its place.
    ///
    /// Used instead of appending, because tapping an already-populated field puts
    /// the caret wherever the tap landed rather than at the end.
    @MainActor
    func replaceText(in element: XCUIElement,
                     with value: String,
                     dismissKeyboard shouldDismissKeyboard: Bool = true,
                     file: StaticString = #filePath,
                     line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: defaultTimeout),
            "Expected the field to exist before editing it",
            file: file, line: line
        )
        element.tap()
        dismissStrongPasswordPromptIfPresent()

        let existing = (element.value as? String) ?? ""
        if !existing.isEmpty {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                    count: existing.count))
        }

        element.typeText(value)
        if shouldDismissKeyboard { dismissKeyboard() }
    }

    /// Resigns focus by sending a newline.
    ///
    /// Only safe on a field whose return key does nothing but dismiss. On a
    /// field carrying `.submitLabel(.send)` with an `.onSubmit` action — the
    /// reset-password email field — return *is* the submit button, so calling
    /// this fires the real request and swaps the button for a spinner. Those
    /// call sites pass `dismissKeyboard: false`.
    @MainActor
    func dismissKeyboard() {
        if app.keyboards.count > 0 {
            app.typeText("\n")
        }
    }

    /// Dismisses iOS's "Use Strong Password?" AutoFill sheet.
    ///
    /// The sign-up fields declare `.textContentType(.newPassword)`, so focusing
    /// one makes the system offer a generated password. Left up, the sheet
    /// swallows most of the keystrokes that follow and the field ends up holding
    /// a truncated value — which quietly invalidates any assertion about
    /// password length or strength.
    @MainActor
    func dismissStrongPasswordPromptIfPresent() {
        guard app.staticTexts["Use Strong Password?"].waitForExistence(timeout: 2) else { return }

        let close = app.buttons["Close"]
        if close.exists {
            close.tap()
        }
    }

    // MARK: Navigation helpers

    /// Navigates onboarding → Sign In and waits for the screen to settle.
    @MainActor
    func openSignIn(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            signInEntryPoint.waitForExistence(timeout: defaultTimeout),
            "Onboarding never showed its Sign In button",
            file: file, line: line
        )
        signInEntryPoint.tap()
        XCTAssertTrue(
            app.staticTexts["Welcome back"].waitForExistence(timeout: defaultTimeout),
            "Tapping Sign In did not open the sign-in screen",
            file: file, line: line
        )
    }

    /// Navigates onboarding → Create Account and waits for the screen to settle.
    @MainActor
    func openSignUp(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            createAccountEntryPoint.waitForExistence(timeout: defaultTimeout),
            "Onboarding never showed its Create Account button",
            file: file, line: line
        )
        createAccountEntryPoint.tap()
        XCTAssertTrue(
            app.staticTexts["Create account"].waitForExistence(timeout: defaultTimeout),
            "Tapping Create Account did not open the sign-up screen",
            file: file, line: line
        )
    }

    /// Navigates onboarding → Sign In → Forgot password.
    @MainActor
    func openForgotPassword(file: StaticString = #filePath, line: UInt = #line) {
        openSignIn(file: file, line: line)

        XCTAssertTrue(
            forgotPasswordLink.waitForExistence(timeout: defaultTimeout),
            "Sign in is missing the Forgot password? link",
            file: file, line: line
        )
        forgotPasswordLink.tap()

        XCTAssertTrue(
            app.staticTexts["Reset password"].waitForExistence(timeout: defaultTimeout),
            "Forgot password? did not open the reset screen",
            file: file, line: line
        )
    }
}

// MARK: - Onboarding

final class OnboardingUITests: AuthFlowUITestCase {

    @MainActor
    func testOnboardingIsTheSignedOutLandingScreen() {
        launchSignedOut()

        XCTAssertTrue(app.staticTexts["AIxcam"].waitForExistence(timeout: defaultTimeout),
                      "Signed out, the app should land on onboarding")
        XCTAssertTrue(app.staticTexts["Go live in seconds."].exists)
        XCTAssertTrue(signInEntryPoint.exists, "Onboarding is missing its Sign In entry point")
        XCTAssertTrue(createAccountEntryPoint.exists, "Onboarding is missing its Create Account entry point")
    }

    @MainActor
    func testSignInEntryPointOpensSignInScreen() {
        launchSignedOut()
        openSignIn()

        XCTAssertTrue(app.staticTexts["Sign in to your AIxcam account."].exists)
        XCTAssertTrue(emailField.exists)
        XCTAssertTrue(passwordField.exists)
    }

    @MainActor
    func testCreateAccountEntryPointOpensSignUpScreen() {
        launchSignedOut()
        openSignUp()

        XCTAssertTrue(app.staticTexts["Watch live, or go live yourself."].exists)
        XCTAssertTrue(emailField.exists)
        XCTAssertTrue(passwordField.exists)
        XCTAssertTrue(confirmPasswordField.exists,
                      "Sign up should ask for the password twice")
    }

    @MainActor
    func testBackFromSignInReturnsToOnboarding() {
        launchSignedOut()
        openSignIn()

        XCTAssertTrue(backButton.waitForExistence(timeout: defaultTimeout))
        backButton.tap()

        XCTAssertTrue(app.staticTexts["Go live in seconds."].waitForExistence(timeout: defaultTimeout),
                      "Backing out of sign in should return to onboarding")
    }

    @MainActor
    func testBackFromSignUpReturnsToOnboarding() {
        launchSignedOut()
        openSignUp()

        XCTAssertTrue(backButton.waitForExistence(timeout: defaultTimeout))
        backButton.tap()

        XCTAssertTrue(app.staticTexts["Go live in seconds."].waitForExistence(timeout: defaultTimeout),
                      "Backing out of sign up should return to onboarding")
    }
}

// MARK: - Sign in

final class SignInUITests: AuthFlowUITestCase {

    /// The submit button on the sign-in screen, as opposed to the onboarding
    /// entry point that shares its title.
    @MainActor private var submitButton: XCUIElement { app.buttons["Sign In"] }

    @MainActor
    func testSubmitIsDisabledUntilBothFieldsAreFilled() {
        launchSignedOut()
        openSignIn()

        XCTAssertFalse(submitButton.isEnabled,
                       "Sign In should be disabled with both fields empty")

        fill(emailField, with: "viewer@example.com")
        XCTAssertFalse(submitButton.isEnabled,
                       "Sign In should stay disabled with no password")

        fill(passwordField, with: "correct-horse")
        XCTAssertTrue(submitButton.isEnabled,
                      "Sign In should enable once both fields have content")
    }

    /// The sign-in gate is deliberately presence-only. An existing account may
    /// predate the current password rules, so the client must not second-guess it
    /// the way sign up does.
    @MainActor
    func testSubmitEnablesEvenForAWeakLegacyPassword() {
        launchSignedOut()
        openSignIn()

        fill(emailField, with: "viewer@example.com")
        fill(passwordField, with: "abc")

        XCTAssertTrue(submitButton.isEnabled,
                      "Sign in should not apply the sign-up password rules")
    }

    @MainActor
    func testForgotPasswordCarriesOverTheTypedEmail() {
        launchSignedOut()
        openSignIn()

        fill(emailField, with: "viewer@example.com")

        XCTAssertTrue(forgotPasswordLink.waitForExistence(timeout: defaultTimeout))
        forgotPasswordLink.tap()

        XCTAssertTrue(app.staticTexts["Reset password"].waitForExistence(timeout: defaultTimeout),
                      "Forgot password? should open the reset screen")
        XCTAssertEqual(emailField.value as? String, "viewer@example.com",
                       "The reset screen should prefill the address already typed")
    }
}

// MARK: - Sign up validation

final class SignUpValidationUITests: AuthFlowUITestCase {

    @MainActor private var submitButton: XCUIElement { app.buttons["Create Account"] }

    private let malformedEmailHint = "That doesn't look like a valid email address."

    @MainActor
    func testSubmitIsDisabledOnAnEmptyForm() {
        launchSignedOut()
        openSignUp()

        XCTAssertFalse(submitButton.isEnabled,
                       "Create Account should be disabled before anything is typed")
    }

    @MainActor
    func testMalformedEmailShowsHintAndBlocksSubmit() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "not-an-email")

        XCTAssertTrue(
            app.staticTexts[malformedEmailHint].waitForExistence(timeout: defaultTimeout),
            "A malformed address should be called out before the round trip"
        )

        fill(passwordField, with: "Str0ng-Passw0rd")
        fill(confirmPasswordField, with: "Str0ng-Passw0rd")

        XCTAssertFalse(submitButton.isEnabled,
                       "A malformed address must keep Create Account disabled")
    }

    @MainActor
    func testHintClearsOnceTheAddressParses() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "not-an-email")

        let hint = app.staticTexts[malformedEmailHint]
        XCTAssertTrue(hint.waitForExistence(timeout: defaultTimeout))

        replaceText(in: emailField, with: "viewer@example.com")

        XCTAssertFalse(hint.exists, "The hint should clear once the address parses")
    }

    @MainActor
    func testMismatchedPasswordsShowHintAndBlockSubmit() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "viewer@example.com")
        fill(passwordField, with: "Str0ng-Passw0rd")
        fill(confirmPasswordField, with: "Str0ng-Passw0rdd")

        XCTAssertTrue(
            app.staticTexts["Passwords don't match."].waitForExistence(timeout: defaultTimeout),
            "A confirmation mismatch should be shown inline"
        )
        XCTAssertFalse(submitButton.isEnabled,
                       "Mismatched passwords must keep Create Account disabled")
    }

    /// Anything under `AuthValidation.minimumPasswordLength` is rejected outright,
    /// and the meter says how long it needs to be rather than waiting for Firebase.
    @MainActor
    func testShortPasswordIsReportedAsTooShortAndBlocksSubmit() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "viewer@example.com")
        fill(passwordField, with: "abc123")

        XCTAssertTrue(
            app.staticTexts["At least 8 characters."].waitForExistence(timeout: defaultTimeout),
            "A short password should say how long it needs to be"
        )

        fill(confirmPasswordField, with: "abc123")
        XCTAssertFalse(submitButton.isEnabled,
                       "A password under the length floor must block submission")
    }

    /// Strength is advisory: a "weak" password past the length floor is still
    /// submittable, and the meter should say so rather than block.
    @MainActor
    func testWeakButLongPasswordIsAcceptedWithAWeakRating() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "viewer@example.com")
        fill(passwordField, with: "aaaaaaaaa")

        XCTAssertTrue(app.staticTexts["Password strength: Weak"].waitForExistence(timeout: defaultTimeout),
                      "Nine lowercase characters should rate as weak")

        fill(confirmPasswordField, with: "aaaaaaaaa")
        XCTAssertTrue(submitButton.isEnabled,
                      "Weak is advisory — it should not block submission")
    }

    @MainActor
    func testStrongPasswordIsRatedStrongAndEnablesSubmit() {
        launchSignedOut()
        openSignUp()

        fill(emailField, with: "viewer@example.com")
        fill(passwordField, with: "Str0ng-Passw0rd")

        XCTAssertTrue(app.staticTexts["Password strength: Strong"].waitForExistence(timeout: defaultTimeout),
                      "A long mixed-class password should rate as strong")

        fill(confirmPasswordField, with: "Str0ng-Passw0rd")

        // Deliberately not tapped: submitting would create a real Firebase account.
        XCTAssertTrue(submitButton.isEnabled,
                      "A valid, matching, strong password should enable Create Account")
    }
}

// MARK: - Password reset

final class ForgotPasswordUITests: AuthFlowUITestCase {

    @MainActor private var sendButton: XCUIElement { app.buttons["Send Reset Link"] }

    @MainActor
    func testSendIsGatedOnAWellFormedAddress() {
        launchSignedOut()
        openForgotPassword()

        XCTAssertFalse(sendButton.isEnabled,
                       "Send Reset Link should be disabled with no address")

        // The keyboard stays up throughout: this field's return key is wired to
        // `.onSubmit { send() }`, so dismissing with a newline would send a real
        // reset email and replace the button with a spinner. Nothing here is
        // tapped, and `isEnabled` does not require the button to be unobscured.
        fill(emailField, with: "not-an-email", dismissKeyboard: false)
        XCTAssertFalse(sendButton.isEnabled,
                       "Send Reset Link should stay disabled for a malformed address")

        replaceText(in: emailField, with: "viewer@example.com", dismissKeyboard: false)
        XCTAssertTrue(sendButton.isEnabled,
                      "Send Reset Link should enable once the address parses")
    }

    @MainActor
    func testBackReturnsToSignIn() {
        launchSignedOut()
        openForgotPassword()

        XCTAssertTrue(backButton.waitForExistence(timeout: defaultTimeout))
        backButton.tap()

        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: defaultTimeout),
                      "Backing out of the reset screen should return to sign in")
    }
}
