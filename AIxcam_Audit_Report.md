# AIxcam — Full Application Audit Report

**Prepared:** August 18, 2026
**Status:** Stage 3 Pre-Launch Review
**Scope:** Architecture · UX · Monetization · Security
**Confidential — Internal Use Only**

---

## Executive Summary

The app has a well-structured SwiftUI shell with solid Firebase Auth integration, a clean Observable/MainActor architecture, and functional camera capture plumbing. However, the core product — live video streaming — is entirely a simulation. `MockStreamingService` produces no real bytes, `AVCaptureSession` has no output attached, and every streaming, chat, tipping, and analytics surface is placeholder text. The current build is a high-fidelity prototype, not a shippable product.

### Summary Scorecard

| Dimension | Current State | Score |
|---|---|---|
| Architecture | Camera capture exists; no ingest, CDN, or realtime layer | 2 / 10 |
| Creator UX | Clean UI shell; zero real functionality beyond auth | 3 / 10 |
| Viewer UX | Discover is empty; no playback, no chat | 1 / 10 |
| Monetization | Fully simulated; no payment processor connected | 0 / 10 |
| Security | Firebase Auth is real; stream security is a placeholder | 3 / 10 |
| Test Coverage | Both test files are empty scaffolding | 0 / 10 |

---

## 1. Architecture & Scalability

### 1.1 Video Ingest Pipeline — Critical Gap

`CameraManager` configures an `AVCaptureSession` with a video input and audio input but attaches **zero outputs**. No `AVCaptureVideoDataOutput`, no `AVCaptureAudioDataOutput`, no `AVCaptureMovieFileOutput`. The camera renders to a preview layer only. `MockStreamingService.startBroadcast()` creates a UUID, sleeps 450ms, and returns. No video bytes ever leave the device.

An ingest protocol must be selected before anything else can be built:

| Protocol | Latency | Complexity | iOS SDK | Best For |
|---|---|---|---|---|
| **RTMP** | 2–5 s | Low | HaishinKit / LFLiveKit | Traditional streaming (Twitch-style) |
| **WebRTC** | <500 ms | High | LiveKit / native | Ultra-low latency, two-way |
| **SRT** | 0.5–3 s | Medium | libsrt | Reliable over lossy mobile networks |
| **LL-HLS** | 2–6 s | Low | AVAssetWriter | Viewer-side delivery only, not for ingest |

**Recommended path:** RTMP ingest via **HaishinKit** (Swift-native, battle-tested) feeding **AWS IVS** or **Mux**. This gives a real encode → publish pipeline in under a week, with CDN distribution handled by the media server.

`AVCaptureVideoDataOutput` and `AVCaptureAudioDataOutput` must be wired into `CameraManager` immediately — this is a Day 1 blocker.

### 1.2 No CDN Layer

There is no viewer-side delivery architecture. When you have 1,000 viewers, each cannot pull directly from the creator's device. Required components:

- **Origin server:** Media server receives RTMP from device, packages into HLS/DASH segments
- **CDN:** CloudFront, Fastly, or Akamai caches and distributes segments globally
- **Playback URL:** Issued to `DiscoverView` viewers per stream session

AWS IVS or Mux collapse the origin and CDN into a single managed service — the right call at this stage. Do not build your own media server for the initial launch.

### 1.3 No Real-Time Communication Layer

Chat, viewer count, and tip notifications require a persistent bi-directional channel. Since Firebase is already a dependency, Firestore is the zero-friction path:

- `streams/{streamID}/messages` — live chat collection with `createdAt`, `senderUID`, `text`
- `streams/{streamID}/viewers` — `FieldValue.increment()` counter, not a per-user presence doc
- Apple Push Notification for background tip alerts when the app is not foregrounded

### 1.4 Database Schema — Not Started

No Firestore schema exists. Minimum required collections:

