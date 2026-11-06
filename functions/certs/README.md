# Apple Root Certificates

`recordTransaction` verifies StoreKit 2 signed transactions (JWS) against Apple's
root certificate authorities. Place Apple's root CA certificates in **this
directory** (`functions/certs/`) as `.cer` (DER) files. They are loaded by
`loadAppleRootCAs()` in `../index.js`.

## Download

All four are now committed to this directory. To re-fetch or refresh them:

```bash
cd functions/certs
curl -O https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
curl -O https://www.apple.com/certificateauthority/AppleRootCA-G2.cer
curl -O https://www.apple.com/certificateauthority/AppleComputerRootCertificate.cer
# Note the different path for this one — it is NOT under /certificateauthority/.
curl -O https://www.apple.com/appleca/AppleIncRootCertificate.cer
```

Only `AppleRootCA-G3` is strictly required for current StoreKit transactions;
including the others is harmless and future-proofs the chain.

These are **public** certificates — safe to commit, and they must be committed.
`loadAppleRootCAs()` throws `failed-precondition` when this directory holds no
`.cer`/`.der` files, which takes down `recordTransaction` and makes
`appStoreNotifications` return 500 to every Apple retry. An empty certs
directory means no purchase ever credits a creator.

Verify a file is a real DER certificate with:

```bash
openssl x509 -inform DER -in AppleRootCA-G3.cer -noout -subject
```

## Required function environment variables

Set before deploying:

```bash
firebase functions:config:set   # (or use process env / secrets)
# APPLE_BUNDLE_ID     com.aixcam.AIxcam  (must match PRODUCT_BUNDLE_IDENTIFIER;
#                     this is also the in-code default, so it only needs setting
#                     if the bundle id ever changes)
# APPLE_APP_APPLE_ID  numeric App Store app id (required to verify PRODUCTION
#                     transactions; omit and only Sandbox is attempted)
```

If `APPLE_APP_APPLE_ID` is unset, only Sandbox verification is attempted — fine
for local and TestFlight testing, but it means **every real App Store purchase
fails verification**. The function logs a warning at cold start when it is
missing. Set it from App Store Connect before shipping.
