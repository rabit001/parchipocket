# Backend Operations Runbook

This guide describes the Firebase backend currently implemented in ParchiPocket. It is not a claim that the project is production-ready.

## Backend scope

The backend comprises Firebase Authentication, Cloud Firestore, Firestore Security Rules, and a Node.js 22 Cloud Functions service. Account deletion is implemented through authenticated callable functions with Auth-trigger and scheduled recovery. Receipt claiming continues to use the documented Firestore claim/copy/index flow; do not infer that every receipt operation has moved to trusted server code. Cloud Functions deployment requires an appropriately billed Google Cloud/Firebase project. Local emulator tests do not require production deployment. Client-side receipt claim issuance still cannot provide server-attested token entropy or robust per-user/IP throttling.

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
| `deletionJobs/{uid}` | Server-owned account-deletion checkpoint, worker lease, stage, and terminal TTL | All client reads/writes denied; Admin SDK only |

Raw claim codes are not persisted. The official client generates 128 bits with `Random.secure()`; only the SHA-256 digest is stored. Shared snapshots omit phone number and settlement/account flags.

## Account deletion lifecycle

The `deleteUserAccount` callable derives the target UID from authenticated callable context and requires recent authentication. The worker creates a server-only `deletionJobs/{uid}` checkpoint, locks the user profile, pseudonymizes retained customer receipt references, deletes the user's owned data, and finally deletes the Firebase Auth account. The Auth deletion trigger and scheduled reconciliation worker recover interrupted jobs. Incomplete jobs must not receive a TTL; only completed jobs receive the 24-hour expiry. See `functions/src/account_deletion/index.js` and the emulator test harness `test_deletion.js`.

## App Check for account deletion

The `deleteUserAccount` callable declares `enforceAppCheck: true`. This protects the destructive endpoint in addition to Firebase Authentication, the five-minute reauthentication freshness check, the deletion-job lock, and worker fencing.

Both supported callers must send valid attestation:
- Android release builds use Play Integrity; debug builds use the App Check debug provider and must use an individually allowlisted debug token.
- The public web deletion portal uses Firebase App Check with a registered Web app and a reCAPTCHA v3 site key. It disables OTP and deletion actions until the Web app ID and site key placeholders in `public/delete-account/index.html` are configured.

The Android client obtains a fresh App Check token before it sends the account-deletion callable request. If token retrieval fails or returns an empty token, the request fails locally instead of silently omitting the App Check header. The Web portal checks for a usable App Check token before sending OTP or requesting account deletion.

Before deploying the updated function, complete the Android and Web Firebase Console registration and the Web page configuration in [SETUP_GUIDE.md](SETUP_GUIDE.md). Deploying the function before the Web key is configured will cause the public deletion portal to fail closed. This repository change does not alter live Firebase configuration or deploy Cloud Functions/Hosting.

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
flutter test integration_test/daily_log_pagination_emulator_test.dart -d emulator-5554
```

The Dart integration tests expect Firestore on port 8088 and Auth on port 9099. The Android emulator connects through `10.0.2.2`. If an emulator failed to start, that run is not a test pass.

## GitHub Actions validation

The `ParchiPocket backend validation` workflow runs Flutter unit/widget tests, static analysis, JavaScript syntax checks, the Firestore rules harness, and the account-deletion security harness on pushes and pull requests. The deletion harness runs after `npm ci --prefix functions` in the same isolated Auth/Firestore emulator session; it exercises callable freshness/identity gates, deletion recovery, fencing, and concurrency cases.

The Android emulator integration job runs automatically for pull requests and pushes to `main`, after the Flutter and Firestore-rules jobs pass. It can also be requested manually from GitHub Actions by selecting `ParchiPocket backend validation`, choosing `Run workflow`, and setting `run_android_integration` to true. A skipped or failed job is **not** an integration-test pass.

On successful pushes to `main`, the workflow builds the debug APK and publishes it with a SHA-256 checksum to a GitHub prerelease. The release tag is derived from the app version in `mobile/parchipocket_flutter/pubspec.yaml`.

## Repeatable Windows scripts

From the repository root:

```powershell
.\scripts\verify-backend.ps1
```

This runs Flutter unit/widget tests, analysis, JavaScript syntax validation, and the rules harness against local demo emulators. The CI workflow additionally runs both Android emulator integration tests.

The production deployment script is separate and interactive:

```powershell
.\scripts\deploy-firestore-rules.ps1
```

It reruns preflight checks and requires the exact target-project confirmation string. Do not run it merely to suppress a permission error.

## Manual Firestore rules deployment

GitHub pushes do not update Firebase's deployed rules. Deployment is a separate production-affecting step and requires explicit approval.

After all emulator checks pass and the rules diff is reviewed, confirm the target project ID in Firebase Console. For the configured project, the manual command is:

```powershell
firebase deploy --only firestore:rules --project parchipocket
```

Do not use production data in emulator tests. After an approved deployment, perform a smoke test with a non-sensitive test account.

## Release checklist

- [ ] Flutter unit/widget tests pass.
- [ ] Flutter analysis has no issues.
- [ ] Firestore Rules harness passes against a local `demo-*` project.
- [ ] Both Dart Firestore/Auth and Daily Log emulator integration tests pass on Android.
- [ ] Demo mode makes no Firestore reads/writes.
- [ ] Existing users can load profile and owned data.
- [ ] Cross-user access and claim replay attempts are denied.
- [ ] Rules are reviewed and the correct Firebase project is confirmed.
- [ ] Phone Auth, App Check configuration, and Console enforcement are verified.
- [ ] Backup, retention, privacy, and support ownership are documented.
