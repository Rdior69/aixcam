"use strict";

const { logger } = require("firebase-functions");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const serverTimestamp = admin.firestore.FieldValue.serverTimestamp;

exports.onCreatorProfilePublished = onDocumentWritten("creatorProfiles/{uid}", async (event) => {
  const before = event.data && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data && event.data.after.exists ? event.data.after.data() : null;

  if (!after || after.isPublished !== true || (before && before.isPublished === true)) {
    return;
  }

  const uid = event.params.uid;
  await db.collection("publicCreatorProfiles").doc(uid).set({
    uid,
    displayName: after.displayName,
    username: after.username,
    biography: after.biography,
    profilePhotoPath: after.profilePhotoPath,
    coverImagePath: after.coverImagePath,
    theme: after.theme,
    customProfileURL: after.customProfileURL,
    publishedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }, { merge: true });

  logger.info("Published creator profile materialized", { uid });
});

exports.onMediaCreated = onDocumentCreated("creatorProfiles/{uid}/media/{mediaId}", async (event) => {
  const media = event.data.data();
  const thumbnailStatus = media.kind === "Video" ? "queued" : "notRequired";

  await event.data.ref.set({
    moderationStatus: "pending",
    thumbnailStatus,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }, { merge: true });

  logger.info("Creator media metadata initialized", {
    uid: event.params.uid,
    mediaId: event.params.mediaId,
    kind: media.kind,
  });
});

exports.onAIJobCreated = onDocumentCreated("creatorProfiles/{uid}/aiJobs/{jobId}", async (event) => {
  const job = event.data.data();

  await event.data.ref.set({
    status: "queued",
    queuedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }, { merge: true });

  await db.collection("cloudFunctionRequests").doc(event.params.jobId).set({
    ownerId: event.params.uid,
    aiJobPath: event.data.ref.path,
    type: job.type || "batchEdit",
    status: "queued",
    createdAt: serverTimestamp(),
  }, { merge: true });

  logger.info("AI job queued", {
    uid: event.params.uid,
    jobId: event.params.jobId,
    type: job.type,
  });
});

exports.onAnalyticsRollup = onDocumentWritten("creatorProfiles/{uid}/media/{mediaId}", async (event) => {
  const uid = event.params.uid;
  const mediaSnapshot = await db.collection("creatorProfiles").doc(uid).collection("media").count().get();
  const mediaCount = mediaSnapshot.data().count;

  await db.collection("creatorProfiles").doc(uid).collection("analytics").doc("summary").set({
    mediaCount,
    updatedAt: serverTimestamp(),
  }, { merge: true });

  logger.info("Creator analytics summary updated", { uid, mediaCount });
});
