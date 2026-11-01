# ParchiPocket Android app

ParchiPocket is a Flutter Android app. The current development focus is Home & Family spending: record daily purchases, review a household log, and see category totals. Firebase Authentication and Cloud Firestore are integrated for authenticated sessions and cloud data.

This is a development/debug-preview build, not a production accounting service.

## Current app behaviour

- **Phone sign-in:** uses Firebase Authentication phone verification. Real SMS delivery requires Phone provider configuration and an eligible Firebase plan. Use configured Firebase test numbers while developing.
- **Google sign-in:** the Google button is still a demo route, not completed Google OAuth.
- **Demo mode:** uses local sample data in memory and must not be treated as a real account or ledger.
- **Home & Family:** manual and voice-assisted household purchase entry, daily log, and category totals.
- **Legacy seller features:** Shop Owner and Street Vendor source files remain for future work and compatibility, but those role flows are paused in the current onboarding/navigation.
- **Receipts:** receipt-claim functionality remains available as a secondary flow. PDF export, production printer support, live nearby-shop discovery, push notifications, and robust offline sync are not production-complete.

## Run on Windows

Open PowerShell in this folder, the one containing `pubspec.yaml`:

```powershell
flutter doctor
flutter pub get
flutter devices
flutter run
```

For a USB-connected Android phone, enable Developer Options and USB debugging, then accept the computer authorization prompt on the phone.

## Validate the app

From this folder:

```powershell
flutter test --reporter compact
flutter analyze
```

The repository-level verification script runs Flutter tests, analysis, and the Firestore rules harness:

```powershell
cd ..\..
.\scripts\verify-backend.ps1
```

For the full Android emulator integration suite, use GitHub Actions or an online Android emulator. The CI workflow runs both Firestore/Auth integration tests and the Daily Log pagination test.

## Firebase configuration files

There are two different Firebase configuration files and they are not duplicates:

- Repository-root `firebase.json`: Firebase CLI configuration for Firestore rules, Functions, Hosting, and local emulators.
- This folder's `firebase.json`: FlutterFire CLI platform mapping for the Android app.
- `android/app/google-services.json` and `lib/firebase_options.dart`: generated Android/Dart Firebase app configuration.

Publishing code to GitHub does not deploy Firestore rules or Functions to Firebase. See `docs/BACKEND_RUNBOOK.md` before any production deployment.

## Project layout

- `lib/core/`: shared app state, Firestore access, and telemetry.
- `lib/features/`: auth, customer, expenses, receipts, settings, account deletion, and retained seller/vendor modules.
- `lib/shared/`: theme and reusable widgets.
- `test/`: unit and widget tests grouped by responsibility.
- `integration_test/`: emulator-backed Firebase and Daily Log tests.
- `android/`: native Android project and resources.

A few old import paths at the top of `lib/` are compatibility export shims. They intentionally forward to the canonical files under `core/`, `features/`, and `shared/`; do not add new implementation code there.

## Latest debug build

The latest published debug APK is on the GitHub Releases page:

[Open the latest ParchiPocket debug release](https://github.com/rabit001/parchipocket/releases)

The APK is debug-signed and is intended for testing. It is not a Play Store production release.
