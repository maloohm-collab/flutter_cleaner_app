const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
admin.initializeApp();
const db = admin.firestore();
const ADMIN_SECRET = defineSecret("ACTIVATION_ADMIN_SECRET");
function normalizePhone(input) {
 let value=String(input||"").replace(/[^0-9+]/g,"");
 if(value.startsWith("+")) value=value.slice(1);
 if(value.startsWith("00")) value=value.slice(2);
 if(value.startsWith("0")) value="962"+value.slice(1);
 if(!/^9627[789][0-9]{7}$/.test(value)) throw new HttpsError("invalid-argument","Enter a valid Jordanian mobile number.");
 return value;
}
function hash(value){return crypto.createHash("sha256").update(value).digest("hex");}
function makeCode(){return crypto.randomBytes(6).toString("hex").toUpperCase();}
exports.createActivationCode=onCall({secrets:[ADMIN_SECRET]},async(request)=>{
 if(request.data?.adminSecret!==ADMIN_SECRET.value()) throw new HttpsError("permission-denied","Not authorized.");
 const code=makeCode(), codeHash=hash(code);
 await db.collection("activationCodes").doc(codeHash).create({status:"unused",createdAt:admin.firestore.FieldValue.serverTimestamp()});
 return {code};
});
exports.redeemActivationCode=onCall(async(request)=>{
 const phone=normalizePhone(request.data?.phone), code=String(request.data?.code||"").trim().toUpperCase();
 if(!/^[A-F0-9]{12}$/.test(code)) throw new HttpsError("invalid-argument","Invalid activation code.");
 const codeRef=db.collection("activationCodes").doc(hash(code));
 const phoneHash=hash(phone), subRef=db.collection("subscriptions").doc(phoneHash);
 const expiresAt=admin.firestore.Timestamp.fromDate(new Date(Date.now()+30*24*60*60*1000));
 await db.runTransaction(async(tx)=>{
  const snap=await tx.get(codeRef);
  if(!snap.exists||snap.data().status!=="unused") throw new HttpsError("failed-precondition","Code is invalid or already used.");
  const now=admin.firestore.Timestamp.now();
  tx.update(codeRef,{status:"redeemed",phoneHash,redeemedAt:now,expiresAt});
  tx.set(subRef,{phoneHash,status:"active",activatedAt:now,expiresAt,source:"manual_whatsapp_payment"});
 });
 return {success:true,expiresAt:expiresAt.toDate().toISOString()};
});
exports.checkSubscription=onCall({enforceAppCheck:true},async(request)=>{
 const phoneHash=hash(normalizePhone(request.data?.phone));
 const snap=await db.collection("subscriptions").doc(phoneHash).get();
 if(!snap.exists)return {active:false};
 const data=snap.data(), active=data.status==="active"&&data.expiresAt.toDate().getTime()>Date.now();
 return {active,expiresAt:data.expiresAt.toDate().toISOString()};
});
