# aixcam
Aixcam is a next-generation creator platform that combines livestreaming, fan engagement, subscriptions, virtual gifting, AI-powered experiences, and premium monetization tools to help creators build thriving digital businesses

## iOS app

This repository includes an Xcode SwiftUI project for the Aixcam iOS app.

- `Aixcam.xcodeproj` opens the app in Xcode.
- `Aixcam/ContentView.swift` contains the landing, sign-up, login, creator setup wizard, fan page preview, and dashboard screens.
- `Aixcam/AuthViewModel.swift` handles prototype account validation, session state, creator onboarding models, and the Firebase-ready creator backend protocol.
- `Aixcam/Assets.xcassets` contains the app icon and in-app icon image.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`, and `docs/firebase-creator-schema.md` define the intended Firebase backend contract.

Open `Aixcam.xcodeproj` in Xcode, choose an iPhone simulator, then build and run.

## Creator onboarding

After account creation or login, creators automatically enter a seven-step setup wizard:

1. Profile information
2. Creator branding
3. Content creation
4. Fan subscriptions
5. AI Studio
6. Creator dashboard
7. Publish

The app currently uses `LocalCreatorBackendService` to persist drafts locally until Firebase iOS SDK setup and `GoogleService-Info.plist` are available in Xcode.

## App icon sizing

The reusable `AixcamIconView` uses SwiftUI's `resizable()` and `scaledToFit()`
modifiers with an explicit square frame so the icon image resizes without being
stretched or cropped.
