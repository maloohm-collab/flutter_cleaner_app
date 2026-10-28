# AI Optimizer — Firebase setup

## Create Firebase project
1. Create a new project at https://console.firebase.google.com/.
2. Add an Android app using the exact applicationId in android/app/build.gradle or build.gradle.kts.
3. Download google-services.json to android/app/google-services.json.
4. On a trusted computer run:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select the new project and Android. This generates lib/firebase_options.dart.
5. Enable Cloud Firestore and App Check in Firebase Console.
6. Deploy the deny-by-default rules in firebase/firestore.rules.
7. Deploy callable functions from `firebase/functions` (see commands below). The app requires both `redeemActivationCode` and `checkSubscription` to be deployed.
8. For normal paid subscriptions, manually verify each 2 JOD payment and issue a unique code with `npm run generate-code`.
9. The agreed legacy code `AICLEANER0000` is registered separately, one time, for phone `0780494789` only. Run `node register-agreed-code.js` from `firebase/functions` on a trusted computer after Firebase Admin credentials are configured. It cannot activate another phone.

## Activation model
- WhatsApp: +962780494789 (local 0780494789).
- User enters Jordanian mobile number and unique activation code.
- Trusted backend redeems the code atomically once, binds it to a normalized phone, and sets expiry to 30 days.
- Client-side activation is intentionally blocked until Firebase config and backend deployment are completed.

## Deploy activation backend (trusted computer only)
```sh
cd firebase/functions
npm install
# Register the agreed code once, if it has not already been registered:
node register-agreed-code.js
# Deploy both callable functions:
cd ../..
firebase deploy --only functions
```

The fixed code is not accepted by format alone: its hashed Firestore record must exist, be unused, and match the registered phone. The code can be redeemed once and the subscription lasts 30 days. Do not put Firebase service-account credentials in GitHub or the APK. Deployment must be performed by someone with access to the Firebase project.

## Build
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Android limits access to other apps' private cache. Do not promise deleting protected app data; show supported system settings instead.
