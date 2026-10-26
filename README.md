# AI Optimizer / Flutter Cleaner

Android Flutter app for cautious storage scanning and cleanup. Paid access is planned as a manually approved monthly subscription: 2 JOD, requested through WhatsApp, with a unique single-use code bound to a phone number.

## Firebase setup (new project)

1. Create a project in the [Firebase Console](https://console.firebase.google.com/), e.g. `ai-optimizer-jordan`.
2. Add an Android app using the exact `applicationId` from `android/app/build.gradle` or `android/app/build.gradle.kts`. Do not guess this ID.
3. Download `google-services.json` and place it at `android/app/google-services.json`. Do not commit this file to a public repository if you prefer to keep project identifiers out of public source.
4. Install/use the Firebase CLI and FlutterFire CLI locally, then run:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select the new Firebase project and Android platform. This generates `lib/firebase_options.dart`; check it locally and do not publish secrets or private configuration unnecessarily.
5. Enable **Cloud Firestore** in Firebase Console.
6. Deploy the Firestore rules in `firebase/firestore.rules` using Firebase CLI after reviewing them. The app must not let anonymous clients create or mark their own activations as paid/active.
7. Deploy the callable functions in `firebase/functions` with Firebase CLI. They are the trusted layer for redeeming codes, checking expiry and binding a code to a normalized phone number.
8. For each paid request, manually verify the 2 JOD payment, then create a unique code using a trusted admin-only process. Never put an admin secret or code-generation secret inside the APK or public client code.

## Activation flow

- User enters phone number and the unique code.
- App calls a trusted backend function; code redemption must be atomic, single-use and linked to the normalized phone number.
- The subscription expires one calendar month after successful redemption (backend UTC timestamp).
- WhatsApp contact: `+962780494789` (local display: `0780494789`).
- This repository contains the client integration scaffolding; activation is intentionally blocked until Firebase config and trusted backend deployment are completed.

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Do not claim the app can clear other apps' private cache directly. Android limits this for ordinary applications; use supported system settings and only delete shared files after preview and user confirmation.
