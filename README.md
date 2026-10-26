# ParchiPocket

**Owner and project author:** Rabit Mansuri (@rabit001)  
**Project type:** Flutter mobile-first digital billing and receipt application

ParchiPocket is a Flutter app for customers, shop owners, and street vendors. It includes Firebase Authentication, Cloud Firestore persistence, UID-scoped security rules, and a receipt-claim flow. It is still a development project, not a production-ready billing or accounting service.

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
- Customer, Shop Owner, and Street Vendor experiences.
- Profile and settings screens.

### Customer
- Home dashboard and bill history.
- Receipt claim by QR/manual code.
- Separate read-only claimed receipts.
- Spending insights, saved shops, and profile screens.

### Shop owner
- Create itemised bills, receipts, and bill history.
- Expenses, udhaar, and settlement tracking.
- Receipt claim-code generation.
- Sales report/export previews and printer setup previews.

### Street vendor
- Quick billing and multi-item bills.
- Receipt preview and sales history.
- Vendor profile.

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
- User-selected roles are app modes, not proof of a real-world business identity.
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
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-ci "node test_rules.js"
```

See [docs/BACKEND_RUNBOOK.md](docs/BACKEND_RUNBOOK.md) for the schema, emulator setup, and the separate production-rules deployment procedure.

## Production release gate

Do not call the app production-ready until:
1. Rules and Dart integration tests pass against local emulators.
2. The reviewed rules have been deployed to the intended Firebase project.
3. Authentication, App Check enforcement, recovery, privacy, and claim-code limitations are reviewed.
4. Critical account, bill, expense, settlement, and receipt-claim flows are verified on a current Android build.
5. A backup/retention and incident-response process is documented.

Maintained under **Rabit Mansuri (@rabit001)**.
