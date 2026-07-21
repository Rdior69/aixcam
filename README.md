# Aixcam

Aixcam is a creator platform prototype that combines livestreaming, fan engagement, subscriptions, AI-assisted workflows, and monetization tools.

## Current status

This repository contains an **iOS SwiftUI prototype**. Today the app runs with a **local backend** (Keychain-backed accounts + on-device drafts). Firebase-shaped service code is present and will activate only after you add the Firebase iOS SDK and a `GoogleService-Info.plist` (never commit the real plist).

What works now:

- Sign up / login (local prototype auth)
- Creator vs fan/brand routing
- Full 7-step creator onboarding wizard with local persistence
- Creator Home after setup, with growth snapshot and studio summary
- Live camera studio (preview, go live / end, mute, flip) from Creator Home
- Publish flow that generates an `https://aixcam.app/creator/{slug}` preview URL

What is not wired yet:

- Live Firebase Auth / Firestore / Storage
- Real fan delivery / CDN livestream ingest (current live mode is on-device studio + simulated viewers)
- Real AI caption generation (local string template only)

## iOS app

- Open `Aixcam.xcodeproj` in Xcode 15.3+ (iOS 17+).
- Shared scheme: **Aixcam** (includes unit tests).
- Key sources live under `Aixcam/`.
- Unit tests live under `AixcamTests/`.

| File | Role |
|------|------|
| `Aixcam/ContentView.swift` | Auth routing and post-login roots |
| `Aixcam/AuthViewModel.swift` | Session state; revalidates on launch |
| `Aixcam/CreatorModels.swift` | Onboarding models |
| `Aixcam/CreatorBackendService.swift` | Local + Firebase-ready backend |
| `Aixcam/SecureCredentialStore.swift` | Keychain storage for local credentials |
| `Aixcam/CreatorSetupViewModel.swift` | Wizard state + persistence |
| `Aixcam/CreatorOnboardingViews.swift` | 7-step setup UI |

## Backend docs

- `FIREBASE_SCHEMA.md` — intended Firestore/Storage shape
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- `firebase.json` + `functions/` — deployable Cloud Function stub
- `.GoogleService-Info.plist.example` — template only; copy to `GoogleService-Info.plist` locally

## Git hygiene

`.gitignore` excludes DerivedData, `xcuserdata`, Node modules, and Firebase secrets such as `GoogleService-Info.plist`.

## App icon

`AixcamIconView` uses `resizable()` + `scaledToFit()` with an explicit square frame so the icon scales without stretch or crop.
