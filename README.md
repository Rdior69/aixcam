# aixcam
Aixcam is an iOS SwiftUI prototype for local member onboarding, login, privacy disclosure, and account deletion.

## iOS app

This repository includes an Xcode SwiftUI project for the Aixcam iOS app.

- `Aixcam.xcodeproj` opens the app in Xcode.
- `Aixcam/ContentView.swift` contains the landing, sign-up, login, privacy, and signed-in account screens.
- `Aixcam/AuthViewModel.swift` handles prototype account validation, Keychain-backed local account storage, password verification, logout, and account deletion.
- `Aixcam/CreatorOnboardingView.swift` contains the post-signup creator onboarding placeholder flow.
- `Aixcam/CreatorOnboardingViewModel.swift`, `Aixcam/CreatorProfile.swift`, and `Aixcam/CreatorSetupStep.swift` define the onboarding foundation.
- `Aixcam/FirebaseCreatorProfileService.swift` provides a Firebase-ready creator profile service that compiles without Firebase linked and uses Firestore when `FirebaseFirestore` is available.
- `Aixcam/Assets.xcassets` contains the app icon and in-app icon image.
- `AixcamTests/AuthViewModelTests.swift` covers the local auth behaviors.

Open `Aixcam.xcodeproj` in Xcode, choose an iPhone simulator, then build and run.

Run the shared scheme tests with:

`xcodebuild test -scheme Aixcam -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`

## App icon sizing

The reusable `AixcamIconView` uses SwiftUI's `resizable()` and `scaledToFit()`
modifiers with an explicit square frame so the icon image resizes without being
stretched or cropped.
