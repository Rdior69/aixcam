# Aixcam architecture

## Current phase

- Phase A: Discovery plan — complete
- Phase B: Root navigation + session management — complete (awaiting approval before Phase C)

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

## Defaults for this epic

- Display brand remains **Aixcam**
- Fan (and temporarily Brand) map to the subscriber experience
- Firebase stays optional until Phase C (local backend default)
