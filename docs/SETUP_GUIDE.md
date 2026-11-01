# Developer Setup Guide

Instructions target Windows, Flutter, Android Studio, and Firebase CLI.

## 1. Open the project

Open `mobile/parchipocket_flutter/` in Android Studio, the folder containing `pubspec.yaml`.

## 2. Verify Flutter and Android tools

```powershell
flutter --version
flutter doctor
flutter pub get
flutter devices
```

In Android Studio, find the SDK path at **File → Settings → Languages & Frameworks → Android SDK**. ADB is under `<Android SDK Location>\platform-tools\adb.exe`.

If an emulator shows as `offline`:
1. Do not launch the same AVD again if Android Studio says it is already running.
2. Use the full path to `adb.exe` for `kill-server`, `start-server`, and `devices -l`.
3. Stop and cold-boot the existing AVD if it remains offline.
4. Avoid **Wipe Data** unless you intend to discard virtual-device data.

## 3. Run the app

```powershell
flutter pub get
flutter run
```

The Google button is a demo route. Phone sign-in uses Firebase Auth; real SMS delivery depends on project configuration and the applicable billing plan. Use configured Firebase test numbers during development.

## 4. Run unit/widget tests and analysis

From `mobile/parchipocket_flutter`:

```powershell
flutter test --reporter compact
flutter analyze
```

## 5. Firestore Rules harness

From the repository root, with Java available:

```powershell
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-ci "node test_rules.js"
```

This harness must use a `demo-*` project ID. Never run it against production Firebase.

## 6. Dart integration tests

Start local Firestore and Auth emulators using the repository root `firebase.json`, then boot an Android emulator and run from `mobile/parchipocket_flutter`:

```powershell
flutter test integration_test/firestore_service_emulator_test.dart -d emulator-5554
```

The Android emulator connects to the host through `10.0.2.2`. If the host machine cannot start Java loopback selectors, do not count the attempt as a pass; use the GitHub Actions workflow or fix the host environment first.

## 7. Firebase configuration and deployment

The Android app config points to Firebase project `parchipocket`. Before production deployment:
- Confirm the target Firebase project in Firebase Console.
- Review the `firestore.rules` diff.
- Run both the Rules harness and Dart integration tests successfully.
- Confirm App Check providers and enforcement status separately.

Pushing to GitHub does **not** deploy Firestore rules. A manual deployment command is documented in [BACKEND_RUNBOOK.md](BACKEND_RUNBOOK.md). Do not deploy rules merely to suppress a permission error.

## Troubleshooting

- **Flutter not recognised:** add Flutter's `bin` folder to PATH and reopen Terminal.
- **ADB not found:** use the full SDK path plus `\platform-tools\adb.exe`.
- **Emulator offline:** restart ADB and stop/cold-boot the existing device; do not create duplicate AVDs as a first step.
- **Permission denied on claims index:** verify whether demo mode is accessing the cloud; for an authenticated cloud session, check whether deployed rules match reviewed repository rules.
- **Data is absent in demo mode after restart:** expected because sample demo state is in memory.


## 8. Firebase App Check setup for account deletion

The account-deletion callable is configured with `enforceAppCheck: true`. Do not deploy the updated function until both supported clients are registered and configured in the same Firebase project.

### Android app

1. In Firebase Console, open **Security → App Check → Apps** and register the Android app `com.parchipocket.app.parchipocket` with **Play Integrity** for release builds.
2. Add the SHA-256 signing-certificate fingerprint(s) for the certificates that will sign the distributed APK. Link the Play Integrity API to the same Google Cloud project when the Play Console flow requires it.
3. Debug builds use `AndroidProvider.debug`. Run a debug build, obtain the generated App Check debug token from the local device logs, and allowlist it under the Android app's **Manage debug tokens** page.
4. Treat debug tokens like passwords: keep them private, never commit them, and remove tokens that are no longer needed.

### Web account-deletion portal

The deletion page is a separate Firebase Web app client. Register a Web app in the same Firebase project and register App Check for it with the reCAPTCHA v3 provider. The current portal uses the reCAPTCHA v3 compat activation API and does not support a reCAPTCHA Enterprise site key.

In `public/delete-account/index.html`, replace these public configuration placeholders with values from the registered Firebase Web app and its App Check registration:

- `__FIREBASE_WEB_APP_ID__`: the Web app ID (not the Android app ID).
- `__FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY__`: the matching public reCAPTCHA v3 site key.

The reCAPTCHA secret key belongs only in the Firebase/Google console. Never put it in HTML or Git. The page intentionally disables OTP/deletion actions while either public setting is missing or still a placeholder. The Firebase Functions callable SDK attaches the App Check token automatically after the Web SDK is activated.

### Safe rollout order

1. Register Android and Web apps and finish provider configuration in Firebase Console.
2. Allowlist debug tokens only for testers, then install a debug APK and verify App Check tokens are issued.
3. Set the Web app ID and reCAPTCHA site key in the deletion page, deploy Hosting, and test the full web OTP/deletion flow with a disposable test account.
4. Deploy only the account-deletion function after both clients are ready:
   `firebase deploy --only functions:deleteUserAccount --project parchipocket`
5. Monitor App Check metrics and function errors before enabling any broader Firestore/Auth enforcement. Do not enable project-wide or unrelated service enforcement as part of this function-only change.

This repository change does not register Firebase apps, create a reCAPTCHA key, allowlist debug tokens, or deploy Hosting/Functions. Those are separate Firebase Console and deployment actions.
