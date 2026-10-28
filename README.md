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
7. Deploy callable functions from `firebase/functions`. The app requires both `redeemActivationCode` and `checkSubscription` to be deployed.
8. The current shared code is `AICLEANER0000`: it can be used for international phone numbers from different countries. Enter the number with its country calling code (for example, `+962780494789` or `+14155552671`); Jordanian local mobile format such as `0780494789` is also supported. Each normalized number gets its own 30-day subscription record. Anyone who knows this shared code can activate a subscription, so change the server-side code when you decide to rotate it.
9. The alternative generated-code flow remains available for unique, one-time codes.

## Activation model
- WhatsApp: +962780494789 (local 0780494789).
- User enters a phone number with its international country calling code and an activation code; Jordanian local mobile format is also accepted.
- Trusted backend redeems the code atomically once, binds it to a normalized phone, and sets expiry to 30 days.
- Client-side activation is intentionally blocked until Firebase config and backend deployment are completed.

## Deploy activation backend

The Cloud Functions must be deployed by an account with access to the Firebase project. The shared code is validated by the backend; it is not consumed after one phone uses it. Each normalized international phone number has an independent subscription expiry. The GitHub Actions deploy workflow currently runs only from `main` and requires the `FIREBASE_SERVICE_ACCOUNT_JSON` repository secret.

## Build
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Android limits access to other apps' private cache. Do not promise deleting protected app data; show supported system settings instead.
