// Run once on a trusted administrator computer after Firebase ADC login.
// This registers the agreed legacy activation code for the phone entered in the
// activation screenshot. The code is one-time-use and cannot be transferred.
//   gcloud auth application-default login
//   node register-agreed-code.js
// Never run this script from the Android app or expose service-account credentials.

const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp({ projectId: "ai-optimizer-jordan" });
const db = admin.firestore();

const code = "AICLEANER0000";
const normalizedPhone = "962780494789"; // 0780494789
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");

async function main() {
  const codeHash = hash(code);
  const allowedPhoneHash = hash(normalizedPhone);
  const ref = db.collection("activationCodes").doc(codeHash);
  try {
    await ref.create({
      status: "unused",
      allowedPhoneHash,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "agreed_legacy_code"
    });
    console.log("Agreed activation code registered for 0780494789.");
    console.log("It can be redeemed once and is valid for 30 days after activation.");
  } catch (error) {
    if (error.code === 6 || error.code === "already-exists") {
      console.log("The agreed code record already exists; no changes were made.");
      return;
    }
    throw error;
  }
}

main().catch((error) => {
  console.error("Could not register agreed activation code:", error.message);
  process.exitCode = 1;
});
