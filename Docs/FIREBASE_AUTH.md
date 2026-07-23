# Firebase Auth activate path (Phase C)

## Default (no Firebase)

Without the Firebase iOS SDK linked **and** a real `GoogleService-Info.plist` in the app bundle, Aixcam uses:

- `LocalCreatorBackendService`
- Keychain-backed member credentials (`SecureCredentialStore`)
- UserDefaults session cache (`aixcam.currentSession.v2`)

`FirebaseApp.configure()` is **never** called without a plist (that would crash).

## Activate Firebase Auth

1. In Xcode, ensure Swift packages from `https://github.com/firebase/firebase-ios-sdk` are resolved and these products are linked to the **Aixcam** target:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseStorage`
   - `FirebaseFunctions`
   - `FirebaseCore`
2. Copy `.GoogleService-Info.plist.example` → `GoogleService-Info.plist` (repo root or `Aixcam/`).
3. Fill in real values from the Firebase console (iOS app `com.aixcam.app`).
4. Add `GoogleService-Info.plist` to the **Aixcam** target membership (Copy Bundle Resources).
5. **Do not commit** the real plist (gitignored).
6. Clean build and run. `CreatorBackendFactory.activeKind` becomes `.firebase`.

## Auth behavior when Firebase is active

| Action | Behavior |
|--------|----------|
| Sign up | Firebase Auth email/password + `users/{uid}` Firestore doc |
| Login | Auth sign-in + load `users/{uid}` |
| Revalidate | Requires `Auth.auth().currentUser.uid` match + Firestore refresh |
| Sign out | `Auth.auth().signOut()` + clear local session cache |
| Auth errors | Mapped via `FirebaseAuthErrorMapper` to `CreatorBackendError` |

## Console checklist

- Enable **Email/Password** in Firebase Authentication
- Deploy `firestore.rules` / `storage.rules`
- Optional: Auth emulator via Firebase CLI for local testing
