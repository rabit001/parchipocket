# Backend Architecture

This document describes the implemented Firebase-backed development architecture and distinguishes it from production services that do not exist yet.

## Runtime shape

```text
Flutter Android client
  ├── AppState: session, routing, and UI state
  ├── FirestoreService: serialization and persistence
  ├── Firebase Authentication: identity/session
  ├── Cloud Firestore: profiles, bills, expenses, saved shops
  └── Receipt claims: digest token, atomic consume, immutable copy
                 │
                 ▼
       Firestore Security Rules
       - UID-scoped account data
       - constrained immutable bill updates
       - owner-issued receipt claim snapshots
       - one claim + one customer copy/index in one atomic commit
```

## Collections

- `users/{uid}`: profile. Only the authenticated owner can read it; the selected role is preserved after creation.
- `users/{uid}/bills/{billId}`: original owner bills. The document ID must match the model ID. Financial fields are immutable; approved flags have constrained transitions.
- `users/{uid}/expenses/{expenseId}`: owner-scoped expense records. Stable IDs and a transaction make retry operations idempotent; conflicting ID reuse is rejected.
- `users/{uid}/savedShops/{shopId}`: owner-scoped saved shop names. New IDs use a SHA-256 digest of a normalized name; deletion supports legacy sanitized IDs.
- `receiptClaims/{sha256(code)}`: minimal receipt snapshot, source owner/bill, expiry, and status. Raw claim codes are not persisted.
- `users/{uid}/claimedReceipts/{ownerUid}/bills/{billId}`: immutable receipt copy belonging to the recipient.
- `users/{uid}/claimedReceiptsIndex/{ownerUid~billId}`: recipient-owned index to load claimed copies.

## Security invariants

1. User data remains scoped to `request.auth.uid`.
2. A claim is issued only against a bill under the authenticated owner's UID; the snapshot matches the original bill.
3. The shared snapshot omits phone number, settlement flags, and account-management data.
4. Claim consumption, customer copy creation, and index creation must be accepted together by the security rules.
5. Claimed copies are read-only and are not sent through seller bill mutation methods.
6. Expenses and bill creation use stable identities for retries; conflicting record reuse is rejected.
7. Original bills remain owner-only; claiming a receipt does not grant access to the source bill.

## Deliberate limitations

- Claim codes are bearer capabilities. A person who knows a valid code can read its minimized snapshot. Rules cannot prove client-side random entropy or provide robust per-user/IP throttling.
- User-selected roles are app modes, not verified merchant identities.
- No separate trusted API or Cloud Functions service is included. Cloud Functions require a billing plan that may not match a Spark-only constraint.
- App Check Console enforcement cannot be inferred from source files.
- Rules in this repository do not become live until explicitly deployed to the intended Firebase project.

## Local verification

From repository root:

```powershell
npx firebase-tools emulators:exec --only firestore,auth --project demo-parchipocket-ci "node test_rules.js"
```

From `mobile/parchipocket_flutter`, with local Firestore/Auth emulators running and an Android emulator connected:

```powershell
flutter test integration_test/firestore_service_emulator_test.dart -d emulator-5554
```

See [BACKEND_RUNBOOK.md](BACKEND_RUNBOOK.md) for operations, deployment, and release checks.
