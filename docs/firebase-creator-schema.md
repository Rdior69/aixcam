# Firebase creator onboarding schema

This document mirrors the Swift models in `Aixcam/AuthViewModel.swift` and the setup flow in `Aixcam/ContentView.swift`.

## Authentication

- Firebase Authentication user id is the canonical `uid`.
- App account metadata lives in `users/{uid}`.
- Creator profile ownership always compares `request.auth.uid` with the document id.

## Firestore collections

| Path | Purpose | Client access |
| --- | --- | --- |
| `users/{uid}` | Account profile, email, role, timestamps | Owner read/write |
| `creatorProfiles/{uid}` | Public creator profile, branding, links, publish state | Owner write, public read after publish |
| `creatorProfiles/{uid}/media/{mediaId}` | Photos, videos, albums, categories, sort order | Owner write, public read after publish |
| `creatorProfiles/{uid}/subscriptionTiers/{tierId}` | Free, Premium, VIP tier metadata and benefits | Owner write, public read after publish |
| `creatorProfiles/{uid}/analytics/{range}` | Revenue, subscribers, views, engagement, content reports | Owner read, server write |
| `creatorProfiles/{uid}/aiJobs/{jobId}` | AI editor, caption, thumbnail, upscaling, and batch jobs | Owner create/read, server update |
| `cloudFunctionRequests/{requestId}` | Queue for Cloud Functions backed AI operations | Owner create/read, server update |

## Storage layout

| Path | Purpose |
| --- | --- |
| `creators/{uid}/profile/` | Profile photos |
| `creators/{uid}/covers/` | Cover/banner images |
| `creators/{uid}/media/photos/` | Published and draft photo uploads |
| `creators/{uid}/media/videos/` | Published and draft video uploads |
| `creators/{uid}/albums/{albumId}/` | Album assets |
| `creators/{uid}/ai-output/` | Server-generated AI outputs |

## Cloud Functions hooks

- `onCreatorProfilePublished`: materialize public fan page metadata.
- `onMediaUploaded`: generate thumbnails, duration metadata, moderation state, and blur hashes.
- `onAIJobCreated`: run background removal, enhancement, filters, captions, thumbnails, upscaling, or batch edits.
- `onAnalyticsRollup`: write dashboard revenue, subscribers, views, engagement, earnings, and content performance.

## Current app implementation

- The SwiftUI app uses `CreatorBackendServicing` as a Firebase-ready boundary.
- `LocalCreatorBackendService` persists draft and published profile data through `UserDefaults` so the flow is usable before the Firebase iOS SDK and `GoogleService-Info.plist` are installed.
- Replace `LocalCreatorBackendService` with a Firebase implementation that writes the paths above when the project has authenticated Firebase CLI/Xcode access.
