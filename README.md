# ParchiPocket

### Everyday spending, easier to track.

![ParchiPocket logo](ParchiPocket_Brand_Assets/parchipocket_logo_horizontal.png)

[![Backend validation](https://github.com/rabit001/parchipocket/actions/workflows/backend-validation.yml/badge.svg)](https://github.com/rabit001/parchipocket/actions/workflows/backend-validation.yml)
[![Flutter 3.47.9](https://img.shields.io/badge/Flutter-3.47.9-02569B?logo=flutter)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase)](https://firebase.google.com/)
[![Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![Latest Beta](https://img.shields.io/github/v/release/rabit001/parchipocket?include_prereleases&label=latest%20beta)](https://github.com/rabit001/parchipocket/releases)

**Maintainer:** [Rabit Mansuri](https://github.com/rabit001)

[Download latest Beta](https://github.com/rabit001/parchipocket/releases) · [All releases](https://github.com/rabit001/parchipocket/releases) · [Report a bug](https://github.com/rabit001/parchipocket/issues/new?template=bug_report.yml)

---

## Overview

ParchiPocket is a Flutter Android app for recording household purchases, reviewing a daily spending log, and understanding category-wise totals. Firebase Authentication and Cloud Firestore provide identity and cloud persistence for supported account features.

ParchiPocket is currently distributed as a **Beta APK through GitHub Releases**. It is not a Play Store release and should not yet be treated as a production accounting or financial service.

## Current capabilities

| Area | Current implementation |
| --- | --- |
| Household purchases | Manual entry with editable details and confirmation before saving |
| Voice-assisted entry | On-device speech recognition and local parsing for a single purchase, followed by user review |
| Daily spending | Daily log and current-month spending totals |
| Category insights | Totals calculated from saved household entries |
| Cloud accounts | Firebase Authentication and UID-scoped Cloud Firestore records |
| Sign-in | Google Sign-In through Firebase Authentication; Phone Auth remains subject to Firebase provider, SMS, quota and billing configuration |
| Profile | Editable contact number; saving a number does not verify ownership |
| Profile photo | Custom photo stored privately on the current device; it is not cloud-synchronised |
| Demo mode | Explicit local session with in-memory sample data; not a cloud account or persistent ledger |
| Beta updates | Checks GitHub Releases on fresh Android app launches and offers a checksum-verified APK update |
| Receipts | Existing QR/manual receipt-claim flow remains available as a secondary feature |

Shop Owner and Street Vendor modules remain in the source tree for compatibility and future development, but their role choices and main navigation are currently paused.

## Latest Android Beta

**ParchiPocket Beta 0.1.5+5**

- [Open the latest Beta release](https://github.com/rabit001/parchipocket/releases/tag/parchipocket-beta-v0.1.5-5)
- [Download the signed Android APK](https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v0.1.5-5/parchipocket-release.apk)
- [Download the SHA-256 checksum](https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v0.1.5-5/parchipocket-release.apk.sha256)

The in-app updater validates release metadata and the APK checksum before opening Android's package installer. Android still requires the user to approve installation; the app does not silently install APKs.

## Technology

- **Client:** Flutter and Dart
- **Authentication:** Firebase Authentication, including Google Sign-In
- **Database:** Cloud Firestore
- **Authorization:** Firestore Security Rules
- **App integrity:** Firebase App Check integration
- **Backend:** Firebase Cloud Functions (Node.js)
- **Speech input:** Android speech service through the repository-local speech-to-text package
- **Automation:** GitHub Actions
- **Testing:** Flutter tests, static analysis, Firebase Emulator Suite, and Android emulator integration tests

## Repository layout

~~~text
.
├── .agents/                    # Repository-specific agent guidance
├── .github/workflows/          # CI, validation, and signed Beta workflows
├── docs/                       # Architecture, setup, and release guides
├── functions/                  # Firebase Cloud Functions
├── mobile/parchipocket_flutter # Flutter Android application
├── packages/speech_to_text/    # Repository-maintained local package
├── public/delete-account/      # Account-deletion web page source
├── scripts/                    # Local verification and packaging scripts
├── ParchiPocket_Brand_Assets/  # Approved brand artwork
├── firebase.json               # Firebase CLI configuration
├── firestore.rules             # Firestore authorization rules
├── test_deletion.js            # Account-deletion test harness
└── test_rules.js               # Firestore rules test harness
~~~

Inside the Flutter app, the main areas are:

- **lib/core/** — shared state, persistence, monitoring, and application services.
- **lib/features/** — authentication, customer experience, expenses, receipts, settings, updates, and retained seller modules.
- **lib/shared/** — theme and reusable widgets.
- **test/** — unit and widget tests.
- **integration_test/** — Firebase emulator-backed integration tests.
- **android/** — native Android application, launcher resources, and update installer integration.

See [Repository Structure](docs/REPOSITORY_STRUCTURE.md) for the detailed map.

## Run locally

### Requirements

- Flutter SDK 3.47.9 (the CI and release workflows are pinned to this version)
- Android Studio and Android SDK
- Java 21
- Node.js 22 and npm for Firebase Functions and emulator tooling
- A configured Android emulator for local device testing

### Start the Android app

From the repository root:

~~~powershell
cd mobile/parchipocket_flutter
flutter doctor
flutter pub get
flutter devices
flutter run
~~~

### Run Flutter tests and static analysis

From the Flutter project directory:

~~~powershell
flutter test --reporter compact
flutter analyze
~~~

### Run backend emulator checks

From the repository root, with Java and Node.js available:

~~~powershell
npx firebase-tools emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_rules.js && node test_deletion.js"
~~~

The demo-* project ID is deliberate. Never run test harnesses against the production Firebase project.

For the combined local verification command, run:

~~~powershell
.\scripts\verify-backend.ps1
~~~

See [Setup Guide](docs/SETUP_GUIDE.md) and [Backend Runbook](docs/BACKEND_RUNBOOK.md) before changing Firebase configuration or deploying backend services.

## Security and data notes

- Cloud records are scoped to the authenticated Firebase UID and protected by Firestore Security Rules.
- Demo mode is local and in-memory; it must not read or write cloud account data.
- Custom profile photos are device-only and do not sync across devices.
- A profile contact number is not automatically a verified phone number.
- Firebase Console settings, App Check enforcement, deployed rules, and deployed Cloud Functions must be checked independently; repository source alone cannot prove their live state.
- Never commit signing keys, credentials, debug tokens, service-account files, or local environment files.
- Report suspected vulnerabilities privately; see [Security Policy](SECURITY.md).

## Known limitations

ParchiPocket remains a Beta. Areas that are not yet production-complete include:

- Robust offline queueing and conflict resolution.
- Cloud-synchronised custom profile photos.
- PDF receipt export.
- Live nearby-shop discovery.
- Production thermal-printer validation.
- Push notifications.
- Complete data export, backup, retention, and recovery workflows.
- Production store listing, privacy/compliance review, and broad real-device validation.

Voice recognition quality and language support depend on the device and its installed speech service. Users should review recognised text and amounts before saving.

## Documentation

| Guide | Description |
| --- | --- |
| [Project Overview](docs/PROJECT_OVERVIEW.md) | Product scope and principles |
| [Feature Status](docs/FEATURE_STATUS.md) | Implemented, paused, and planned capabilities |
| [Setup Guide](docs/SETUP_GUIDE.md) | Windows, Flutter, Android, and Firebase setup |
| [Architecture](docs/ARCHITECTURE.md) | Client and backend design |
| [Repository Structure](docs/REPOSITORY_STRUCTURE.md) | Source tree map |
| [Development Roadmap](docs/DEVELOPMENT_ROADMAP.md) | Remaining product work |
| [Backend Runbook](docs/BACKEND_RUNBOOK.md) | Emulator validation and safe Firebase operations |
| [Release Artifacts](docs/RELEASE_ARTIFACTS.md) | Beta APKs and release verification |
| [Contributing](CONTRIBUTING.md) | Branch, review, and test expectations |
| [Security](SECURITY.md) | Vulnerability reporting |

## License

No open-source license is currently declared in this repository. Do not assume that repository visibility grants permission to reuse, redistribute, or modify the project. The maintainer should select a license before accepting external contributions or reuse.

---

**ParchiPocket** · Built and maintained by [Rabit Mansuri](https://github.com/rabit001)
