<div align="center">

# ParchiPocket

### Everyday spending, easier to track.

A Flutter Android app focused on helping households record daily purchases, review spending activity, and understand category-wise totals.

[![Backend validation](https://github.com/rabit001/parchipocket/actions/workflows/backend-validation.yml/badge.svg)](https://github.com/rabit001/parchipocket/actions/workflows/backend-validation.yml)
[![Flutter](https://img.shields.io/badge/Client-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com/)

**Created by [Rabit Mansuri](https://github.com/rabit001)**

[View latest debug build](https://github.com/rabit001/parchipocket/releases) · [Report an issue](https://github.com/rabit001/parchipocket/issues)

</div>

---

## Overview

ParchiPocket is a **mobile-first household expense tracker**. The current development focus is the Home & Family experience: record a purchase, review the details, save it, and follow daily spending and monthly category totals.

The app supports manual purchase entry and a voice-assisted entry flow. Voice input is transcribed and parsed on-device, then presented for review and confirmation before saving.

ParchiPocket is actively under development. The available Android APK is a **debug preview**, not a production Play Store release or a production accounting service.

## Current features

| Area | Current implementation |
| --- | --- |
| Household purchases | Manual entry with editable fields and confirmation before saving |
| Voice-assisted entry | Speech recognition and local phrase parsing for one purchase per utterance |
| Daily spending | Daily log and current-month spending totals |
| Category insights | Totals calculated from saved household entries |
| Cloud data | Firebase Authentication and owner-scoped Cloud Firestore records |
| Demo mode | Explicit local session using in-memory sample data |
| Receipt sharing | Existing QR/manual receipt-claim flow remains available as a secondary feature |

### Product scope

The current app experience prioritises **Home & Family daily spending**.

Shop Owner and Street Vendor modules remain in the source tree for compatibility and future development, but their role choices and main navigation are paused in the current iteration. Existing legacy seller records have not been removed.

## Technology

- **App:** Flutter and Dart
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **Authorization:** Firestore Security Rules
- **App integrity:** Firebase App Check configuration
- **Backend functions:** Firebase Cloud Functions
- **Validation:** Flutter tests, static analysis, Firebase emulators, and Android emulator integration tests
- **Automation:** GitHub Actions

## Project structure

```text
.
├── .github/workflows/           # CI, validation, debug APK workflow
├── docs/                        # Architecture, setup, status, and release guides
├── functions/                   # Firebase Cloud Functions
├── mobile/
│   └── parchipocket_flutter/    # Flutter Android application
├── public/delete-account/       # Account-deletion web page source
├── scripts/                     # Validation and deployment scripts
├── firebase.json                # Firebase CLI configuration
├── firestore.rules              # Firestore authorization rules
├── test_deletion.js             # Account-deletion test harness
└── test_rules.js                # Firestore rules test harness
```

Inside the Flutter app:

- `lib/core/` – application state, data access, and telemetry.
- `lib/features/` – authentication, expenses, receipts, settings, account deletion, and retained seller/vendor modules.
- `lib/shared/` – theme and reusable widgets.
- `test/` – unit and widget tests.
- `integration_test/` – Firebase emulator-backed integration tests.

See [Repository Structure](docs/REPOSITORY_STRUCTURE.md) for the detailed map.

## Run locally

### Requirements

- Flutter SDK (stable channel)
- Android Studio and Android SDK
- An Android emulator or USB-debugging-enabled Android device
- Java and Node.js for the Firebase emulator test harness

### Start the Android app

Open `mobile/parchipocket_flutter/` in Android Studio, or open PowerShell in that folder (the one containing `pubspec.yaml`):

```powershell
flutter doctor
flutter pub get
flutter devices
flutter run
```

### Run tests and analysis

From `mobile/parchipocket_flutter/`:

```powershell
flutter test --reporter compact
flutter analyze
```

Run the Firestore and account-deletion harnesses from the repository root using local emulators and a demo project ID:

```powershell
npx firebase-tools emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_rules.js && node test_deletion.js"
```

For the repository's combined verification workflow, use:

```powershell
.\scripts\verify-backend.ps1
```

The GitHub Actions workflow also builds an Android debug APK and runs automated validation. Android emulator integration checks are part of the workflow on the configured CI path.

## Latest Android preview

The latest published APK is available on the [GitHub Releases page](https://github.com/rabit001/parchipocket/releases).

> **Build type:** Debug-signed APK for testing. It is not a production-signed app and is not a Play Store release.

## Backend and security notes

ParchiPocket uses Firebase Authentication and Cloud Firestore. User-owned household records are scoped to the authenticated account, and Firestore Security Rules are maintained and tested with local emulators.

A few important distinctions:

- Pushing code to GitHub does **not** deploy Firestore Rules or Cloud Functions to Firebase.
- Emulator test results do not prove that production Firebase settings or deployed rules match the repository.
- Real SMS delivery depends on Firebase Phone provider configuration, billing, quotas, and allowed test numbers.
- The Google sign-in button currently uses a demo route; completed Google OAuth is not yet implemented.
- Demo mode uses in-memory sample data and is not a cloud account or persistent ledger.

Review [Backend Runbook](docs/BACKEND_RUNBOOK.md) before making Firebase deployment changes.

## Current limitations

The following items are not production-complete:

- Google OAuth sign-in.
- Production Firebase configuration and deployment verification.
- Robust offline sync and conflict resolution.
- PDF receipt export.
- Live nearby-shop discovery.
- Production thermal-printer integration.
- Push notifications.
- Audited correction flows for saved household entries.

Voice recognition quality and language support depend on the device and installed speech service. Always review the transcript and extracted amount before saving.

## Documentation

| Guide | What it covers |
| --- | --- |
| [Project Overview](docs/PROJECT_OVERVIEW.md) | Product focus, principles, and development direction |
| [Feature Status](docs/FEATURE_STATUS.md) | Implemented, paused, planned, and incomplete areas |
| [Setup Guide](docs/SETUP_GUIDE.md) | Windows, Flutter, Android Studio, and Firebase setup |
| [Architecture](docs/ARCHITECTURE.md) | Application and backend architecture |
| [Development Roadmap](docs/DEVELOPMENT_ROADMAP.md) | Planned development work |
| [Backend Runbook](docs/BACKEND_RUNBOOK.md) | Emulator validation and Firebase deployment cautions |
| [Release Artifacts](docs/RELEASE_ARTIFACTS.md) | Debug build and release details |

## Production readiness

ParchiPocket should not be treated as a production accounting service until the intended Firebase project and deployed rules are verified, App Check and authentication are reviewed, critical flows are tested on current Android devices, production signing is configured, and backup, privacy, and recovery processes are documented.

---

<div align="center">

**ParchiPocket** · Built and maintained by [Rabit Mansuri](https://github.com/rabit001)

</div>
