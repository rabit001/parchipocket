# ParchiPocket: Project Overview

**Maintainer:** Rabit Mansuri ([rabit001](https://github.com/rabit001))
**Platform:** Android
**Client:** Flutter and Dart
**Backend:** Firebase Authentication, Cloud Firestore, Firestore Security Rules, and Cloud Functions
**Distribution:** Signed Beta APK through GitHub Releases
**Current status:** Active Beta; not a Play Store or production financial-service release.

## 1. Product focus

ParchiPocket focuses on Home & Family daily spending. Users can record household purchases, review a daily log, and inspect category totals. Manual entry and voice-assisted single-purchase entry are supported, with a review-before-save flow.

The repository also retains Shop Owner and Street Vendor modules from earlier iterations. Their source files and legacy records remain for compatibility and future development, but their role choices and primary navigation are paused in the current app experience.

## 2. Product principles

- Make frequent purchase recording quick and understandable.
- Keep household expenses, seller expenses, receipts, and Udhaar records distinct.
- Show clear totals and category breakdowns.
- Keep cloud data scoped to the authenticated Firebase UID.
- Make demo mode visibly separate from authenticated cloud sessions.
- Make the storage boundary of profile photos clear: custom photos are stored locally on the current device.
- Never label Beta or preview capabilities as production-ready.

## 3. Implemented foundations

- Flutter Android client with feature-based source folders.
- Firebase Authentication, including Google Sign-In.
- Firebase Phone Auth flow; real SMS delivery remains dependent on Firebase provider configuration, quotas, permitted test numbers, and applicable billing.
- Cloud Firestore persistence for supported profiles and records.
- UID-scoped Firestore Security Rules and local emulator validation.
- Explicit local demo mode with in-memory sample data.
- Manual and voice-assisted household purchase entry with review-before-save.
- Daily spending log and category totals.
- Profile contact-number editing; this field is not proof of phone ownership or verification.
- Device-local custom profile photos with Google profile image/initials fallback.
- QR/manual receipt claim and read-only copy flow.
- Cloud Functions account-deletion implementation.
- GitHub Actions validation and signed Beta release workflows.
- In-app Beta update checks, checksum validation, and Android package-installer handoff.

## 4. Current limitations

- Custom profile photos are device-only and do not sync to another device.
- Demo data is in-memory and is not a persistent cloud ledger.
- Real Phone Auth SMS delivery depends on Firebase Console configuration and applicable billing.
- Firebase Console App Check enforcement and live backend deployment state must be verified separately.
- Shop Owner and Street Vendor flows are retained but paused in current navigation.
- PDF export, live shop discovery, production thermal printing, push notifications, robust offline sync, and complete data export/recovery are not production-complete.
- Voice recognition availability and Hindi/Hinglish accuracy vary by device.
- Beta APK distribution is separate from Play Store production distribution.

## 5. Development direction

1. Stabilise critical flows on supported physical Android devices.
2. Continue profile, purchase-entry, Daily Log, and account lifecycle testing.
3. Define data correction, export, backup, retention, and recovery behaviour.
4. Design offline queueing and conflict resolution before claiming reliable offline support.
5. Validate receipt and account-deletion flows end-to-end.
6. Complete privacy, accessibility, security, deployment, signing, and Play Store readiness reviews before production distribution.
