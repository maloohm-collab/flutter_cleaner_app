# AI Optimizer — Firebase activation setup

## Activation flow
- The app calls `redeemActivationCode` after the customer enters their Jordanian mobile number and a paid activation code.
- A successful redemption activates the phone-number subscription for 30 days.
- The app calls `checkSubscription` at startup. An expired or missing subscription does not unlock the app.
- Firestore client access to `activationCodes` and `subscriptions` must remain denied by the deployed rules. Cloud Functions use the Admin SDK and are not restricted by client rules.

## Create codes securely
Do not expose a code-generation callable function or put an admin secret/service-account key in the mobile app or GitHub.

On a trusted administrator computer with Node.js 20 and Google Cloud CLI installed:

1. Open a terminal in `firebase/functions`.
2. Run `npm install`.
3. Sign in with the administrator's Google account that has the minimum required Firestore permissions:
   `gcloud auth application-default login`
4. Run `npm run generate-code`.
5. Give the displayed code privately to the customer after payment. Do not save the plain code in GitHub.

The generator stores only a SHA-256 hash of the code in Firestore. Treat the generated plain code as a one-time secret.

## Before deployment
1. Confirm Firebase project `ai-optimizer-jordan` and billing/plan eligibility for Cloud Functions.
2. Deploy the Firestore rules and functions from the repository root using Firebase CLI.
3. Test a valid code, a wrong code, a reused code, an invalid Jordanian phone number, and subscription expiry.
4. Do not treat the service as production-ready until abuse controls and function logs have been reviewed. The current failed-attempt limit is keyed by phone number and is not a complete anti-abuse system.