| Collection | Key Fields |
|---|---|
| `users/{uid}` | email, displayName, createdAt, payoutInfo, subscriberCount |
| `streams/{streamID}` | creatorUID, status, startedAt, playbackURL, viewerCount |
| `streams/{id}/messages` | senderUID, text, createdAt |
| `tips/{tipID}` | amount, fromUID, toUID, streamID, timestamp |
| `subscriptions/{id}` | subscriberUID, creatorUID, tier, renewsAt, status |

### 1.5 CameraManager Threading Model

`CameraManager` is `@Observable` without `@MainActor`. The `@Observable` macro's access tracking is not thread-safe unless isolated to the main actor. All observable mutations go through `Task { @MainActor in ... }` which is correct, but the class itself is accessible for reads from any thread. Mark it `@MainActor` and dispatch session work to a `sessionQueue` internally.

### 1.6 Camera Session Interruption Not Handled

`AVCaptureSession` emits `AVCaptureSessionWasInterrupted` notifications on phone calls, FaceTime, and low-battery camera suspension. None are observed. A phone call mid-stream will freeze the camera feed without the app knowing, keeping the RTMP connection open while sending a frozen frame.

Required actions on interrupt: pause the stream, activate the privacy shield, and alert the creator with a recoverable error state.

### 1.7 Slider Range Collapse — Crash Risk

In `LiveBroadcastView`, the zoom `Slider` is initialized with `range: 1.0...viewModel.maxZoomFactor`. `maxZoomFactor` starts at `1.0` before the camera is configured. A `Slider` with range `1.0...1.0` is a zero-width range that triggers a `preconditionFailure` in SwiftUI's slider layout engine.

**Fix:** Change `max(..., 1.0)` to `max(..., 1.01)` in the `maxZoomFactor` computed property to guarantee a non-degenerate range before the camera is ready.

---

## 2. Creator and Viewer UX

### 2.1 Hardcoded Creator Identity

`HomeView` displays **"Hello, Creator"** and `ProfileView` displays **"Creator"** regardless of who is authenticated. Firebase Auth provides `displayName` on the user object. `AppRouter` should expose a computed `displayName` property and both views should use it.

```swift
// AppRouter.swift — add this
var displayName: String {
    currentUser?.displayName ?? currentUser?.email?.components(separatedBy: "@").first ?? "Creator"
}
```

### 2.2 Stream Setup Has No Configuration Step

Tapping "Start Live Stream" immediately launches the broadcast view with a hardcoded `creatorID: "creator-demo"`. Creators must be able to configure before going live:

- **Stream title** (required for discovery and SEO)
- **Category and tags** (for Discover feed ranking)
- **Privacy setting:** public, followers-only, or unlisted
- **Stream quality:** 720p / 1080p based on detected connection speed
- **Thumbnail preview** and test-stream mode before going live

### 2.3 Swipe-to-Back Gesture Broken

`SignInView`, `SignUpView`, and `LiveBroadcastView` all use `.toolbar(.hidden, for: .navigationBar)` with a custom back button overlay. This suppresses the system navigation bar, which **also disables the swipe-to-go-back gesture** on `NavigationStack`. This is a standard iOS UX expectation.

**Fix:** Use `.navigationBarBackButtonHidden(true)` with a custom `.toolbar` item instead of hiding the entire bar.

### 2.4 Chat is Entirely Static Placeholder

The three hardcoded strings in `LiveBroadcastView` are the only chat content in the app. There is no input field, no real message sending, no moderation, and no persistence. A full Firestore-backed implementation with profanity filtering and creator-mute capabilities is required before launch.

### 2.5 No Stream Quality / Latency Feedback

There is no bitrate meter, frame-rate counter, packet-loss indicator, or latency display during a live stream. Mobile creators on congested networks need to know when their stream is degrading before viewers complain. A minimal stats overlay (bitrate, FPS, network quality) is required.

### 2.6 Permission Denial Recovery Incomplete

When a user grants camera permission in Settings and returns to the app, `handleAppBecameActive()` calls `cameraManager.startSession()` directly without re-running the permission check. The permission overlay will remain visible even after access is granted.

**Fix:** Replace the direct `startSession()` call in `handleAppBecameActive` with a full call to `requestPermissionsAndPrepareCamera()`.

