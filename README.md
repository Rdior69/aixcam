# aixcam
Aixcam is a next-generation creator platform that combines livestreaming, fan engagement, subscriptions, virtual gifting, AI-powered experiences, and premium monetization tools to help creators build thriving digital businesses.

## iOS app

This repository includes an Xcode SwiftUI project for the Aixcam iOS app with a complete 7-step Creator Setup Wizard.

### Project structure

```
Aixcam/
├── AixcamApp.swift              # App entry, Firebase init
├── ContentView.swift            # Root view wrapper
├── Models/                      # Data models (profile, content, subscriptions)
├── ViewModels/                  # AuthViewModel, CreatorSetupViewModel
├── Services/                    # Firebase-ready repositories + local persistence
├── Theme/                       # Design tokens, glassmorphism components
└── Views/
    ├── Auth/                    # Landing, sign-up, login
    ├── CreatorSetup/            # 7-step onboarding wizard
    └── Dashboard/               # Post-publish creator dashboard
```

### Creator Setup Wizard (7 steps)

After sign-up or login as a **Creator**, users automatically enter the setup wizard:

1. **Profile Information** — photo, cover, display name, username, bio, links
2. **Creator Branding** — theme colors, layout, fan page preview, custom URL
3. **Content Creation** — upload photos/videos, albums, categories, drag-and-drop
4. **Fan Subscriptions** — free, premium, VIP tiers with benefits
5. **AI Studio** — background removal, enhancement, filters, captions, thumbnails
6. **Creator Dashboard** — revenue, subscribers, engagement analytics preview
7. **Publish** — review all settings, preview fan page, go live

### Firebase

- `firebase/firestore.rules` — secure creator profile and media access
- `firebase/storage.rules` — authenticated uploads under `creators/{uid}/`

Add `GoogleService-Info.plist` to the Xcode target and link Firebase SDK via SPM to enable cloud sync. Without Firebase, the app uses local persistence (UserDefaults + Documents) for development.

### Getting started

Open `Aixcam.xcodeproj` in Xcode, choose an iPhone simulator (iOS 17+), then build and run.

## App icon sizing

The reusable `AixcamIconView` uses SwiftUI's `resizable()` and `scaledToFit()` modifiers with an explicit square frame so the icon image resizes without being stretched or cropped.
