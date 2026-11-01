# Repository Structure

ParchiPocket is a Flutter Android application backed by Firebase. This guide describes the current repository layout and where new code belongs.

## Repository root

- `.github/workflows/`: continuous integration and validation.
- `.agents/skills/`: repository-specific audit and fix guidance.
- `docs/`: project overview, architecture, setup, operations, and release guidance.
- `functions/`: Firebase Cloud Functions Node.js package.
- `mobile/parchipocket_flutter/`: Flutter application, Android project, and Dart tests.
- `public/delete-account/`: public account-deletion page source.
- `scripts/`: local verification and Firebase rules helper scripts.
- `firebase.json`, `firestore.rules`: Firebase emulator/deployment configuration and authorization rules.
- `test_deletion.js`, `test_rules.js`: root-level backend/security emulator test entry points.

## Flutter application

```text
lib/
├── core/
│   ├── data/                 # Firestore persistence and data access
│   ├── monitoring/           # Crashlytics and Performance isolation
│   └── state/
│       ├── app_state.dart    # application/session state coordinator
│       └── models/           # app types and household expense models
├── features/
│   ├── account_deletion/data/
│   ├── auth/presentation/
│   │   └── auth_screens/     # session, sign-in/OTP, onboarding
│   ├── customer/presentation/
│   │   └── customer_screens/ # home, expenses, bills, insights, shops, profile
│   ├── expenses/domain/
│   ├── receipts/presentation/
│   ├── settings/presentation/
│   │   └── common_screens/   # settings, support, receipt sharing, account, misc
│   ├── shop_owner/presentation/
│   │   └── shop_screens/     # home, billing, history, expenses, udhaar, reports, printer
│   └── street_vendor/presentation/
│       └── vendor_screens/   # home, sales, profile
└── shared/
    ├── theme/
    └── widgets/
```

Large screen libraries use Dart `part` files to group related screen classes while keeping one public library per feature. This preserves private helper visibility within the feature and keeps existing route imports simple.

The old `lib/app_state.dart`, `lib/screens/*`, `lib/services/*`, `lib/theme.dart`, `lib/telemetry.dart`, `lib/widgets/ui.dart`, and `lib/household_expense_parser.dart` paths are small compatibility exports. New app code should import from `core/`, `features/`, and `shared/`.

## Flutter tests

- `test/core/`: state, security, and telemetry.
- `test/features/account_deletion/`: account deletion client.
- `test/features/expenses/`: expense state, model, parser, query, pagination, and UI.
- `test/features/receipts/`: receipt claim/query.
- `test/features/shop_owner/`: shop-owner mode.
- `test/shared/`: shared theme/UI.

The Flutter test runner discovers `*_test.dart` files recursively under `test/`.

## Firebase Functions

`functions/index.js` is intentionally retained as the configured package entry point. It forwards to `functions/src/account_deletion/index.js`. This preserves the Firebase package contract while locating implementation code under `src/`.

## Validation

From repository root, install the Functions dependencies once:

```powershell
npm --prefix functions ci
```

Run the deletion and rules harnesses inside isolated local Auth and Firestore emulators:

```powershell
npx --yes firebase-tools@latest emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_deletion.js"
npx --yes firebase-tools@latest emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_rules.js"
```

From `mobile/parchipocket_flutter/`:

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

Use only documented `demo-*` Firebase project IDs for emulator tests. Pushing a branch or updating a pull request does not deploy Firebase services.
