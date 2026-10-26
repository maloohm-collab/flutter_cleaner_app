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
  console.log("\nActivation code (show to the customer once): " + code);
  console.log("This code expires 30 days after successful redemption. Store it securely.\n");
}

main().catch((error) => {
  console.error("Could not create activation code:", error.message);
  process.exitCode = 1;
});
