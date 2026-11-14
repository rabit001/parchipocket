# Repository Structure

This map describes the repository layout at the current development head. The default branch is the integration target; feature and maintenance work is proposed through pull requests.

## Repository root

- .agents/skills/: repository-specific audit/fix guidance for coding agents.
- .github/workflows/: CI validation, debug build, and signed APK release workflows.
- .github/ISSUE_TEMPLATE/: structured issue forms.
- docs/: architecture, setup, backend operations, feature status, roadmap, and release guides.
- functions/: Firebase Cloud Functions Node.js package.
- mobile/parchipocket_flutter/: Flutter Android application, native Android project, and Dart tests.
- packages/speech_to_text/: repository-maintained local speech-to-text package dependency.
- ParchiPocket_Brand_Assets/: approved launcher and horizontal wordmark artwork.
- public/delete-account/: account-deletion web page source.
- scripts/: local backend validation, Firestore deployment, and Android artifact packaging.
- firebase.json: Firebase CLI configuration for rules, Functions, Hosting, and local emulators.
- firestore.rules: Firestore authorization rules.
- test_rules.js, test_deletion.js: root-level security/emulator test entry points.

## Flutter application

~~~text
mobile/parchipocket_flutter/
├── android/             # Native Android app, manifest, launcher and updater integration
├── assets/branding/     # In-app logos and launcher artwork
├── lib/
│   ├── core/            # App state, data access, monitoring and shared services
│   ├── features/        # Auth, customer, expenses, receipts, settings, updates, legacy modules
│   └── shared/          # Theme and reusable widgets
├── test/                # Unit and widget tests
└── integration_test/    # Firebase emulator-backed integration tests
~~~

Large feature screens use Dart part files. Keep feature-private helpers inside their feature library unless there is a clear reason to promote them into shared code.

## Firebase configuration files

These similarly named files serve different tools and must not be merged or deleted as duplicates:

- Repository-root firebase.json: Firebase CLI configuration for Firestore rules, Functions, Hosting, and local emulators.
- mobile/parchipocket_flutter/firebase.json: FlutterFire CLI mapping for this Flutter app.
- mobile/parchipocket_flutter/android/app/google-services.json: Android Firebase app configuration.
- mobile/parchipocket_flutter/lib/firebase_options.dart: generated Dart Firebase options.

Firebase client configuration is not a substitute for service-account credentials. Never commit service-account JSON, private keys, signing material, or local environment files.

## Local package dependency

The Flutter app uses the repository-local package at packages/speech_to_text/. This keeps the application on a reviewed source version rather than relying on an unreviewed remote patch. Changes to this package should include focused tests and a clear explanation of the upstream behaviour being adjusted.

## Compatibility export shims

Older paths such as lib/app_state.dart, lib/screens/, lib/services/, lib/theme.dart, lib/telemetry.dart, lib/widgets/ui.dart, and lib/household_expense_parser.dart may be intentional compatibility exports. Check imports and tests before removing them; do not add new implementation code to a shim.

## Build and release outputs

Flutter/Gradle build directories are ignored by Git. Local packaged APK/AAB files belong under the ignored root release-assets/android/ directory. Public Beta APKs are distributed through immutable GitHub Releases, not committed as source files.
