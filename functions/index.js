/**
 * Minimal Firebase Cloud Function stub used by AI Studio.
 * Deploy as `generateCaptionSuggestion` and secure with App Check + Auth.
 */
const functions = require("firebase-functions");

exports.generateCaptionSuggestion = functions.https.onCall((data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  const prompt = `${data.prompt || ""}`.trim();
  if (!prompt) {
    throw new functions.https.HttpsError("invalid-argument", "Prompt is required.");
  }
  const snippet = prompt.length > 72 ? `${prompt.slice(0, 72)}...` : prompt;
  return {
    caption: `New exclusive drop: ${snippet} Tap in for premium access and behind-the-scenes updates.`
  };
});
