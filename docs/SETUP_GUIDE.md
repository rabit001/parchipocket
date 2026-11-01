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

The Google button is a demo route. Phone sign-in uses Firebase Auth; real SMS delivery depends on Phone provider configuration and the applicable billing plan. Use configured Firebase test numbers during development.

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

## 6. Android emulator integration tests

Use the repository-root `firebase.json` to configure local Auth and Firestore emulators, then start an Android emulator. From `mobile/parchipocket_flutter`, run:

```powershell
flutter test integration_test/firestore_service_emulator_test.dart -d emulator-5554 --reporter compact
flutter test integration_test/daily_log_pagination_emulator_test.dart -d emulator-5554 --reporter compact
```

The Android emulator connects to the host through `10.0.2.2`. If the host machine cannot start Java loopback selectors, do not count the attempt as a pass; use the GitHub Actions workflow or fix the host environment first.

For the same checks in one command, run `.\scripts\verify-backend.ps1` from the repository root for unit/widget tests, analysis, and rules checks. The hosted GitHub Actions workflow additionally runs both Android emulator integration tests.

## 7. Firebase configuration and deployment

The Android app config points to Firebase project `parchipocket`. Before production deployment:
- Confirm the target Firebase project in Firebase Console.
- Review the `firestore.rules` diff.
- Run the Rules harness and both Dart integration tests successfully.
- Confirm Phone provider, App Check providers, and enforcement status separately.

Pushing to GitHub does **not** deploy Firestore rules or Functions. A manual deployment command is documented in [BACKEND_RUNBOOK.md](BACKEND_RUNBOOK.md). Do not deploy rules merely to suppress a permission error.

## Troubleshooting

- **Flutter not recognised:** add Flutter's `bin` folder to PATH and reopen Terminal.
- **ADB not found:** use the full SDK path plus `\platform-tools\adb.exe`.
- **Emulator offline:** restart ADB and stop/cold-boot the existing device; do not create duplicate AVDs as a first step.
- **Permission denied on claims index:** verify whether demo mode is accessing the cloud; for an authenticated cloud session, check whether deployed rules match reviewed repository rules.
- **Data is absent in demo mode after restart:** expected because sample demo state is in memory.
