# Development Roadmap

This roadmap reflects the current ParchiPocket Beta direction. Completion is based on implementation and automated checks; Firebase Console configuration and physical-device behaviour require separate verification.

## Current baseline

- [x] Flutter Android app organised by core, features, and shared layers.
- [x] Firebase Authentication integration, including Google Sign-In.
- [x] Firebase Phone Auth flow integrated; real SMS delivery remains environment-dependent.
- [x] Cloud Firestore persistence and owner-scoped security rules for supported records.
- [x] Explicit local demo mode separated from authenticated cloud sessions.
- [x] Manual and voice-assisted household purchase entry with review-before-save.
- [x] Household Daily Log, pagination, and category totals.
- [x] Profile contact-number editing with explicit unverified status.
- [x] Device-local profile photo selection, replacement, removal, and cleanup.
- [x] Android launcher icon resources and signed Beta distribution.
- [x] In-app Beta updater with release metadata and APK checksum verification.
- [x] Receipt claim/copy flow and account-deletion backend implementation retained.
- [x] Flutter tests, static analysis, Firestore rules harness, Android emulator integration, and Android build validation in GitHub Actions.

## Stage 1: Stabilise real-device experience

- [ ] Verify Google Sign-In, profile updates, and account switching across test accounts.
- [ ] Verify Android Back button and gesture behaviour across supported Android launchers/devices.
- [ ] Verify photo picker cancellation, replacement, removal, and app-restart behaviour.
- [ ] Verify Beta update check, Later dismissal, download, installer permission, and in-place update behaviour.
- [ ] Verify Firebase Phone provider, SMS quota/billing, test numbers, and account recovery in the intended Firebase project.
- [ ] Verify App Check enforcement and debug-token handling in Firebase Console.

## Stage 2: Household data reliability

- [ ] Add a safe, audited correction flow for household entries.
- [ ] Define and test backup, export, retention, and account-recovery behaviour.
- [ ] Design offline queueing and conflict resolution before claiming reliable offline support.
- [ ] Test timezone/date boundaries, pagination, retries, and duplicate-submit behaviour on real devices.

## Stage 3: Receipts and retained seller capabilities

- [ ] Validate receipt claims end-to-end with two separate test accounts.
- [ ] Add production-quality PDF receipt export and sharing.
- [ ] Select thermal printer models and test Bluetooth/USB compatibility.
- [ ] Revisit Shop Owner and Street Vendor modes only after defining role verification and business onboarding.

## Stage 4: Production readiness

- [ ] Complete privacy/data-retention review and support/incident ownership.
- [ ] Complete accessibility, performance, security, and recovery checks.
- [ ] Prepare store listing and Play Console compliance.
- [ ] Run a small pilot with consenting users and a documented issue log.

## Not part of the current Beta

Push notifications, live nearby-shop discovery, production PDF/printer support, robust offline sync, cloud profile-photo sync, and Play Store production distribution are not currently complete. Do not describe these as implemented until code and tests demonstrate the end-to-end behaviour.
