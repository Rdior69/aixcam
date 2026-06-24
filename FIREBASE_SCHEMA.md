# AIXLive Creator Backend Schema

## Firestore Collections

### `users/{uid}`
- `id: string`
- `name: string`
- `email: string`
- `accountType: "Creator" | "Fan or member" | "Brand partner"`
- `createdAt: number` (milliseconds since epoch)
- `hasPublishedCreatorProfile: boolean`

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

## Storage Structure

- `creators/{uid}/photo/{assetId}.jpg`
- `creators/{uid}/video/{assetId}.mov`
- `creators/{uid}/banner/{assetId}.jpg`

## Cloud Functions

- `generateCaptionSuggestion` (callable)
  - Input: `{ prompt: string }`
  - Output: `{ caption: string }`
  - Used by onboarding step 5 AI Studio.

## Real-time Flows

- Client listens to `creatorDrafts/{uid}` snapshot updates.
- Any update in profile, branding, content, subscriptions, or AI settings rehydrates the wizard instantly.

