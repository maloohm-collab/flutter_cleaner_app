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
7. Deploy callable functions in firebase/functions. Set ACTIVATION_ADMIN_SECRET in Secret Manager; never embed it in APK or public client code.
8. Manually verify each 2 JOD payment before issuing a unique code.

## Activation model
- WhatsApp: +962780494789 (local 0780494789).
- User enters Jordanian mobile number and unique activation code.
- Trusted backend redeems the code atomically once, binds it to a normalized phone, and sets expiry to 30 days.
- Client-side activation is intentionally blocked until Firebase config and backend deployment are completed.

## Build
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Android limits access to other apps' private cache. Do not promise deleting protected app data; show supported system settings instead.
