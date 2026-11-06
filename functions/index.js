const fs = require("fs");
const path = require("path");
// Pinned to the v1 namespace explicitly. firebase-functions v6 ships both
// generations, and v2 would change every callable's signature AND its public
// URL (run.app rather than cloudfunctions.net) — which the six hardcoded client
// endpoints depend on. Importing v1 by name keeps the SDK current without
// moving the wire contract.
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {
  SignedDataVerifier,
  Environment,
} = require("@apple/app-store-server-library");

admin.initializeApp();

// --- App Store transaction verification config -----------------------------

// Must match your app's bundle identifier and (for production) numeric App ID.
// The fallback is the real bundle id from PRODUCT_BUNDLE_IDENTIFIER: a wrong
// value here is silent and total, because SignedDataVerifier rejects every
// transaction whose bundle doesn't match and the purchase simply never credits.
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "com.aixcam.AIxcam";
const APPLE_APP_APPLE_ID = process.env.APPLE_APP_APPLE_ID
  ? Number(process.env.APPLE_APP_APPLE_ID)
  : undefined;

// Without the numeric App ID no Production verifier can be built, so only
// Sandbox transactions verify — dev and TestFlight pass while every real App
// Store purchase fails. That is invisible until money is involved, so say it
// loudly at cold start.
if (APPLE_APP_APPLE_ID === undefined) {
  console.warn(
    "APPLE_APP_APPLE_ID is not set. Only Sandbox transactions will verify; " +
      "real App Store purchases will be rejected. Set it from App Store Connect."
  );
}
// Online OCSP-style revocation checks on the signing certificate chain.
const ENABLE_ONLINE_CHECKS = true;

// Apple root CAs used to anchor the JWS certificate chain. Download the four
// certificates from https://www.apple.com/certificateauthority/ and place the
// .cer files in functions/certs/ (see functions/certs/README.md).
let cachedRootCAs = null;
function loadAppleRootCAs() {
  if (cachedRootCAs) return cachedRootCAs;
  const dir = path.join(__dirname, "certs");
  let files;
  try {
    files = fs.readdirSync(dir).filter((f) => f.endsWith(".cer") || f.endsWith(".der"));
  } catch (e) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Apple root certificates are not installed on the server."
    );
  }
  if (files.length === 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "No Apple root certificates found in functions/certs."
    );
  }
  cachedRootCAs = files.map((f) => fs.readFileSync(path.join(dir, f)));
  return cachedRootCAs;
}

const verifierCache = {};
function verifierFor(environment) {
  if (verifierCache[environment]) return verifierCache[environment];
  const verifier = new SignedDataVerifier(
    loadAppleRootCAs(),
    ENABLE_ONLINE_CHECKS,
    environment,
    APPLE_BUNDLE_ID,
    APPLE_APP_APPLE_ID
  );
  verifierCache[environment] = verifier;
  return verifier;
}

/**
 * Verifies and decodes a StoreKit 2 signed transaction (JWS) against Apple's
 * public keys. StoreKit doesn't tell us which environment a transaction came
 * from, and a Production verifier rejects Sandbox transactions (and vice versa),
 * so we try Production first and fall back to Sandbox. Throws if neither verifies.
 */
