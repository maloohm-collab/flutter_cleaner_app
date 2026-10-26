const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

function normalizePhone(input) {
  let value = String(input || "").replace(/[^0-9+]/g, "");
  if (value.startsWith("+")) value = value.slice(1);
  if (value.startsWith("00")) value = value.slice(2);
  if (value.startsWith("0")) value = "962" + value.slice(1);
  if (!/^9627[789][0-9]{7}$/.test(value)) {
    throw new HttpsError("invalid-argument", "Enter a valid Jordanian mobile number.");
  }
  return value;
}

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

exports.redeemActivationCode = onCall(async (request) => {
  const phone = normalizePhone(request.data?.phone);
  const code = String(request.data?.code || "").trim().toUpperCase();
  if (!/^[A-F0-9]{12}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Invalid activation code.");
  }

  const phoneHash = hash(phone);
  const codeRef = db.collection("activationCodes").doc(hash(code));
  const subRef = db.collection("subscriptions").doc(phoneHash);
  const attemptRef = db.collection("activationAttempts").doc(phoneHash);
  const nowMs = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(nowMs + 30 * 24 * 60 * 60 * 1000)
  );

  await db.runTransaction(async (tx) => {
    const attemptSnap = await tx.get(attemptRef);
    const attemptData = attemptSnap.exists ? attemptSnap.data() : {};
    const windowStart = Number(attemptData.windowStartMs || 0);
    const count = nowMs - windowStart < 60 * 60 * 1000
      ? Number(attemptData.count || 0)
      : 0;

    if (count >= 10) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many attempts. Please try again in one hour."
      );
    }

    const codeSnap = await tx.get(codeRef);
    if (!codeSnap.exists || codeSnap.data().status !== "unused") {
      tx.set(attemptRef, {
        count: count + 1,
        windowStartMs: count === 0 ? nowMs : windowStart,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      throw new HttpsError("failed-precondition", "Code is invalid or already used.");
    }

    const now = admin.firestore.Timestamp.now();
    tx.update(codeRef, {
      status: "redeemed",
      phoneHash,
      redeemedAt: now,
      expiresAt
    });
    tx.set(subRef, {
      phoneHash,
      status: "active",
      activatedAt: now,
      expiresAt,
      source: "manual_whatsapp_payment"
    });
    tx.delete(attemptRef);
  });

  return { success: true, expiresAt: expiresAt.toDate().toISOString() };
});

exports.checkSubscription = onCall(async (request) => {
  const phoneHash = hash(normalizePhone(request.data?.phone));
  const snap = await db.collection("subscriptions").doc(phoneHash).get();
  if (!snap.exists) return { active: false };

  const data = snap.data();
  if (!data.expiresAt || typeof data.expiresAt.toDate !== "function") {
    throw new HttpsError("internal", "Subscription record is incomplete.");
  }
  const active = data.status === "active" && data.expiresAt.toDate().getTime() > Date.now();
  return { active, expiresAt: data.expiresAt.toDate().toISOString() };
});
