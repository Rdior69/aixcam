# Apple Root Certificates

`recordTransaction` verifies StoreKit 2 signed transactions (JWS) against Apple's
root certificate authorities. Place Apple's root CA certificates in **this
directory** (`functions/certs/`) as `.cer` (DER) files. They are loaded by
`loadAppleRootCAs()` in `../index.js`.

## Download

From https://www.apple.com/certificateauthority/ download and save here:

- `AppleRootCA-G3.cer`  ← the one that signs StoreKit / App Store Server JWS
- `AppleRootCA-G2.cer`
- `AppleIncRootCertificate.cer`
- `AppleComputerRootCertificate.cer`

Only `AppleRootCA-G3` is strictly required for current StoreKit transactions;
including the others is harmless and future-proofs the chain.

These are **public** certificates — safe to commit to the repo.

## Required function environment variables

Set before deploying:

```bash
firebase functions:config:set   # (or use process env / secrets)
# APPLE_BUNDLE_ID     e.g. com.aixcam.app   (must match the app's bundle id)
# APPLE_APP_APPLE_ID  numeric App Store app id (required to verify PRODUCTION
#                     transactions; omit and only Sandbox is attempted)
```

If `APPLE_APP_APPLE_ID` is unset, only Sandbox verification is attempted, which
is the right default for local/TestFlight testing.
