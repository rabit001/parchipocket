# ParchiPocket

**Owner and project author:** Rabit Mansuri (@rabit001)  
**Project type:** Flutter mobile-first household spending tracker with voice-assisted purchase entry

ParchiPocket is currently focused on **Home & Family daily expense tracking**: users can record what they bought, the amount, and a spending category, then review daily entries and monthly category totals. The current work adds voice-assisted entry with a review-before-save flow. Firebase Authentication, Cloud Firestore persistence, UID-scoped security rules, and the existing receipt-claim flow remain part of the project. Shop Owner and Street Vendor screens remain in the repository for future work, but their role choices and navigation are paused in the current app experience. This is still a development project, not a production-ready accounting service.

## Current backend

- Firebase Authentication for account sessions and phone-auth flow.
- Cloud Firestore for user profiles, bills, expenses, saved shops, and claimed receipt copies.
- Firestore Security Rules validate user-owned records and constrain financial fields.
- Receipt claims use a random bearer code, a SHA-256 digest as the document ID, bounded expiry, and an atomic claim/copy/index transaction.
- Demo mode is designed to use local sample data without cloud reads or writes.

**Important:** Pushing code to GitHub does not deploy Firestore rules to Firebase. Review and deploy rules only after emulator tests pass. Never use production bill data for emulator testing.

## Product capabilities

### Shared / onboarding
- Splash and welcome screens.
- Explicit local demo mode.
- Phone / OTP authentication flow.
- Home & Family profile setup.
- Profile and settings screens.

### Home & Family daily spending (current focus)
- Daily and current-month spending totals.
- Manual household purchase entry.
- Voice-assisted single-purchase entry with transcript, editable fields, and explicit confirmation before saving.
- Household daily log and category totals calculated from real saved entries.
- Separate owner-scoped Firestore household expense collection.
- Existing receipt QR/manual claim remains available as a secondary feature.

### Paused for this iteration
- Shop Owner and Street Vendor screens remain in the codebase for future development, but their role options and main navigation are hidden.
- Existing seller bills, expenses, Udhaar, and claimed receipts are not deleted by this change.

## Technology

- Flutter / Dart.
- Firebase Authentication.
- Cloud Firestore and Firestore Security Rules.
- Firebase App Check (Android Play Integrity configuration).
- Local Firebase emulators for rule and integration testing.

## Known limitations

- Google sign-in is a demo flow, not a completed Google OAuth integration.
- Real SMS OTP delivery depends on Firebase project configuration and the applicable billing plan. Use configured Firebase test phone numbers for development.
- The demo session uses in-memory sample data and resets when the app process restarts.
- Receipt claim codes are bearer secrets. Firestore rules enforce a single durable claim and receipt integrity, but rules cannot prove that a client used cryptographically secure randomness or provide robust attempt throttling.
- User-selected roles were previously app modes, not proof of a real-world business identity. Shop Owner and Street Vendor modes are currently paused in onboarding; their legacy screens and stored records remain for compatibility.
- Voice-assisted entry uses platform speech recognition plus a conservative local phrase parser. It is not yet an LLM-based assistant and currently targets one household purchase per utterance.
- Household entries are owner-scoped and immutable after saving in this initial version; an audited correction flow is still needed.
- Speech recognition availability and Hindi/Hinglish accuracy vary by device and installed speech service. Review extracted text and amount before saving.
- Firestore rules must be deployed separately; this repository does not prove which rules are active in Firebase Console.
- PDF generation, thermal printer integration, nearby-shop discovery, push notifications, and robust offline sync/conflict resolution are not production-complete.
- Do not treat this project as an accounting system until the release gates below are satisfied.

## Repository layout

```text
.
├── README.md
├── firebase.json
├── firestore.rules
├── test_rules.js
├── docs/
│   ├── ARCHITECTURE.md
│   ├── BACKEND_RUNBOOK.md
│   ├── FEATURE_STATUS.md
│   └── SETUP_GUIDE.md
└── mobile/parchipocket_flutter/
    ├── lib/
    ├── test/
    └── integration_test/
```

## Run the app on Windows

Open `mobile/parchipocket_flutter/` in Android Studio, then run:

```powershell
flutter pub get
flutter devices
flutter run
```

For an emulator that shows as `offline`, inspect Android Studio's SDK Location and use its `platform-tools/adb.exe`. Do not wipe emulator data as a first troubleshooting step.

## Tests

From the Flutter project folder:

```powershell
flutter pub get
flutter test --reporter compact
flutter analyze
```

From the repository root, run the Firestore Rules harness through local emulators:

```powershell
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-phase4 "node test_rules.js"
```

Use scripts/verify-backend.ps1 for Flutter tests, analysis, and rules tests; add -RunAndroidIntegration -DeviceId emulator-5554 only when an Android emulator is online. See docs/BACKEND_RUNBOOK.md for the schema, emulator setup, and the separately gated production-rules deployment procedure.

## Production release gate

Do not call the app production-ready until:
1. Rules and Dart integration tests pass against local emulators.
2. The reviewed rules have been deployed to the intended Firebase project.
3. Authentication, App Check enforcement, recovery, privacy, and claim-code limitations are reviewed.
4. Critical account, bill, expense, settlement, and receipt-claim flows are verified on a current Android build.
5. A backup/retention and incident-response process is documented.

Maintained under **Rabit Mansuri (@rabit001)**.

## Assignment 3 submission materials

Assignment 3 evidence and status notes are maintained in [docs/assignment3/README.md](docs/assignment3/README.md).

- [Automated prototype test results](docs/assignment3/TEST_RESULTS.md) — seven browser-prototype checks passed; these are not Android-device test results.
- [Peer feedback form](docs/assignment3/PEER_FEEDBACK_TEMPLATE.md) — blank template for collecting real participant feedback.
- [Deployment status](docs/assignment3/DEPLOYMENT_STATUS.md) — distinguishes the source repository from a verified public app build.
- [Retrospective and next steps](docs/assignment3/RETROSPECTIVE.md).

The demo video is intentionally not included. Do not claim Android build/device testing, public deployment, or peer feedback until each has been completed and evidence is available.
