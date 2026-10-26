// Run only on a trusted administrator's computer.
// Authenticate with Application Default Credentials before running:
//   gcloud auth application-default login
// Then, from this directory:
//   npm run generate-code
// Never place service-account keys or generated codes in the app or source control.

const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp({ projectId: "ai-optimizer-jordan" });

const db = admin.firestore();
const code = crypto.randomBytes(6).toString("hex").toUpperCase();
const codeHash = crypto.createHash("sha256").update(code).digest("hex");

async function main() {
  await db.collection("activationCodes").doc(codeHash).create({
    status: "unused",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    source: "trusted_admin_cli"
  });
  console.log("\nActivation code (provide to the paid customer privately): " + code);
  console.log("The subscription lasts 30 days from successful redemption.\n");
}

main().catch((error) => {
  console.error("Could not create activation code:", error.message);
  process.exitCode = 1;
});