### 2.7 No Accessibility Support

No `.accessibilityLabel` is present on any interactive control across the entire app. VoiceOver users cannot operate the flip-camera button, mute button, zoom slider, or go-live button. All explicit font sizes also prevent Dynamic Type scaling. This is an App Store Review risk — Apple evaluates accessibility compliance during review.

### 2.8 Discover is Entirely Empty

`DiscoverView` shows only a placeholder message referencing "Stage 6." The data model for streams (playback URL, stream status, thumbnail, viewer count) must be designed now since it affects the Firestore schema and CDN URL structure that all other features depend on.

---

## 3. Monetization and Creator Tools

### 3.1 Tipping — Entirely Simulated

`triggerTipPlaceholder()` fires a fake "Tip received" animation on a random timer. No payment processor is integrated.

Architecture required for real tipping:
- **StoreKit 2** consumable products for tip amounts (Apple requires IAP for in-app digital goods — 30% cut)
- **Firestore** `tips` collection as a ledger for creator payout accounting
- **Cloud Function** to validate and record each IAP receipt server-side
- **1099-K** tax form generation for US creators earning over $600/year

> **Note:** Apple has historically required tips during live streams to go through IAP. Plan for the 30% fee in your creator payout model from day one.

### 3.2 No Subscription Infrastructure

There is no concept of subscriptions anywhere in the codebase. Required components:

- **RevenueCat** for subscription management (handles IAP receipts, renewals, entitlements)
- **Subscriber-only stream access gating** in the stream session model
- **Subscriber badge** in chat (role-based display name decoration)
- **Monthly creator payout** for subscription revenue minus platform fee

### 3.3 No Post-Stream Analytics

Creators need actionable post-stream data. Nothing is instrumented today. Minimum required:

- Peak and average viewer count over stream duration
- Total tips received, broken down by viewer
- Chat message volume and engagement rate
- Geographic distribution of viewers
- Stream duration and viewer drop-off timestamps

### 3.4 Creator Profile Not Created on Sign-Up

`AppRouter.signUp()` creates a Firebase Auth account but does **not** write a Firestore `users/{uid}` document. The first time a creator signs in there is no profile for the rest of the app to query.

```swift
// AppRouter.swift — add to signUp()
let result = try await Auth.auth().createUser(withEmail: email, password: password)
try await Firestore.firestore().collection("users").document(result.user.uid).setData([
    "email": email,
    "createdAt": FieldValue.serverTimestamp(),
    "displayName": ""
])
```

### 3.5 creatorID Hardcoded to a String Literal

```swift
// HomeView.swift — current (wrong)
LiveBroadcastViewModel(creatorID: "creator-demo")

// HomeView.swift — required
LiveBroadcastViewModel(creatorID: appRouter.currentUser?.uid ?? "")
```

Every stream created in the current build would be attributed to the literal string `"creator-demo"` in Firestore rather than the real user's UID. This is a data integrity bug.

---

## 4. Security and Data Privacy

### 4.1 Stream Key Management — Not Implemented

There is no stream key concept. The `creatorID` string is used as the broadcast identifier, which would expose the Firebase UID in network traffic. Stream keys must be:

- Randomly generated server-side per session (Cloud Functions)
- Short-lived (expire when the stream ends)
- Never reused across sessions
- Independently revocable without affecting the user account

### 4.2 MainActor.assumeIsolated in Auth Listener — Crash Risk

```swift
// AppRouter.swift — current (risky)
Auth.auth().addStateDidChangeListener { [weak self] _, user in
    MainActor.assumeIsolated {   // crashes if called off main thread
        self?.currentUser = user
        self?.isAuthenticated = user != nil
    }
}

// AppRouter.swift — safe replacement
Auth.auth().addStateDidChangeListener { [weak self] _, user in
    Task { @MainActor [weak self] in
        self?.currentUser = user
        self?.isAuthenticated = user != nil
    }
}
```

