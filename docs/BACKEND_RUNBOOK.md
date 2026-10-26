# Backend Operations Runbook

This guide describes the Firebase backend currently implemented in ParchiPocket. It is not a claim that the project is production-ready.

## Backend scope

The backend is Firebase Authentication plus Cloud Firestore and Security Rules. No separate server/API or Cloud Functions service is included. This is compatible with a Spark-oriented setup, but client-only receipt claims cannot have server-attested token entropy or robust per-user/IP throttling.

## Data schema

| Path | Purpose | Security |
|---|---|---|
| `users/{uid}` | Profile and selected app role | Owner only; role is preserved on update |
| `users/{uid}/bills/{billId}` | Original bills | Owner only; path ID matches record ID; financial fields immutable |
| `users/{uid}/expenses/{expenseId}` | Expenses | Owner only; idempotent transaction writes; client update/delete denied |
| `users/{uid}/savedShops/{shopId}` | Saved shop references | Owner only; names use digest IDs to prevent sanitization collisions |
| `receiptClaims/{sha256(code)}` | Bearer claim and minimized receipt snapshot | Authenticated exact lookup; expiry and single-use state transition rules |
| `users/{uid}/claimedReceipts/{ownerUid}/bills/{billId}` | Claimed read-only receipt copy | Recipient only; atomically tied to claim consumption |
| `users/{uid}/claimedReceiptsIndex/{ownerUid~billId}` | Recipient index | Recipient only; atomically tied to copy creation and claim consumption |

Raw claim codes are not persisted. The official client generates 128 bits with `Random.secure()`; only the SHA-256 digest is stored. Shared snapshots omit phone number and settlement/account flags.

## Security boundaries

- The authenticated UID must match the user path for profiles, original bills, expenses, saved shops, and claimed copies.
- Claim issuance requires a source bill owned by the authenticated user; the snapshot must match the original bill.
- Claim consumption, the immutable customer copy, and the index record must be accepted as one atomic Firestore transaction.
- An identical expense retry uses the same document ID. Conflicting content at that ID is rejected rather than overwriting the original.
- Saved shop IDs are based on a SHA-256 digest of the normalized name; removal supports legacy sanitized IDs.
- Roles are app modes, not verification of a real-world business.
- A bearer who knows a valid claim code can read its minimized snapshot. Rules cannot prove client-side randomness or enforce robust per-user/IP rate limits.
- App Check is defense in depth, not a replacement for authorization. Its Firebase Console enforcement state cannot be inferred from repository files.
- Repository rules are not live until explicitly deployed to the correct Firebase project.

## Local validation

From repository root:

```powershell
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-phase4 "node test_rules.js"
```

From the Flutter project directory:

```powershell
flutter pub get
flutter test --reporter compact
flutter analyze
flutter test integration_test/firestore_service_emulator_test.dart -d emulator-5554
```

The Dart integration test expects Firestore on port 8088 and Auth on port 9099. The Android emulator connects through `10.0.2.2`. If an emulator failed to start, that run is not a test pass.

## Repeatable Windows scripts

From the repository root, run:

    .\scripts\verify-backend.ps1

This runs Flutter unit/widget tests, analysis, JavaScript syntax validation, and the rules harness against local demo emulators. To also run the Dart Firestore/Auth integration suite, an Android emulator must be online:

    .\scripts\verify-backend.ps1 -RunAndroidIntegration -DeviceId emulator-5554

The production deployment script is separate and interactive:

    .\scripts\deploy-firestore-rules.ps1

It reruns all preflight checks and requires the Android integration suite to pass before asking for the exact target-project confirmation string. It has not been run as part of this change.

## Manual Firestore rules deployment

GitHub pushes do not update Firebase's deployed rules. Deployment is a separate production-affecting step and requires explicit approval.

After all emulator checks pass and the rule diff is reviewed, confirm the target project ID in Firebase Console. For the configured project, the manual command is:

```powershell
firebase deploy --only firestore:rules --project parchipocket
```

Do not run this merely to hide a client/demo-mode bug. Do not use production data in emulator tests. After an approved deployment, perform a smoke test with a non-sensitive test account.

## Release checklist

- [ ] Flutter unit/widget tests pass.
- [ ] Flutter analysis has no issues.
- [ ] Firestore Rules harness passes against a local `demo-*` project.
- [ ] Dart Firestore/Auth integration tests pass on an Android emulator.
- [ ] Demo mode makes no Firestore reads/writes.
- [ ] Existing users can load profile and owned data.
- [ ] Cross-user access and claim replay attempts are denied.
- [ ] Rules are reviewed and the correct Firebase project is confirmed.
- [ ] App Check configuration and Console enforcement are verified.
- [ ] Backup, retention, privacy, and support ownership are documented.
