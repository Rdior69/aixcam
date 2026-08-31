const fs = require("fs");
const path = require("path");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { IvschatClient, CreateChatTokenCommand } = require("@aws-sdk/client-ivschat");
const {
  SignedDataVerifier,
  Environment,
} = require("@apple/app-store-server-library");

admin.initializeApp();

// --- App Store transaction verification config -----------------------------

// Must match your app's bundle identifier and (for production) numeric App ID.
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "com.aixcam.app";
const APPLE_APP_APPLE_ID = process.env.APPLE_APP_APPLE_ID
  ? Number(process.env.APPLE_APP_APPLE_ID)
  : undefined;
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
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

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
 * Mints a short-lived IVS Chat token for the signed-in user.
 */
exports.createChatToken = functions
  .runWith({ secrets: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"] })
  .https.onCall(async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "chatToken", 30, 60);

    const { roomArn } = data;
    if (!roomArn) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "roomArn is required."
      );
    }

    // Derive the region from the room ARN so the token is minted in the same
    // region the client connects to (arn:aws:ivschat:<region>:<account>:room/<id>).
    // A hardcoded region here silently breaks chat when the room lives elsewhere.
    const region = roomArn.split(":")[3] || "us-west-2";
    const client = new IvschatClient({
      region,
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      },
    });

    const userId = context.auth.uid;
    const displayName =
      context.auth.token.name ||
      (context.auth.token.email
        ? context.auth.token.email.split("@")[0]
        : userId);

    const command = new CreateChatTokenCommand({
      roomIdentifier: roomArn,
      userId,
      capabilities: ["SEND_MESSAGE"],
      attributes: { displayName },
      sessionDurationInMinutes: 60,
    });

    const response = await client.send(command);

    return {
      token: response.token,
      sessionExpirationTime: response.sessionExpirationTime?.toISOString(),
      tokenExpirationTime: response.tokenExpirationTime?.toISOString(),
    };
  });

/**
 * Returns the IVS ingest credentials for the signed-in creator's channel.
 *
 * SECURITY: The RTMP stream key is a long-lived broadcast credential and must
 * NEVER ship inside the app binary. It is stored only in the function's secret
 * environment (or a per-creator record in Firestore) and handed out here to
 * authenticated creators. The creator identity comes from the verified token,
 * never from a client-supplied field.
 */
exports.createStreamCredentials = functions
  .runWith({
    secrets: ["IVS_INGEST_ENDPOINT", "IVS_STREAM_KEY", "IVS_CHAT_ROOM_ARN"],
  })
  .https.onCall(async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "streamCreds", 20, 60);

    const uid = context.auth.uid;

    // Per-creator channel provisioning. If a creator has their own channel stored
    // in Firestore, prefer it; otherwise fall back to the shared channel secrets.
    // This keeps one authenticated code path whether you run one channel or many.
    const db = admin.firestore();
    const creatorDoc = await db.collection("creatorChannels").doc(uid).get();

    let ingestEndpoint = process.env.IVS_INGEST_ENDPOINT;
    let streamKey = process.env.IVS_STREAM_KEY;
    let chatRoomARN = process.env.IVS_CHAT_ROOM_ARN;

    if (creatorDoc.exists) {
      const d = creatorDoc.data();
      ingestEndpoint = d.ingestEndpoint || ingestEndpoint;
      streamKey = d.streamKey || streamKey;
      chatRoomARN = d.chatRoomARN || chatRoomARN;
    }

    if (!ingestEndpoint || !streamKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No streaming channel is provisioned for this account."
      );
    }

    return {
      ingestEndpoint,
      streamKey,
      chatRoomARN: chatRoomARN || "",
    };
  });

/**
 * Receives identity-verification PII and forwards it to a KYC provider.
 *
 * SECURITY: Raw government ID numbers must NOT be stored at rest here. Forward to
 * a compliant KYC vendor (Stripe Identity / Persona) and persist only a status.
 * This is a stub that records the *status* and drops the raw PII after handoff.
 */
exports.submitIdentityVerification = functions.https.onCall(
  async (data, context) => {
    assertVerifiedCaller(context);
    await enforceRateLimit(context.auth.uid, "idv", 5, 3600);

    const { legalName, idNumber, idType, countryOfIssue, dateOfBirth } = data || {};
    if (!legalName || !idNumber || !countryOfIssue || !dateOfBirth) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required verification fields."
      );
    }

    // TODO: hand `idNumber`/`legalName`/`dateOfBirth` to the KYC provider SDK here.
    // Do NOT write these raw values to Firestore.

    await admin
      .firestore()
      .collection("identityVerifications")
      .doc(context.auth.uid)
      .set(
        {
          status: "pending",
          idType: idType || "unknown",
          countryOfIssue,
          submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    return { status: "pending" };
  }
);

/**
 * Records a StoreKit transaction after server-side re-verification.
 *
 * The client sends only the App Store-signed JWS. We verify that signature
 * against Apple's public keys and read all transaction facts (id, product,
 * bundle, dates, refund status) from the *verified* payload — the client's word
 * is never trusted. Idempotent on the verified transaction id. Renewals and
 * refunds are reconciled out-of-band by App Store Server Notifications v2.
 */
exports.recordTransaction = functions.https.onCall(async (data, context) => {
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
exports.appStoreNotifications = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const signedPayload = req.body && req.body.signedPayload;
  if (!signedPayload || typeof signedPayload !== "string") {
    res.status(400).send("Missing signedPayload");
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