`assumeIsolated` is a runtime assertion that crashes with `preconditionFailure` if the current context is not the main actor. Firebase currently calls this listener on the main thread, but this is an implementation detail — not a public API guarantee.

### 4.3 Sign-Out Errors Silently Swallowed

```swift
// AppRouter.swift
func signOut() {
    try? Auth.auth().signOut()  // errors silently discarded
}
```

Firebase sign-out errors occur on keychain access failures. Silent failure means the user believes they signed out but their session token remains valid and stored. At minimum, log to Crashlytics.

### 4.4 No Rate Limiting on Authentication

There is no local throttle on failed sign-in attempts beyond disabling the button during an active request. Add local exponential backoff and a lockout UI after three consecutive failures to prevent credential stuffing from the client side.

### 4.5 No Password Complexity Enforcement

Firebase requires a minimum of 6 characters. `SignUpView` has no local validation — a user can submit a 5-character password and receive a cryptic Firebase error string. Add a local check with a clear human-readable message before the network call, and display a password strength indicator.

### 4.6 StreamingSecurityPolicy Uses Placeholder Domain

```swift
// StreamingService.swift — current
static let `default` = StreamingSecurityPolicy(
    ingestURL: URL(string: "https://stream.aixlive.local/ingest")!,
    allowedHosts: ["stream.aixlive.local"]
)
```

The `.local` TLD is for mDNS/Bonjour local network discovery — not a real public domain. The validation logic (scheme check, IP block, allowlist enforcement) is well-designed. Update the policy with your actual CDN or media server ingest domains before wiring any real streaming.

### 4.7 No DRM or Content Protection

Three levels of content protection are required:

- **FairPlay Streaming (FPS):** Apple's DRM for HLS content. Requires an Apple FPS certificate and key server. Essential for premium/paid streams. Onboarding takes **4–6 weeks — begin immediately.**
- **Visible watermarking:** Burn the viewer's username into the video frame client-side as a deterrent to screen recording. Compositable with `AVVideoComposition`.
- **Forensic watermarking:** Invisible per-viewer watermarks (Verimatrix, Irdeto) that survive re-encoding. Required at scale for premium content.

### 4.8 Privacy Manifest Compliance

Apple requires a `PrivacyInfo.xcprivacy` manifest declaring all data uses and required reason APIs. Verify:

1. Firebase SDK version in `Package.swift` is ≥ 10.25.0 (earlier versions ship no privacy manifest)
2. Your app target has its own `PrivacyInfo.xcprivacy` declaring all data categories collected (user ID, usage data, crash data)

### 4.9 App Transport Security Audit

Verify that `Info.plist` contains no `NSAllowsArbitraryLoads: true` exception. These are sometimes added to resolve Firebase SDK connection issues during development and accidentally left in production builds, disabling TLS enforcement for all outbound connections.

---

## 5. Test Coverage

Both `AIxcamTests.swift` and `AIxcamUITests.swift` are empty scaffolding. The app has **zero test coverage.**

| Test Case | Type | Priority |
|---|---|---|
| `StreamingSecurityPolicy.validate()` — invalid URLs, IP addresses, HTTP scheme | Unit | Critical |
| `AppRouter` auth state transitions (signIn, signOut, signUp error handling) | Unit | Critical |
| `LiveBroadcastViewModel` state machine (goLive, endLive, isPreparing guard) | Unit | Critical |
| `CameraManager` zoom clamping (min/max bounds, 1.01 floor) | Unit | High |
| `signUp()` → Firestore document creation | Integration | High |
| Permission denial → overlay appears; permission grant → overlay clears | Unit | High |
| Focus task cancel on rapid second tap (no premature nil) | Unit | Medium |
| Full onboarding flow (sign up → MainTabView appears) | UI | Medium |

---

## 6. Issues Fixed This Session

The following bugs were identified and corrected before this report was written:

