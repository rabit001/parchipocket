# Development Roadmap

This roadmap describes the work remaining from the current Home & Family spending MVP. Completed items are based on code and automated checks on `main`; Firebase Console deployment and physical-device behaviour still require separate verification.

## Current baseline

- [x] Flutter Android app organised by `core/`, `features/`, and `shared/`.
- [x] Firebase Authentication phone sign-in flow integrated.
- [x] Cloud Firestore persistence and owner-scoped security rules implemented for supported records.
- [x] Explicit local demo mode separated from authenticated cloud sessions.
- [x] Manual and voice-assisted household purchase entry with review-before-save.
- [x] Household daily log, pagination, and category totals implemented.
- [x] Receipt claim/copy flow and account-deletion backend implementation retained.
- [x] Flutter unit/widget tests, static analysis, Firestore rules emulator harness, Android emulator integration, and debug APK build in GitHub Actions.
- [x] Debug APK and SHA-256 checksum published through GitHub Releases.

## Stage 1: Stabilise real-device experience

- [ ] Install the latest debug APK on a clean Android device and verify onboarding, phone login, profile setup, purchase entry, Daily Log, and settings.
- [ ] Capture and resolve any remaining runtime errors from actual device logs/screenshots.
- [ ] Verify Firebase Phone provider, SMS quota/billing, test numbers, and account recovery in the intended Firebase project.
- [ ] Verify App Check enforcement and debug-token handling in Firebase Console.
- [ ] Confirm Firestore rules deployed to the intended project match the reviewed repository rules.

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
- [ ] Configure production Android signing outside the repository.
- [ ] Complete accessibility, performance, security, and recovery checks.
- [ ] Prepare store listing, release notes, and Play Console compliance.
- [ ] Run a small pilot with consenting users and a documented issue log.

## Not part of the current release

Google OAuth, push notifications, live nearby-shop discovery, production PDF/printer support, and robust offline sync are not currently complete. Do not describe these as implemented until code and tests demonstrate the end-to-end behaviour.
