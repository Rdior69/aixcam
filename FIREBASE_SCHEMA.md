# Aixcam Creator Backend Schema

## Firestore Collections

### `users/{uid}`
- `id: string`
- `name: string`
- `email: string`
- `accountType: "Creator" | "Fan or member" | "Brand partner"`
- `createdAt: number` (milliseconds since epoch)
- `hasPublishedCreatorProfile: boolean`
- `accountStatus: "active" | "suspended" | "restricted"` (default `active`)
- `hasCompletedSubscriberOnboarding: boolean` (default `false`)

### `creatorDrafts/{uid}`
- `profile: map`
  - `profilePhotoURL: string`
  - `bannerPhotoURL: string`
  - `displayName: string`
  - `username: string`
  - `aboutMe: string`
  - `location: string`
  - `websites: string[]`
  - `socialLinks: map[]`
- `branding: map`
  - `themeColorHex: string`
  - `profileStyle: string`
  - `customProfilePath: string`
  - `enableGlassmorphism: boolean`
- `content: map`
  - `mediaItems: map[]`
  - `albums: map[]`
  - `categories: string[]`
- `subscriptions: map`
- `aiStudio: map`
- `dashboard: map`
- `publishedProfileURL: string | null`
- `lastUpdatedAt: number` (milliseconds since epoch)
- `currentStepRawValue: number` (wizard resume index)

### `subscriberDrafts/{uid}`
- `displayName: string`
- `bio: string`
- `interests: string[]`
- `notifyNewDrops: boolean`
- `notifyLiveSessions: boolean`
- `currentStepRawValue: number`
- `lastUpdatedAt: number` (milliseconds since epoch)

## Authentication

- Provider: Firebase Auth **Email/Password** when Firebase is active
- Local fallback: Keychain members via `LocalCreatorBackendService`
- Activate steps: `Docs/FIREBASE_AUTH.md`
- Auth errors map through `FirebaseAuthErrorMapper` → `CreatorBackendError`

## Storage Structure

- `creators/{uid}/photo/{assetId}.jpg`
- `creators/{uid}/video/{assetId}.mov`
- `creators/{uid}/banner/{assetId}.jpg`

## Cloud Functions

- `generateCaptionSuggestion` (callable)
  - Input: `{ prompt: string }`
  - Output: `{ caption: string }`
  - Used by onboarding step 5 AI Studio.
  - Source: `functions/index.js`

## Public profile URLs

Published creator pages use `https://aixcam.app/creator/{slug}`.

## Real-time Flows

- Client listens to `creatorDrafts/{uid}` snapshot updates.
- Any update in profile, branding, content, subscriptions, or AI settings rehydrates the wizard instantly.

## Runtime note

`FirebaseBootstrap` only calls `FirebaseApp.configure()` when `GoogleService-Info.plist` is in the app bundle. Until Firebase packages are linked **and** that plist is present, the iOS app uses `LocalCreatorBackendService`. See `Docs/FIREBASE_AUTH.md`.
