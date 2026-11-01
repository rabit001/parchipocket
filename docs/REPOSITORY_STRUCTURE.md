# Repository Structure

ParchiPocket is a Flutter Android application backed by Firebase. This map reflects the current `main` branch.

## Repository root

- `.github/workflows/`: CI validation and debug APK release automation.
- `.agents/skills/`: repository-specific audit/fix guidance for coding agents.
- `docs/`: architecture, setup, backend operations, feature status, roadmap, and release guides.
- `functions/`: Firebase Cloud Functions Node.js package.
- `mobile/parchipocket_flutter/`: Flutter application, Android project, and Dart tests.
- `public/delete-account/`: public account-deletion page.
- `scripts/`: local backend validation, Firestore deployment, and Android artifact packaging.
- `firebase.json`: Firebase CLI configuration for rules, Functions, Hosting, and local emulators.
- `firestore.rules`: Firestore authorization rules.
- `test_rules.js`, `test_deletion.js`: root-level security/emulator test entry points.

## Flutter application

```text
lib/
├── core/
│   ├── data/                 # Firestore persistence and data access
│   ├── monitoring/           # Telemetry sanitization and reporting
│   └── state/
│       ├── app_state.dart    # Application/session state coordinator
│       └── models/           # Shared app and household-expense models
├── features/
│   ├── account_deletion/data/
│   ├── auth/presentation/    # Session, sign-in/OTP, onboarding
│   ├── customer/presentation/# Current Home & Family experience
│   ├── expenses/domain/     # Household expense parsing
│   ├── receipts/presentation/
│   ├── settings/presentation/
│   ├── shop_owner/presentation/ # Retained; paused in current navigation
│   └── street_vendor/presentation/ # Retained; paused in current navigation
└── shared/
    ├── theme/
    └── widgets/
```

Large feature screens use Dart `part` files. Keep feature-private helpers inside their feature library unless there is a clear reason to promote them into shared code.

## Flutter tests

- `test/core/`: app state, security/App Check, and telemetry.
- `test/features/account_deletion/`: account-deletion client behaviour.
- `test/features/expenses/`: expense state, model, parser, query, pagination, and UI.
- `test/features/receipts/`: receipt-claim/query behaviour.
- `test/features/shop_owner/`: retained seller-mode behaviour.
- `test/shared/`: shared theme/UI.
- `integration_test/`: Firebase emulator integration and Daily Log pagination scenarios.

Flutter recursively discovers `*_test.dart` files under `test/`.

## Firebase configuration files

These similarly named files serve different tools and must not be merged or deleted as duplicates:

- Repository-root `firebase.json`: Firebase CLI configuration for emulators, Firestore rules, Functions, and Hosting.
- `mobile/parchipocket_flutter/firebase.json`: FlutterFire CLI mapping for this Flutter app.
- `mobile/parchipocket_flutter/android/app/google-services.json`: Android Firebase app configuration.
- `mobile/parchipocket_flutter/lib/firebase_options.dart`: generated Dart Firebase options.

## Compatibility export shims

The old paths `lib/app_state.dart`, `lib/screens/*`, `lib/services/*`, `lib/theme.dart`, `lib/telemetry.dart`, `lib/widgets/ui.dart`, and `lib/household_expense_parser.dart` are intentionally small export shims. They preserve older import paths while the implementation lives under `core/`, `features/`, and `shared/`. Keep them until all external/older imports have been migrated and tests prove they can be removed.

## Firebase Functions

`functions/index.js` is intentionally retained as the configured package entry point. It forwards to the implementation under `functions/src/account_deletion/index.js`.

## Build and release outputs

Flutter/Gradle build directories are ignored by Git. Local packaged APK/AAB files belong under the root `release-assets/android/` directory (also ignored). Public test APKs are distributed through GitHub Releases, not committed as source files.
