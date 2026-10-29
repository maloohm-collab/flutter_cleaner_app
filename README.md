# AI Optimizer

## Activation
- Activation is code-only. No phone number or phone binding is required.
- The current code is `AICLEANER0000`.
- A successful activation stores a 30-day expiry locally on the device.
- The app does not require Firebase Cloud Functions deployment for activation.
- WhatsApp support: +962780494789 (local 0780494789).

## Important limitation
This simple activation mode keeps the code in the app and stores the expiry on the device. It is suitable for a basic low-cost setup, but it is not tamper-resistant: a determined user could extract the code or alter local app data. Server-side enforcement would require a backend.

## Build
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Android limits access to other apps' private cache. Do not promise deleting protected app data; show supported system settings instead.