async function verifySignedTransaction(signedTransaction) {
  const environments = [];
  // A Production verifier requires the numeric App Apple ID; only attempt it
  // when configured, otherwise go straight to Sandbox (dev/TestFlight).
  if (APPLE_APP_APPLE_ID !== undefined) environments.push(Environment.PRODUCTION);
  environments.push(Environment.SANDBOX);

  let lastError;
  for (const env of environments) {
    try {
      return await verifierFor(env).verifyAndDecodeTransaction(signedTransaction);
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError || new Error("Verification failed for all environments.");
}

/**
 * Verifies and decodes an App Store Server Notification V2 signed payload.
 * Same Production→Sandbox fallback rationale as transactions.
 */
async function verifySignedNotification(signedPayload) {
  const environments = [];
  if (APPLE_APP_APPLE_ID !== undefined) environments.push(Environment.PRODUCTION);
  environments.push(Environment.SANDBOX);

  let lastError;
  for (const env of environments) {
    try {
      return await verifierFor(env).verifyAndDecodeNotification(signedPayload);
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError || new Error("Notification verification failed for all environments.");
}

// --- Creator ledger --------------------------------------------------------
//
// Firestore schema (all backend-only; denied to clients):
//
//   creatorLedgers/{creatorId}
//     { availableMinorUnits, currency, updatedAt }
//   creatorLedgers/{creatorId}/entries/{transactionId}
//     { direction: "credit"|"debit", amountMinorUnits, currency, productId,
//       transactionId, appAccountToken, creatorId, reversed?, createdAt }
//
// Attribution: which creator a purchase belongs to is NOT derivable from the
// signed transaction alone. The client must record it at checkout in
//   attributions/{appAccountToken}  ->  { creatorId, buyerUid }
// using a per-purchase appAccountToken. Until then, entries are parked under the
// "_unattributed" ledger so no money is lost and reconciliation can happen later.

const UNATTRIBUTED = "_unattributed";

/**
 * Applies a single idempotent ledger movement for a verified transaction, and
 * flips the transaction doc's `credited` flag to match. Runs in its own Firestore
 * transaction (all reads before writes) so it is safe to call after the caller's
 * status write and safe to retry.
 *
 * Idempotency, keyed by the transaction id:
 *   - "credit": no-op if a credit entry already exists.
 *   - "debit":  no-op unless an un-reversed credit entry exists (reverses it once).
 *
 * @param {object} payload  a verified JWSTransactionDecodedPayload
 * @param {"credit"|"debit"} direction
 * @returns {Promise<boolean>} whether a movement was applied
 */
async function applyLedgerEntry(payload, direction) {
  const db = admin.firestore();
  const transactionId = String(payload.transactionId);
  const token = payload.appAccountToken || null;

  return db.runTransaction(async (tx) => {
    // ---- reads (must all precede writes) ----
    const attrSnap = token
      ? await tx.get(db.collection("attributions").doc(token))
      : null;
    const creatorId =
      attrSnap && attrSnap.exists && attrSnap.data().creatorId
        ? attrSnap.data().creatorId
        : UNATTRIBUTED;

    const ledgerRef = db.collection("creatorLedgers").doc(creatorId);
    const entryRef = ledgerRef.collection("entries").doc(transactionId);
    const txnRef = db.collection("transactions").doc(transactionId);

    const entrySnap = await tx.get(entryRef);
    const ledgerSnap = await tx.get(ledgerRef);

    // ---- idempotency guards ----
    if (direction === "credit" && entrySnap.exists) return false;
    if (direction === "debit" && (!entrySnap.exists || entrySnap.data().reversed === true)) {
      return false;
    }

    // StoreKit `price` is in milliunits of currency (price * 1000). Fall back to
    // the recorded entry amount when reversing.
    const amountMinorUnits =
      typeof payload.price === "number"
        ? Math.round(payload.price / 10)
        : entrySnap.exists
          ? entrySnap.data().amountMinorUnits || 0
          : 0;
    const currency =
      payload.currency ||
      (entrySnap.exists ? entrySnap.data().currency : null) ||
      (ledgerSnap.exists ? ledgerSnap.data().currency : null);

    const delta = direction === "debit" ? -amountMinorUnits : amountMinorUnits;
    const prevBalance = ledgerSnap.exists ? ledgerSnap.data().availableMinorUnits || 0 : 0;

    // ---- writes ----
    tx.set(
      ledgerRef,
      {
        availableMinorUnits: prevBalance + delta,
        currency: currency || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (direction === "credit") {
      tx.set(entryRef, {
        direction: "credit",
        amountMinorUnits,
        currency: currency || null,
        productId: payload.productId || null,
        transactionId,
        appAccountToken: token,
        creatorId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(
        entryRef,
        {
          reversed: true,
          reversedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    tx.set(txnRef, { credited: direction === "credit", creatorId }, { merge: true });
    return true;
  });
}

// Flip to "true" in the function environment once the iOS client is wired to send
// App Check tokens. Kept opt-in so enabling it can't silently break live clients.
//
// NOTE: this cannot be enabled yet. The app links only FirebaseAuth and
// FirebaseCore, and all six client call sites post to the function URL with a
// hand-built Authorization header rather than going through the Functions SDK,
// so `context.app` is never populated. Turning this on today would reject 100%
// of real traffic. See the deploy checklist in README before flipping it.
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

// Per-function concurrency ceilings.
//
// On the Spark plan an abusive traffic spike hit a quota wall. On Blaze there is
// no wall — it scales to the platform default and bills for it — so the ceiling
// has to be stated explicitly or a scraper becomes an invoice. These are sized
// for a pre-launch app and are deliberately low; raise them from real traffic
// data rather than from anticipation of it.
const MAX_INSTANCES = {
  streamCreds: 10,
  listLive: 20, // Viewer discovery — the most-called endpoint.
  recordTransaction: 10,
  appStoreNotifications: 10,
};

// Generous ceiling for a real App Store Server Notification JWS; anything larger
// is not one. Guards the public notification endpoint from being used to make us
// do expensive signature work on arbitrary data.
const MAX_SIGNED_PAYLOAD_BYTES = 100 * 1024;

/**
 * Rejects unauthenticated or (when enforced) un-attested callers.
 * Centralized so every callable applies the same gate.
 */
function assertVerifiedCaller(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in."
    );
  }
  if (ENFORCE_APP_CHECK && !context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App Check attestation is required."
    );
  }
}

/**
 * Fixed-window per-user rate limiter backed by Firestore.
 * Throttles abuse of the token/credential endpoints from a single account.
 * Throws resource-exhausted once the caller exceeds `limit` calls in `windowSeconds`.
 */
async function enforceRateLimit(uid, action, limit, windowSeconds) {
  const db = admin.firestore();
  const windowStart = Math.floor(Date.now() / 1000 / windowSeconds);
  const ref = db.collection("rateLimits").doc(`${action}_${uid}_${windowStart}`);

  const count = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? snap.data().count : 0;
    tx.set(
      ref,
      {
        count: current + 1,
        // TTL field — configure a Firestore TTL policy on `expiresAt` to auto-purge.
        expiresAt: admin.firestore.Timestamp.fromMillis(
          (windowStart + 1) * windowSeconds * 1000 + 60000
        ),
      },
      { merge: true }
    );
    return current + 1;
  });

  if (count > limit) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many requests. Please slow down."
    );
  }
}

/**
 * Returns the live-streaming credentials for the signed-in creator's channel,
 * provisioning a Cloudflare Stream live input the first time they go live.
 *
 * SECURITY: the ingest URL embeds the stream key, a long-lived broadcast
 * credential that must NEVER ship inside the app binary. It is minted here for
 * authenticated creators only, and the creator identity comes from the verified
 * token — never from a client-supplied field.
 *
 * Each creator gets their OWN live input. The AWS IVS version this replaced
 * fell back to one shared channel when a creator had no record, which meant two
 * creators going live at once would publish over each other.
 */
exports.createStreamCredentials = functions
  .runWith({
    secrets: ["CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_STREAM_TOKEN"],
    maxInstances: MAX_INSTANCES.streamCreds,
  })
  .https.onCall(async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "streamCreds", 20, 60);

    const uid = context.auth.uid;
    const db = admin.firestore();
    const ref = db.collection("creatorChannels").doc(uid);
    const snapshot = await ref.get();

    // Reuse the creator's existing input. Cloudflare keys are stable, so
    // re-provisioning on every Go Live would leak live inputs and hand the
    // creator a different key each session for no benefit.
    if (snapshot.exists && snapshot.get("ingestURL") && snapshot.get("playbackURL")) {
      return {
        ingestURL: snapshot.get("ingestURL"),
        playbackURL: snapshot.get("playbackURL"),
      };
    }

    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    const apiToken = process.env.CLOUDFLARE_STREAM_TOKEN;
    if (!accountId || !apiToken) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Streaming is not configured on the server."
      );
    }

    let payload;
    try {
      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/live_inputs`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            meta: { name: `aixcam-${uid}` },
            // Recorded so a finished broadcast stays watchable. Switch to "off"
            // if storage cost matters more than replays.
            recording: { mode: "automatic" },
          }),
        }
      );
      payload = await response.json();
      if (!response.ok || !payload || payload.success === false) {
        // Cloudflare returns its reason in `errors`; logging it is the
        // difference between a five-minute diagnosis and guessing.
        console.error("Cloudflare live_inputs failed", response.status, JSON.stringify(payload && payload.errors));
        throw new Error("cloudflare_rejected");
      }
    } catch (e) {
      throw new functions.https.HttpsError(
        "unavailable",
        "Could not provision a streaming channel. Try again in a moment."
      );
    }

    const input = payload.result || {};
    const rtmps = input.rtmps || {};
    // `rtmps.url` ends in a trailing slash ("rtmps://live.cloudflare.com:443/live/").
    // Guard anyway: concatenating without checking is how you ship a URL with a
    // doubled or missing separator that only fails at connect time.
    const base = String(rtmps.url || "").replace(/\/+$/, "");
    const streamKey = rtmps.streamKey;

    // Take the HLS manifest Cloudflare gives us rather than composing
    // `https://customer-<CODE>.cloudflarestream.com/<uid>/manifest/video.m3u8`
    // ourselves. Composing it would mean carrying the account's customer code
    // as a third secret — a value that is not discoverable through this API and
    // that an operator can only find by uploading a video and reading it out of
    // a URL. One fewer secret, one fewer way to be silently wrong.
    const playbackURL = (input.playback || {}).hls;

    if (!base || !streamKey || !input.uid || !playbackURL) {
      throw new functions.https.HttpsError(
        "internal",
        "Streaming provider returned an incomplete channel."
      );
    }

    const ingestURL = `${base}/${streamKey}`;

    // Persisted so listLiveChannels can join a live stream to its playback URL
    // without the client ever seeing the stream key. This collection is closed
    // to clients in firestore.rules for exactly that reason.
    await ref.set(
      {
        provider: "cloudflare",
        liveInputId: input.uid,
        ingestURL,
        playbackURL,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { ingestURL, playbackURL };
  });

/**
 * Lists channels that are currently live, for the viewer-side Discover feed.
 *
 * Joins streams/{id} (which the client may not read for other creators) with
 * creatorChannels/{uid} (closed to clients entirely — it holds the stream key)
 * and viewerProfiles/{uid} (owner-read only). Returns a narrow projection:
 * nothing sensitive, and nothing the caller could have assembled themselves.
 * This is why discovery is a function rather than a rules relaxation.
 */
exports.listLiveChannels = functions
  .runWith({ maxInstances: MAX_INSTANCES.listLive })
  .https.onCall(async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "listLive", 60, 60);

    const db = admin.firestore();

    // `endedAt == null` relies on startSession writing an explicit null. A
    // missing field matches no equality filter in Firestore, so an omitted
    // endedAt would make a live stream invisible here.
    const snapshot = await db
      .collection("streams")
      .where("endedAt", "==", null)
      .limit(50)
      .get();

    if (snapshot.empty) {
      return { channels: [] };
    }

    const creatorIds = [
      ...new Set(snapshot.docs.map((d) => d.get("creatorID")).filter(Boolean)),
    ];
    if (creatorIds.length === 0) {
      return { channels: [] };
    }

    // One batched read rather than two lookups per stream.
    const channelRefs = creatorIds.map((id) =>
      db.collection("creatorChannels").doc(id)
    );
    const profileRefs = creatorIds.map((id) =>
      db.collection("viewerProfiles").doc(id)
    );
    const fetched = await db.getAll(...channelRefs, ...profileRefs);
    const channelDocs = fetched.slice(0, creatorIds.length);
    const profileDocs = fetched.slice(creatorIds.length);

    const metaByCreator = new Map();
    creatorIds.forEach((id, index) => {
      const channel = channelDocs[index];
      const profile = profileDocs[index];
      metaByCreator.set(id, {
        playbackURL: (channel.exists && channel.get("playbackURL")) || "",
        displayName: (profile.exists && profile.get("displayName")) || "",
      });
    });

    const channels = snapshot.docs
      .map((doc) => {
        const creatorId = doc.get("creatorID");
        const meta = metaByCreator.get(creatorId) || {};
        const startedAt = doc.get("startedAt");
        return {
          streamId: doc.id,
          creatorId: creatorId || "",
          displayName: meta.displayName || "",
          startedAt: startedAt ? startedAt.toDate().toISOString() : null,
          playbackURL: meta.playbackURL || "",
        };
      })
      // A channel with no playback URL cannot be watched; listing it would only
      // produce a row that fails when tapped.
      .filter((c) => c.creatorId && c.playbackURL)
      .sort((a, b) => String(b.startedAt || "").localeCompare(String(a.startedAt || "")));

    return { channels };
  });

/**
 * Records a StoreKit transaction after server-side re-verification.
 *
 * The client sends only the App Store-signed JWS. We verify that signature
 * against Apple's public keys and read all transaction facts (id, product,
 * bundle, dates, refund status) from the *verified* payload — the client's word
 * is never trusted. Idempotent on the verified transaction id. Renewals and
 * refunds are reconciled out-of-band by App Store Server Notifications v2.
 */
exports.recordTransaction = functions
  .runWith({ maxInstances: MAX_INSTANCES.recordTransaction })
  .https.onCall(async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "txn", 60, 60);

    const { signedTransaction } = data || {};
    if (!signedTransaction || typeof signedTransaction !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "signedTransaction (JWS) is required."
      );
    }

    // 1. Verify the signature against Apple's root CAs. Anything unsigned,
    //    tampered, or from the wrong app/environment throws here.
    let payload;
    try {
      payload = await verifySignedTransaction(signedTransaction);
    } catch (e) {
      console.error("recordTransaction verification failed:", e && e.message);
      throw new functions.https.HttpsError(
        "permission-denied",
        "Transaction signature could not be verified."
      );
    }

    // 2. Defense-in-depth: confirm the verified payload really is for this app.
    if (payload.bundleId && payload.bundleId !== APPLE_BUNDLE_ID) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Transaction is for a different application."
      );
    }

    const transactionId = String(payload.transactionId);
    const isRefunded = payload.revocationDate != null;

    // 3. Persist the verified record (idempotent), then move the ledger via the
    //    shared helper. Both are keyed on the transaction id so repeats are no-ops.
    const db = admin.firestore();
    await db
      .collection("transactions")
      .doc(transactionId)
      .set(
        {
          uid: context.auth.uid,
          productId: payload.productId || null,
          originalTransactionId: payload.originalTransactionId || null,
          type: payload.type || null,
          environment: payload.environment || null,
          appAccountToken: payload.appAccountToken || null,
          purchaseDate: payload.purchaseDate
            ? admin.firestore.Timestamp.fromMillis(payload.purchaseDate)
            : null,
          expiresDate: payload.expiresDate
            ? admin.firestore.Timestamp.fromMillis(payload.expiresDate)
            : null,
          status: isRefunded ? "refunded" : "verified",
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    await applyLedgerEntry(payload, isRefunded ? "debit" : "credit");

    return {
      status: isRefunded ? "refunded" : "verified",
      transactionId,
      productId: payload.productId || null,
    };
  });

