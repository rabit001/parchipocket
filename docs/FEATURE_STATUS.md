# Feature Status

Status is based on code in this repository. Implementation does not prove the Firebase rules are deployed or the app is production-ready.

| Area | Status | Notes |
|---|---|---|
| Home & Family daily-spending experience | In progress | Household-focused onboarding and dashboard; seller/vendor role choices hidden for this iteration |
| Manual household purchase entry | Implemented on feature branch | Item, amount, category, date, source; must be reviewed before saving |
| Voice-assisted household entry | MVP on feature branch | Platform speech-to-text plus conservative local parser; one purchase phrase at a time, not an LLM agent |
| Household expense persistence | Implemented on feature branch | Owner-scoped `users/{uid}/householdExpenses` collection with strict schema and immutable entries |
| Daily log and category insights | Implemented on feature branch | Totals use household entries; category totals no longer use fixed percentages |
| Explicit local demo session | Implemented | In-memory sample data; must not access Firestore |
| Phone / OTP authentication | Integrated | Firebase Auth flow; real SMS depends on project configuration and billing |
| Google sign-in | Demo only | Not a completed Google OAuth integration |
| Account profiles and legacy roles | Cloud persistence implemented | Existing seller roles are retained in stored profiles, but route to Home & Family while seller modes are paused |
| Legacy bill history, seller expenses, Udhaar | Retained but paused | Existing code and records are not deleted by this feature |
| Receipt claim QR/manual code | Implemented | 128-bit client CSPRNG, SHA-256 digest, bounded expiry |
| Claimed receipts | Implemented | Separate minimized read-only copies and index; QR claim remains secondary in the current customer interface |
| Receipt-claim security | Implemented in rules | Atomic claim/copy/index constraints; emulator test and deployment still required for release |
| Firestore Security Rules | Updated on feature branch | Household rules are checked in, but GitHub pushes do not deploy rules |
| Firebase App Check | Client configured | Console enforcement/debug-token configuration must be verified separately |
| Nearby shop discovery | Demo/placeholder | No live location-based discovery service |
| PDF generation/share | Preview/planned | Not production-complete |
| Thermal printer integration | Preview/planned | Not validated on target hardware |
| Push notifications | Not implemented | No messaging backend |
| Offline sync/conflict resolution | Not implemented | No complete offline queue/reconciliation model |
| CI validation | Added | Workflow runs Flutter checks, rules emulator, and Android integration tests; feature branch CI still needs verification |

## Release gate

Do not treat this as a production accounting service until CI passes, the reviewed rules are deployed to the correct Firebase project, App Check enforcement is verified, critical device flows are tested, and retention/recovery/privacy decisions are documented.
