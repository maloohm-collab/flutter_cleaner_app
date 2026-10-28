const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

function normalizePhone(input) {
  let value = String(input || "").trim().replace(/[\\s().-]/g, "");
  if (value.startsWith("+")) value = value.slice(1);
  if (value.startsWith("00")) value = value.slice(2);
  // Keep support for Jordanian local mobile numbers such as 0780494789.
  // Other countries must enter the number with its international country code.
  if (/^0[0-9]{9}$/.test(value)) {
    value = "962" + value.slice(1);
  }
  // Accept international numbers in E.164 digit form (8–15 digits).
  if (!/^[1-9][0-9]{7,14}$/.test(value)) {
    throw new HttpsError(
      "invalid-argument",
      "Enter a valid phone number with the international country code, e.g. +962780494789."
    );
  }
  return value;
}

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

// Shared activation code agreed for the current release. It activates the
// phone supplied by each customer independently; it is intentionally reusable
// across different phone numbers until the owner changes this server-side value.
// Note: anyone who knows this shared code can activate a 30-day subscription.
const SHARED_ACTIVATION_CODE = "AICLEANER0000";

exports.redeemActivationCode = onCall(async (request) => {
  const phone = normalizePhone(request.data?.phone);
  const code = String(request.data?.code || "").trim().toUpperCase();
  // Accept generated 12-character hex codes and the agreed legacy code format.
  // A format match alone never activates a subscription: the hashed code must
  // exist as an unused record in Firestore.
  const phoneHash = hash(phone);

  // Reusable shared code: create/refresh a separate 30-day subscription for
  // every valid phone number. It is not consumed by the first customer.
  if (code === SHARED_ACTIVATION_CODE) {
    const sharedSubRef = db.collection("subscriptions").doc(phoneHash);
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    );
    await db.runTransaction(async (tx) => {
      tx.set(sharedSubRef, {
        phoneHash,
        status: "active",
        activatedAt: now,
        expiresAt,
        source: "shared_activation_code"
      });
    });
    return { success: true, expiresAt: expiresAt.toDate().toISOString(), restored: false };
  }

  if (!/^[A-F0-9]{12}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Invalid activation code.");
  }
  const codeRef = db.collection("activationCodes").doc(hash(code));
  const subRef = db.collection("subscriptions").doc(phoneHash);
  const attemptRef = db.collection("activationAttempts").doc(phoneHash);
  const nowMs = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(nowMs + 30 * 24 * 60 * 60 * 1000)
  );

  const redeemed = await db.runTransaction(async (tx) => {
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
    if (codeSnap.exists) {
      const codeData = codeSnap.data();
      if (codeData.allowedPhoneHash && codeData.allowedPhoneHash !== phoneHash) {
        tx.set(attemptRef, {
          count: count + 1,
          windowStartMs: count === 0 ? nowMs : windowStart,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return { success: false };
      }

      // Allow the same customer to restore activation after a local logout.
      // A redeemed code can never be transferred to a different phone number.
      if (codeData.status === "redeemed" && codeData.phoneHash === phoneHash) {
        const subSnap = await tx.get(subRef);
        const subData = subSnap.exists ? subSnap.data() : {};
        const currentExpiry = subData.expiresAt;
        if (
          subData.status === "active" &&
          currentExpiry &&
          typeof currentExpiry.toDate === "function" &&
          currentExpiry.toDate().getTime() > nowMs
        ) {
          return {
            success: true,
            expiresAt: currentExpiry.toDate().toISOString(),
            restored: true
          };
        }
      }
    }

    if (!codeSnap.exists || codeSnap.data().status !== "unused") {
      tx.set(attemptRef, {
        count: count + 1,
        windowStartMs: count === 0 ? nowMs : windowStart,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return { success: false };
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
    return {
      success: true,
      expiresAt: expiresAt.toDate().toISOString(),
      restored: false
    };
  });

  if (!redeemed.success) {
    const latestAttempt = await attemptRef.get();
    if (latestAttempt.exists && Number(latestAttempt.data().count || 0) >= 10) {
      throw new HttpsError("resource-exhausted", "Too many attempts. Please try again in one hour.");
    }
    throw new HttpsError("failed-precondition", "Code is invalid, expired, or already used for another phone.");
  }

  return {
    success: true,
    expiresAt: redeemed.expiresAt,
    restored: redeemed.restored === true
  };
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
