# Developer Setup Guide

These instructions target Windows, Flutter, Android Studio, Java, Node.js, and the Firebase Emulator Suite.

## 1. Open the project

Open the repository root in your editor, then open mobile/parchipocket_flutter/ in Android Studio. The Flutter project directory is the one containing pubspec.yaml.

## 2. Install and verify tools

The repository's GitHub Actions workflows pin Flutter 3.47.9 and Java 21. Use the same versions when reproducing CI locally.

~~~powershell
flutter --version
flutter doctor
java -version
node --version
npm --version
~~~

Fetch Flutter dependencies:

~~~powershell
cd mobile/parchipocket_flutter
flutter pub get
~~~

## 3. Run the Android app

From mobile/parchipocket_flutter/:

~~~powershell
flutter devices
flutter run
~~~

The app uses Firebase Authentication and Cloud Firestore for supported authenticated sessions. Google Sign-In is integrated through Firebase Authentication. Phone sign-in uses Firebase Phone Auth; real SMS delivery depends on Phone provider configuration, quotas, allowed test numbers, and applicable billing.

Demo mode is a separate local session with in-memory sample data. It is not a cloud account or persistent ledger.

## 4. Run Flutter tests and analysis

From mobile/parchipocket_flutter/:

~~~powershell
flutter test --reporter compact
flutter analyze
~~~

## 5. Run Firestore and Auth rules tests

From the repository root, with Java available:

~~~powershell
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-phase2 "node test_rules.js"
~~~

Use a demo-* project ID for emulator tests. Never point the test harness at production Firebase.

For the repository's combined local verification command:

~~~powershell
.\scripts\verify-backend.ps1
~~~

## 6. Run Android emulator integration tests

Use the repository-root firebase.json to configure local Auth and Firestore emulators, then start an Android emulator. From mobile/parchipocket_flutter/, run:

~~~powershell
flutter test integration_test/firestore_service_emulator_test.dart -d emulator-5554 --reporter compact
flutter test integration_test/daily_log_pagination_emulator_test.dart -d emulator-5554 --reporter compact
~~~

The Android emulator connects to the host through 10.0.2.2. If an emulator fails to start or a test cannot reach the emulators, do not count the attempt as a pass. The hosted GitHub Actions workflow runs the configured integration suite for pull requests to main.

## 7. Firebase configuration and deployment

The Android app is configured for Firebase project parchipocket. Before any production deployment:

- Confirm the target project in Firebase Console.
- Review the complete firestore.rules diff.
- Run the Rules harness and relevant Dart integration tests.
- Confirm Phone provider, App Check providers, and enforcement separately.
- Deploy only the explicitly intended Firebase service.

Pushing to GitHub does not deploy Firestore rules, Cloud Functions, or Hosting. See Backend Runbook before deployment.

## 8. Firebase App Check for account deletion

The account-deletion callable uses App Check enforcement. Both supported clients must be configured in the same Firebase project before deploying the function.

### Android app

1. Register the Android app under Firebase Console → App Check.
2. Configure Play Integrity for release builds and add the SHA-256 signing-certificate fingerprints for distributed APKs.
3. Debug builds use the App Check debug provider. Allowlist debug tokens only for known development devices.
4. Treat debug tokens like passwords. Never commit or share them.

### Web account-deletion portal

The deletion page is a separate Firebase Web app client. Register the Web app and configure its App Check provider. The page intentionally disables OTP/deletion actions while required public configuration is missing or still a placeholder.

The reCAPTCHA secret key belongs only in Firebase/Google Console. Never place it in HTML or Git.

### Safe rollout order

1. Register Android and Web apps and finish provider configuration.
2. Allowlist debug tokens only for test devices and verify token issuance.
3. Configure the deletion page's public Web app/App Check values and test with a disposable account.
4. Deploy only the intended Cloud Function after both clients are ready.
5. Monitor App Check metrics and function errors before enabling broader enforcement.

These steps do not register Firebase apps, create reCAPTCHA keys, allowlist debug tokens, or deploy services automatically.

## Troubleshooting

- **Flutter not recognised:** add Flutter's bin directory to PATH and reopen the terminal.
- **Android SDK tools missing:** verify the SDK path in Android Studio settings.
- **Emulator offline:** stop and cold-boot the existing AVD; avoid wiping data unless intentional.
- **Permission denied:** determine whether the request is expected to use demo mode or an authenticated cloud session, then inspect the deployed rules for the intended Firebase project.
- **Demo data disappears after restart:** expected; demo state is in memory.
