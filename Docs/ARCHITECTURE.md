# Aixcam architecture

## Current phase

- Phase A: Discovery plan — complete
- Phase B: Root navigation + session management — complete
- Phase C: Auth + Firebase activate/fallback — complete
- Phase D: Biometric / PIN App Lock — complete
- Phase E: Creator + subscriber onboarding — complete (awaiting approval before Phase F)

## Root routing

`SessionManager` owns bootstrap and publishes `AppRootRoute` via `SessionRouter.route(for:)`.

| Route | Meaning |
|-------|---------|
| `launching` | Splash while session revalidates |
| `unauthenticated` | Welcome / auth |
| `creatorNeedsOnboarding` | Creator Home + auto setup cover |
| `creatorHome` | Published creator |
| `subscriberNeedsOnboarding` | Subscriber Home + auto setup cover |
| `subscriberHome` | Subscriber shell after setup |
| `accountBlocked` | Suspended / restricted |

## Onboarding (Phase E)

- **Creator:** existing 7-step wizard; auto-opens when unpublished; persists `currentStepRawValue` for resume
- **Subscriber (Fan/Brand):** 4-step wizard (welcome → profile → interests → preferences); completes via `completeSubscriberOnboarding` and sets `hasCompletedSubscriberOnboarding`

## App Lock (Phase D)

Orthogonal to routing. When App Lock is enabled (4-digit PIN in Keychain):

1. Authenticated cold start → `UnlockView` until PIN / biometrics succeed
2. Background timeout (immediate / 1 min / 5 min) → lock again
3. Settings from Creator / Subscriber home (`lock.shield`)

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
- App Lock is opt-in (disabled until a PIN is set)