| # | Issue | File | Fix Applied |
|---|---|---|---|
| 1 | `hasPermission` initialized to `true` before any permission check | `LiveBroadcastViewModel` | Changed initial value to `false` |
| 2 | Focus task race — rapid double-tap hid new indicator early | `LiveBroadcastViewModel` | Added `focusTask`; cancel-and-replace on each tap; cancel in `onDisappear` |
| 3 | `FocusIndicatorView` animation used `value: UUID()` — triggered on every parent re-render | `LiveBroadcastView` | Removed spurious animation modifier; `.transition` handles enter/exit |
| 4 | Dead code: `configureIfNeeded()` defined but never called | `CameraManager` | Removed unused method |
| 5 | `keyboardType` modifier missing on `SecureField` branch | `AuthTextField` | Applied modifier to both `TextField` and `SecureField` |

---

## 7. Prioritized Roadmap

### Phase 1 — Make It Real (Weeks 1–3)

- [ ] Integrate **HaishinKit + AWS IVS** (or Mux) — wire `AVCaptureVideoDataOutput` → encoder → RTMP publisher
- [ ] Replace `creatorID: "creator-demo"` with `appRouter.currentUser?.uid`
- [ ] Create Firestore `users/{uid}` document on sign-up
- [ ] Fix `MainActor.assumeIsolated` → `Task { @MainActor in ... }` in `AppRouter`
- [ ] Fix `maxZoomFactor` floor from `1.0` to `1.01` to prevent Slider crash
- [ ] Fix `handleAppBecameActive` to re-check permissions via `requestPermissionsAndPrepareCamera()`

### Phase 2 — UX Completeness (Weeks 4–6)

- [ ] Stream configuration screen: title, category, privacy, quality selector
- [ ] Real-time chat via Firestore with profanity filtering and creator-mute
- [ ] Live stream stats overlay: bitrate, FPS, estimated latency, signal strength
- [ ] Fix swipe-to-back gesture in `SignInView`, `SignUpView`, `LiveBroadcastView`
- [ ] `DiscoverView` with live stream grid fed from Firestore + playback via `AVPlayer`
- [ ] Camera session interruption handling (`AVCaptureSessionWasInterrupted`)
- [ ] Replace hardcoded "Hello, Creator" with real `displayName` from Firebase Auth

### Phase 3 — Monetization (Weeks 7–10)

- [ ] In-app tipping via **StoreKit 2** consumables with Firestore tip ledger
- [ ] Subscription management via **RevenueCat** with entitlement gating
- [ ] Post-stream analytics screen (peak viewers, tips, watch time, geography)
- [ ] Creator payout dashboard with **Stripe Connect** integration
- [ ] 1099-K tax form generation for US creators earning over $600/year

### Phase 4 — Security Hardening (Weeks 11–13)

- [ ] Server-side stream key generation and rotation (Cloud Functions)
- [ ] **Begin Apple FairPlay Streaming onboarding immediately** (4–6 week process)
- [ ] `PrivacyInfo.xcprivacy` for all data categories — verify Firebase SDK ≥ 10.25.0
- [ ] Password complexity enforcement and exponential backoff on auth failures
- [ ] ATS and Keychain audit — no `NSAllowsArbitraryLoads` in `Info.plist`
- [ ] Forensic watermarking evaluation for premium content tiers

### Phase 5 — Scale & Operations (Weeks 14+)

- [ ] Load test ingest pipeline at 10,000 concurrent streams
- [ ] CDN cache-hit ratio monitoring and origin offload tuning
- [ ] Firestore security rules audit (no open read/write permissions)
- [ ] Analytics data pipeline: BigQuery or Amplitude for creator dashboards
- [ ] Abuse detection: CSAM pipeline (PhotoDNA / Apple APIs) — required before public launch
- [ ] App Store Review preparation: accessibility audit, privacy nutrition labels, age rating

---

## Closing Notes

The UI quality and code organization are genuinely good. The `@Observable` / `@MainActor` architecture is clean, the permission and privacy shield flows are thoughtful, and `StreamingSecurityPolicy` validates correctly by design. The investment in polish is not wasted.

The next sprint must be entirely focused on **Phase 1**: wiring real video bytes from the camera to a real media server. Every other feature in this roadmap depends on that foundation being in place first.
