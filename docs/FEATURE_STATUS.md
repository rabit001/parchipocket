# Feature Status

Status is based on code in this repository. Implementation does not prove the Firebase rules are deployed or the app is production-ready.

| Area | Status | Notes |
|---|---|---|
| Welcome and onboarding | Implemented | Local navigation routes available |
| Explicit local demo session | Implemented | In-memory sample data; must not access Firestore |
| Phone / OTP authentication | Integrated | Firebase Auth flow; real SMS depends on project configuration and billing |
| Google sign-in | Demo only | Not a completed Google OAuth integration |
| Account profiles and roles | Cloud persistence implemented | UID-scoped profiles; roles are app-selected, not business verification |
| Bill creation / persistence | Implemented | Firestore-generated IDs, create-only transaction retries |
| Bill history and settlement flags | Implemented | Owner-only reads; financial fields protected by rules |
| Expenses | Implemented | Owner-only immutable records, stable retry IDs |
| Saved shops | Implemented | Digest-based IDs avoid name-sanitization collisions; legacy deletes supported |
| Receipt claim QR/manual code | Implemented | 128-bit client CSPRNG, SHA-256 digest, bounded expiry |
| Customer claimed receipts | Implemented | Separate minimized read-only copies and index |
| Receipt-claim security | Implemented in rules | Atomic claim/copy/index constraints; emulator test and deployment still required for release |
| Firestore Security Rules | Checked into repository | GitHub pushes do not deploy rules |
| Firebase App Check | Client configured | Console enforcement/debug-token configuration must be verified separately |
| Nearby shop discovery | Demo/placeholder | No live location-based discovery service |
| PDF generation/share | Preview/planned | Not production-complete |
| Thermal printer integration | Preview/planned | Not validated on target hardware |
| Push notifications | Not implemented | No messaging backend |
| Offline sync/conflict resolution | Not implemented | No complete offline queue/reconciliation model |
| CI validation | Added | Workflow runs Flutter checks, rules emulator, and Android integration tests |

## Release gate

Do not treat this as a production accounting service until CI passes, the reviewed rules are deployed to the correct Firebase project, App Check enforcement is verified, critical device flows are tested, and retention/recovery/privacy decisions are documented.
