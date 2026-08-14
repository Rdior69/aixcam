# Firebase Setup Guide for AIxcam

## Overview
AIxcam uses Firebase Authentication for user sign-in and account management.

## Setup Instructions

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard

### 2. Add iOS App to Firebase Project
1. In the Firebase Console, click the iOS+ icon
2. Enter your iOS bundle ID (e.g., `com.yourcompany.aixcam`)
3. Download the `GoogleService-Info.plist` file
4. **Important**: Add this file to your Xcode project
   - Drag it into your Xcode project navigator
   - Make sure "Copy items if needed" is checked
   - Ensure it's added to your app target

### 3. Enable Authentication Methods
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** authentication
3. (Optional) Enable any additional providers you want to support

### 4. Configure Info.plist
Your `Info.plist` needs the following entries for camera/microphone access:

```xml
<key>NSCameraUsageDescription</key>
<string>AIxcam needs camera access to stream live video.</string>

<key>NSMicrophoneUsageDescription</key>
<string>AIxcam needs microphone access to stream live audio.</string>
```

### 5. Verify Installation
The app already has Firebase configured in `AIxcamApp.swift`:
```swift
init() {
    FirebaseApp.configure()
}
```

This will automatically read from your `GoogleService-Info.plist` file.

## Security Notes

⚠️ **Never commit `GoogleService-Info.plist` to version control with real credentials!**

For development:
- Use a test Firebase project
- Add `.gitignore` entry: `GoogleService-Info.plist`

For production:
- Use Firebase App Check for additional security
- Enable Firebase Security Rules
- Consider using different Firebase projects for dev/staging/production

## Testing Authentication

Once configured, you can:
1. Launch the app
2. Tap "Create Account"
3. Enter an email and password
4. Sign up successfully

You can view registered users in Firebase Console under **Authentication** → **Users**.

## Troubleshooting

### "No GoogleService-Info.plist found"
- Ensure the file is in your project root and added to the app target
- Clean build folder (Cmd+Shift+K) and rebuild

### Authentication fails
- Check Firebase Console → Authentication is enabled
- Verify Email/Password provider is enabled
- Check Xcode console for detailed error messages

### Camera doesn't work
- Verify Info.plist has camera/microphone usage descriptions
- Check device Settings → Privacy → Camera/Microphone permissions

## Current Status

✅ Firebase SDK dependencies added (Package.swift)
✅ Firebase initialized in app (AIxcamApp.swift)
✅ Authentication flow implemented (AppRouter.swift)
⚠️ **ACTION NEEDED**: Add your `GoogleService-Info.plist` file
⚠️ **ACTION NEEDED**: Add camera/microphone permissions to Info.plist
