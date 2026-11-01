# Feature Status

This table describes the code currently on `main`. A passing CI run proves the automated checks for that commit; it does not prove that Firebase production settings are deployed or that every physical-device scenario has been tested.

| Area | Current status | Notes |
|---|---|---|
| Home & Family daily spending | Implemented MVP; active development | Current onboarding and primary app experience |
| Manual household purchase entry | Implemented | Review fields and explicitly confirm before saving |
| Voice-assisted purchase entry | Implemented MVP | Platform speech recognition and a conservative local parser; one purchase per utterance |
| Household expense persistence | Implemented | Owner-scoped Firestore collection with schema validation |
| Daily log and category insights | Implemented | Uses saved household entries and paginated Daily Log data |
| Local demo session | Implemented | In-memory sample data; must not read or write cloud data |
| Phone / OTP authentication | Integrated; Firebase configuration check required | Firebase Auth code is implemented; real SMS depends on Phone provider, billing, quotas, and allowed test numbers |
| Google sign-in | Demo only | Not completed Google OAuth |
| Account profiles | Implemented | Cloud profile loading and updates for authenticated accounts |
| Shop Owner / Street Vendor | Retained but paused | Legacy screens and stored records remain; role choices are hidden in current navigation |
| Receipt claim QR/manual code | Implemented | Claim code is a bearer secret; shared snapshot is minimized |
| Claimed receipt copies | Implemented | Read-only recipient copy and index are validated by Firestore rules |
| Account deletion | Implemented in source | Cloud Functions flow and recovery logic exist; production deployment must be verified separately |
| Firestore Security Rules | Checked in and CI-tested | Emulator harness passes; GitHub pushes do not deploy rules |
| Firebase App Check | Account-deletion callable enforced in source | Android Play Integrity/debug provider and Web reCAPTCHA v3 must be registered in Firebase Console before deploying the function; broader Firestore/Auth enforcement remains separate |
| Nearby shop discovery | Placeholder | No live nearby-shop service |
| PDF receipt export | Preview/planned | Not production-complete |
| Thermal printer | Preview/planned | Not validated against target printer hardware |
| Push notifications | Not implemented | No messaging backend |
| Offline sync/conflict resolution | Not implemented | No complete offline queue/reconciliation model |
| CI validation | Passing on current main commit | Flutter tests/analysis, Firestore rules, Android emulator integration, and debug APK build passed |
| Android debug preview | Published | [latest GitHub debug release](https://github.com/rabit001/parchipocket/releases); debug-signed, not a production release |

## Production release gate

Do not treat the app as a production accounting service until the intended Firebase project and deployed rules are confirmed, App Check enforcement is reviewed, authentication and account recovery are tested on real devices, critical financial/receipt flows are verified, production signing is configured, and backup/retention/privacy processes are documented.
