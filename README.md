# aixcam
Aixcam is a next-generation creator platform that combines livestreaming, fan engagement, subscriptions, virtual gifting, AI-powered experiences, and premium monetization tools to help creators build thriving digital businesses

## iOS app

This repository includes an Xcode SwiftUI project for the AIXLive iOS app.

- `Aixcam.xcodeproj` opens the app in Xcode.
- `Aixcam/ContentView.swift` handles auth routing, post-login onboarding entry, and dashboard root states.
- `Aixcam/AuthViewModel.swift` manages session state and authentication.
- `Aixcam/CreatorModels.swift` defines onboarding models for profile, branding, media, subscriptions, AI studio, and analytics.
- `Aixcam/CreatorBackendService.swift` provides Firebase-ready and local fallback data services.
- `Aixcam/CreatorSetupViewModel.swift` handles onboarding wizard state and real-time persistence.
- `Aixcam/CreatorOnboardingViews.swift` includes the full 7-step creator setup wizard and dashboard views.
- `firestore.rules`, `storage.rules`, and `firestore.indexes.json` define backend security and query indexes.
- `FIREBASE_SCHEMA.md` documents database and storage structure.
- `Aixcam/Assets.xcassets` contains the app icon and in-app icon image.

Open `Aixcam.xcodeproj` in Xcode, choose an iPhone simulator, then build and run.

## App icon sizing

The reusable `AixcamIconView` uses SwiftUI's `resizable()` and `scaledToFit()`
modifiers with an explicit square frame so the icon image resizes without being
stretched or cropped.
