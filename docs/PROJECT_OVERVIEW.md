# ParchiPocket: Project Overview

**Project owner:** Rabit Mansuri (@rabit001)  
**Platform:** Android  
**Client:** Flutter and Dart  
**Backend:** Firebase Authentication, Cloud Firestore, Firestore Security Rules, and Cloud Functions  
**Current status:** Working development MVP with a published debug preview; not production-ready.

## 1. Current product focus

The current iteration focuses on Home & Family daily spending. A user can record household purchases, review a daily log, and inspect category totals. Manual entry and voice-assisted single-purchase entry are supported, with a review-before-save flow.

The repository also retains Shop Owner and Street Vendor features from earlier iterations. Those screens and records remain in source for compatibility and future work, but their role choices and main navigation are paused in the current app experience.

## 2. Product principles

- Make frequent purchase recording quick and understandable.
- Keep bills, household expenses, seller expenses, and Udhaar records distinct.
- Show clear totals and category breakdowns.
- Minimise personal information and keep user data owner-scoped.
- Make demo mode visibly separate from authenticated cloud sessions.
- Do not label preview features as production-ready.

## 3. Implemented foundations

- Flutter Android client with feature-based source folders.
- Firebase phone authentication flow; real SMS delivery depends on Firebase Console configuration and billing.
- Cloud Firestore persistence for profiles and supported records.
- UID-scoped Firestore rules and local emulator validation.
- Explicit local demo mode with in-memory sample data.
- Receipt claim/copy flow with minimized read-only receipt data.
- Cloud Functions account-deletion implementation.
- GitHub Actions checks for Flutter tests, static analysis, Firestore rules, Android emulator integration, and debug APK packaging.
- Automatic GitHub Release publishing for successful main-branch debug builds.

## 4. Current limitations

- Google sign-in remains demo-only.
- Real SMS OTP requires verification of the production Firebase Phone provider, billing, quotas, and test-number setup.
- Firebase Console App Check enforcement and deployed Firestore rules cannot be inferred from repository source.
- Shop Owner and Street Vendor flows are paused in current navigation.
- PDF export, live shop discovery, production thermal printing, push notifications, and robust offline sync are not production-complete.
- Voice recognition availability and Hindi/Hinglish accuracy vary by device.
- Debug APKs are for testing only; production signing, privacy, recovery, store listing, and release review remain separate work.

## 5. Development direction

1. Keep the source tree feature-based and remove documentation drift.
2. Resolve remaining runtime issues on a current physical Android device.
3. Verify real Phone Auth and Firebase project settings with a test account.
4. Finish data correction/recovery and offline behaviour.
5. Validate receipt and account-deletion flows end-to-end.
6. Complete production security, privacy, deployment, signing, and Play Store release gates.
