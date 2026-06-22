# aixcam
Aixcam is a next-generation creator platform that combines livestreaming, fan engagement, subscriptions, virtual gifting, AI-powered experiences, and premium monetization tools to help creators build thriving digital businesses

## iOS app

This repository includes an Xcode SwiftUI project for the Aixcam iOS app.

- `Aixcam.xcodeproj` opens the app in Xcode.
- `Aixcam/ContentView.swift` contains the landing, sign-up, and login screens.
- `Aixcam/AuthViewModel.swift` handles prototype account validation and local member storage.
- `Aixcam/Assets.xcassets` contains the app icon and in-app icon image.

Open `Aixcam.xcodeproj` in Xcode, choose an iPhone simulator, then build and run.

## App icon sizing

The reusable `AixcamIconView` uses SwiftUI's `resizable()` and `scaledToFit()`
modifiers with an explicit square frame so the icon image resizes without being
stretched or cropped.
