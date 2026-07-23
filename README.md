# Aixcam

Aixcam is a creator platform prototype that combines livestreaming, fan engagement, subscriptions, AI-assisted workflows, and monetization tools.

## Current status

This repository contains an **iOS SwiftUI prototype**. The default backend is **local** (Keychain-backed accounts + on-device drafts). Firebase Auth activates only when the Firebase iOS SDK is linked **and** a real `GoogleService-Info.plist` is in the app bundle (never commit the real plist). See `Docs/FIREBASE_AUTH.md`.

What works now:

- Launch screen + centralized session routing (`SessionManager`)
- Sign up / login (local by default; Firebase when activated)
- Safe Firebase bootstrap (skips `configure()` when plist is missing)
- Creator vs subscriber-role routing (fan/brand map to subscriber shell)
- Full 7-step creator onboarding wizard with local persistence
- Creator Home after setup, with growth snapshot and studio summary
- Live camera studio (preview, go live / end, mute, flip) from Creator Home
- Publish flow that generates an `https://aixcam.app/creator/{slug}` preview URL
- Suspended/restricted account status screen

What is not wired yet:

- Live Firebase without adding SDK + plist locally (optional activate path is ready)
- Real fan delivery / CDN livestream ingest (current live mode is on-device studio + simulated viewers)
- Real AI caption generation (local string template only)

## iOS app

- Open `Aixcam.xcodeproj` in Xcode 15.3+ (iOS 17+).
- Shared scheme: **Aixcam** (includes unit tests).
- Key sources live under `Aixcam/`.
- Unit tests live under `AixcamTests/`.

| File | Role |
|------|------|
| `Aixcam/RootView.swift` | App root switch driven by `SessionManager` |
| `Aixcam/SessionManager.swift` / `SessionRouter.swift` | Launch bootstrap + pure route mapping |
| `Aixcam/ContentView.swift` | Welcome/auth + creator authenticated root |
| `Aixcam/AuthViewModel.swift` | Session state; revalidates on launch |
| `Aixcam/CreatorModels.swift` | Onboarding models |
| `Aixcam/FirebaseBootstrap.swift` | Safe Firebase configure + auth error mapping |
| `Aixcam/CreatorBackendService.swift` | Local + Firebase-ready backend |
| `Aixcam/SecureCredentialStore.swift` | Keychain storage for local credentials |
| `Aixcam/CreatorSetupViewModel.swift` | Wizard state + persistence |
| `Aixcam/CreatorOnboardingViews.swift` | 7-step setup UI |
| `Docs/ARCHITECTURE.md` | Phase plan + routing table |
| `Docs/FIREBASE_AUTH.md` | How to activate Firebase Auth |

## Backend docs

- `FIREBASE_SCHEMA.md` — intended Firestore/Storage shape
- `Docs/FIREBASE_AUTH.md` — Firebase Auth activate checklist
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- `firebase.json` + `functions/` — deployable Cloud Function stub
- `.GoogleService-Info.plist.example` — template only; copy to `GoogleService-Info.plist` locally

## Git hygiene

`.gitignore` excludes DerivedData, `xcuserdata`, Node modules, and Firebase secrets such as `GoogleService-Info.plist`.

## App icon

`AixcamIconView` uses `resizable()` + `scaledToFit()` with an explicit square frame so the icon scales without stretch or crop.
