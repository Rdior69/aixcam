# Aixcam architecture

## Current phase

- Phase A: Discovery plan — complete
- Phase B: Root navigation + session management — complete
- Phase C: Auth + Firebase activate/fallback — complete (awaiting approval before Phase D)

## Root routing

`SessionManager` owns bootstrap and publishes `AppRootRoute` via `SessionRouter.route(for:)`.

| Route | Meaning |
|-------|---------|
| `launching` | Splash while session revalidates |
| `unauthenticated` | Welcome / auth |
| `creatorNeedsOnboarding` | Creator Home with setup banner |
| `creatorHome` | Published creator |
| `subscriberNeedsOnboarding` | Subscriber shell + setup notice |
| `subscriberHome` | Subscriber shell |
| `accountBlocked` | Suspended / restricted |

## Backend selection (Phase C)

`FirebaseBootstrap.configureIfPossible()` runs at launch.

| Condition | Backend |
|-----------|---------|
| No Firebase SDK linked, or no `GoogleService-Info.plist` in bundle | `LocalCreatorBackendService` (Keychain) |
| SDK linked **and** plist present **and** `FirebaseApp` configured | `FirebaseCreatorBackendService` |

See `Docs/FIREBASE_AUTH.md` for the activate checklist.

## Defaults for this epic

- Display brand remains **Aixcam**
- Fan (and temporarily Brand) map to the subscriber experience
- Firebase is optional; local auth remains the default without a real plist