// --- App Store Server Notifications V2 -------------------------------------

/**
 * Applies a verified notification's transaction to Firestore, reconciling
 * refunds, renewals, and expirations. Idempotent per notificationUUID.
 *
 * @param {object} notification decoded ResponseBodyV2DecodedPayload
 */
async function handleNotification(notification) {
  const db = admin.firestore();
  const notificationUUID = notification.notificationUUID;
  const type = notification.notificationType; // e.g. "REFUND", "DID_RENEW"
  const subtype = notification.subtype || null;
  const data = notification.data || {};

  // Dedupe: Apple retries until it gets a 200, so the same UUID can arrive twice.
  const seenRef = db.collection("appStoreNotifications").doc(notificationUUID);
  const isNew = await db.runTransaction(async (tx) => {
    const snap = await tx.get(seenRef);
    if (snap.exists) return false;
    tx.set(seenRef, {
      type,
      subtype,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 24 * 3600 * 1000),
    });
    return true;
  });
  if (!isNew) {
    console.log(`ASSN ${notificationUUID} already processed; skipping.`);
    return;
  }

  // Notifications without transaction info (e.g. some TEST pings) need no work.
  if (!data.signedTransactionInfo) {
    console.log(`ASSN ${type}/${subtype} has no transaction info.`);
    return;
  }

  // The transaction inside the notification is itself a JWS — verify it too.
  const txn = await verifySignedTransaction(data.signedTransactionInfo);
  const transactionId = String(txn.transactionId);
  const originalTransactionId = txn.originalTransactionId
    ? String(txn.originalTransactionId)
    : transactionId;

  const isRefundOrRevoke = type === "REFUND" || type === "REVOKE" || txn.revocationDate != null;
  const isRenewalOrPurchase =
    type === "DID_RENEW" ||
    type === "SUBSCRIBED" ||
    type === "OFFER_REDEEMED" ||
    type === "RESUBSCRIBE";
  const isExpiration =
    type === "EXPIRED" ||
    type === "GRACE_PERIOD_EXPIRED" ||
    (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD");

  const txnRef = db.collection("transactions").doc(transactionId);
  const subRef = db.collection("subscriptions").doc(originalTransactionId);

  // Persist the transaction status and the subscription entitlement snapshot.
  // The `credited` flag is owned by applyLedgerEntry, so it isn't touched here.
  await db.runTransaction(async (tx) => {
    tx.set(
      txnRef,
      {
        productId: txn.productId || null,
        originalTransactionId,
        type: txn.type || null,
        environment: txn.environment || null,
        appAccountToken: txn.appAccountToken || null,
        purchaseDate: txn.purchaseDate
          ? admin.firestore.Timestamp.fromMillis(txn.purchaseDate)
          : null,
        expiresDate: txn.expiresDate
          ? admin.firestore.Timestamp.fromMillis(txn.expiresDate)
          : null,
        status: isRefundOrRevoke ? "refunded" : "verified",
        lastNotificationType: type,
        lastNotificationSubtype: subtype,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Maintain the subscription entitlement snapshot for auto-renewables.
    if (isRenewalOrPurchase || isExpiration || isRefundOrRevoke) {
      const nowMs = Date.now();
      const expiresMs = txn.expiresDate || 0;
      const active = !isRefundOrRevoke && !isExpiration && expiresMs > nowMs;
      tx.set(
        subRef,
        {
          productId: txn.productId || null,
          appAccountToken: txn.appAccountToken || null,
          environment: txn.environment || null,
          active,
          expiresDate: txn.expiresDate
            ? admin.firestore.Timestamp.fromMillis(txn.expiresDate)
            : null,
          lastNotificationType: type,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  });

  // Move the ledger through the shared, idempotent helper. Refunds/revokes
  // reverse a prior credit exactly once; renewals/purchases credit exactly once.
  if (isRefundOrRevoke) {
    await applyLedgerEntry(txn, "debit");
  } else if (isRenewalOrPurchase) {
    await applyLedgerEntry(txn, "credit");
  }
}

/**
 * HTTPS endpoint that Apple calls with App Store Server Notifications V2.
 * Configure this URL in App Store Connect (Production and Sandbox).
 *
 * Response contract: 200 = handled (Apple stops), 5xx = retry with backoff,
 * 4xx = bad request / bad signature (Apple will not usefully retry).
 */
exports.appStoreNotifications = functions
  .runWith({ maxInstances: MAX_INSTANCES.appStoreNotifications })
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const signedPayload = req.body && req.body.signedPayload;
    if (!signedPayload || typeof signedPayload !== "string") {
      res.status(400).send("Missing signedPayload");
      return;
    }

    // This endpoint is public and unauthenticated by design — Apple cannot carry a
    // bearer token — so the only thing standing between a stranger and our compute
    // is the signature check. That check is expensive: it walks a certificate chain
    // and, with ENABLE_ONLINE_CHECKS, makes an outbound OCSP request. Rejecting
    // anything that cannot possibly be a JWS first keeps a flood of junk from
    // turning into billable CPU and egress.
    if (signedPayload.length > MAX_SIGNED_PAYLOAD_BYTES) {
      res.status(400).send("Payload too large");
      return;
    }
    if (signedPayload.split(".").length !== 3) {
      res.status(400).send("Malformed signedPayload");
      return;
    }

    let notification;
    try {
      notification = await verifySignedNotification(signedPayload);
    } catch (e) {
      console.error("ASSN signature verification failed:", e && e.message);
      res.status(400).send("Invalid signature");
      return;
    }

    try {
      await handleNotification(notification);
    } catch (e) {
      // Transient failure — let Apple retry.
      console.error("ASSN handling error:", e);
      res.status(500).send("Processing error");
      return;
    }

    res.status(200).send("OK");
  });
