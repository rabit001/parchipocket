# Feature Status

This table describes the current Beta implementation represented by the repository release branch. Automated tests demonstrate only the scenarios they execute; they do not prove that every real-device, Firebase Console, or production scenario has been verified.

| Area | Current status | Notes |
|---|---|---|
| Home & Family daily spending | Implemented Beta; active development | Primary onboarding and app experience |
| Manual household purchase entry | Implemented | Review fields and confirm before saving |
| Voice-assisted purchase entry | Implemented Beta | Uses the device speech service and local parsing; one purchase per utterance |
| Daily log and category insights | Implemented | Uses saved household entries and paginated Daily Log data |
| Household expense persistence | Implemented | Owner-scoped Firestore records with schema/rules validation |
| Demo mode | Implemented | In-memory sample session; must not read or write cloud account data |
| Google Sign-In | Implemented | Google provider through Firebase Authentication; real provider/client configuration is required |
| Phone / OTP authentication | Integrated; environment-dependent | Firebase Auth code exists; real SMS depends on Phone provider, quotas, test-number configuration, and billing |
| Profile contact number | Implemented | Editable profile field; not verified merely by being saved |
| Profile photo | Implemented, device-only | Custom image is stored in private app storage for the current UID/device; no cloud sync |
| Android launcher icon | Implemented | Standard and round launcher resources are packaged in the Beta APK |
| In-app Beta updater | Implemented for Android Beta | Checks on fresh app launches, validates metadata/checksum, and hands off to Android installer; user approval is required |
| Shop Owner / Street Vendor | Retained but paused | Legacy screens and records remain; role choices are hidden in current navigation |
| Receipt claim QR/manual code | Implemented | Claim code is a bearer capability; shared snapshot is minimized |
| Claimed receipt copies | Implemented | Read-only recipient copy and index are constrained by Firestore rules |
| Account deletion | Implemented in source | Callable/worker recovery flow exists; production function and client configuration must be verified separately |
| Firestore Security Rules | Checked in and emulator-tested | Rules changes require explicit deployment to the intended project |
| Firebase App Check | Integrated for selected callable flow | Console registration, allowed debug tokens, and enforcement must be checked separately |
| Nearby shop discovery | Placeholder | No live nearby-shop service |
| PDF receipt export | Planned / incomplete | Not production-complete |
| Thermal printer | Preview / incomplete | Not validated against target printer hardware |
| Push notifications | Not implemented | No messaging backend |
| Offline sync/conflict resolution | Not implemented | No complete queue/reconciliation model |
| CI validation | Configured | Flutter tests/analysis, Firestore rules, and Android emulator checks run in GitHub Actions |
| Android Beta APK | Published | [GitHub Releases](https://github.com/rabit001/parchipocket/releases); signed Beta prerelease, not a Play Store release |

## Beta release gate

Before widening distribution, verify the intended Firebase project and deployed rules, App Check configuration, authentication and account recovery, critical financial/receipt flows on supported devices, update installation behaviour, privacy/data retention, and recovery processes. A green CI run is not a substitute for these checks.
