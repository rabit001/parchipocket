# ParchiPocket Android App

ParchiPocket is a Flutter Android app for recording household purchases, reviewing daily spending, and viewing category totals. The app uses Firebase Authentication and Cloud Firestore for supported cloud accounts.

The current distribution is a signed Beta APK, not a Play Store production release.

## Current app behaviour

- **Google Sign-In:** integrated through Firebase Authentication.
- **Phone sign-in:** uses Firebase Phone Auth; real SMS delivery depends on Firebase provider setup, quotas, test numbers, and applicable billing.
- **Profile contact number:** editable profile field; saving a number does not verify ownership.
- **Profile photo:** custom photos are stored in private app storage on the current device and are not cloud-synchronised.
- **Demo mode:** local in-memory sample data; it is not a persistent cloud account.
- **Home & Family:** manual and voice-assisted household purchase entry, daily log, and category totals.
- **Beta updates:** checks for a newer published Beta on fresh app launches and hands off verified APKs to Android's installer.
- **Legacy seller features:** Shop Owner and Street Vendor source modules remain for compatibility, but their role flows are paused in current navigation.
- **Receipts:** QR/manual receipt-claim functionality remains available. PDF export, live shop discovery, production printer support, push notifications, and robust offline sync are not production-complete.

## Run on Windows

Open PowerShell in this folder, the one containing pubspec.yaml:

~~~powershell
flutter doctor
flutter pub get
flutter devices
flutter run
~~~

## Validate the app

~~~powershell
flutter test --reporter compact
flutter analyze
~~~

The repository-level verification script runs Flutter tests, analysis, and the Firestore rules harness:

~~~powershell
cd ..\..
.\scripts\verify-backend.ps1
~~~

For Android emulator integration tests, use the configured GitHub Actions workflow or a local emulator with the Firebase Auth and Firestore emulators available.

## Firebase configuration files

These files serve different tools and are not duplicates:

- Repository-root firebase.json: Firebase CLI configuration for Firestore rules, Functions, Hosting, and local emulators.
- This folder's firebase.json: FlutterFire CLI platform mapping for the Android app.
- android/app/google-services.json and lib/firebase_options.dart: generated Android/Dart Firebase app configuration.

Publishing code to GitHub does not deploy Firestore rules, Functions, or Hosting. See the repository's Backend Runbook before any production deployment.

## Project layout

- lib/core/: shared app state, Firestore access, and telemetry.
- lib/features/: auth, customer, expenses, receipts, settings, app updates, account deletion, and retained seller/vendor modules.
- lib/shared/: theme and reusable widgets.
- test/: unit and widget tests grouped by responsibility.
- integration_test/: emulator-backed Firebase and Daily Log tests.
- android/: native Android project and launcher/update resources.

Older import paths at the top of lib/ may be compatibility export shims. They forward to canonical files under core/, features/, and shared/. Do not add new implementation code to a shim.
