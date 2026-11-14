# Contributing to ParchiPocket

Thanks for helping improve ParchiPocket. The project is an actively developed Android Beta, so changes should be small, reviewable, tested, and honest about their runtime limitations.

## Before opening a pull request

1. Read the [Project Overview](docs/PROJECT_OVERVIEW.md), [Feature Status](docs/FEATURE_STATUS.md), and [Backend Runbook](docs/BACKEND_RUNBOOK.md).
2. Check existing issues and pull requests to avoid duplicate work.
3. For a substantial change, open an issue first to agree on the scope.
4. Never include credentials, signing material, debug tokens, service-account files, personal data, or production exports.

## Branching

Use short, descriptive branches:

- `feat/<short-description>` for product features.
- `fix/<short-description>` for bug fixes.
- `chore/<short-description>` for maintenance and documentation.
- `docs/<short-description>` for documentation-only work.

Create branches from the current `main`. Do not develop directly on `main`. Open a pull request back to `main` and keep unrelated changes in separate PRs.

## Local validation

For Flutter changes, from `mobile/parchipocket_flutter/`:

```powershell
flutter pub get
flutter test --reporter compact
flutter analyze
```

For Firestore/Auth rules changes, from the repository root:

```powershell
npx firebase-tools emulators:exec --only auth,firestore --project demo-parchipocket-phase4 "node test_rules.js && node test_deletion.js"
```

Use a `demo-*` project ID only. Do not point test harnesses at the production Firebase project.

For Android changes, build the debug APK and inspect the merged manifest/resources when relevant. For release-related changes, verify package ID, signing certificate, checksum, manifest, and release assets. Do not use a debug keystore as a release-signing fallback.

## Pull request expectations

A pull request should include:

- A clear summary and the reason for the change.
- The user-visible behaviour before and after.
- Relevant tests and their actual results.
- Screenshots or short recordings for UI changes, with personal data removed.
- Firebase and security impact, including whether any deployment is required.
- Any known limitations or device scenarios that remain unverified.

Keep PRs focused. Update documentation when behaviour, setup, architecture, or release procedures change. Do not claim physical-device verification unless it was performed.

## Firebase and release safety

- A Git push does not deploy Firestore Rules, Cloud Functions, or Hosting.
- Production Firebase deployments require explicit project verification and review of the complete deployment diff.
- Never commit the release keystore or signing credentials.
- Signed Beta releases must use the protected GitHub environment and the established certificate.
- Increment the app version and Android version code before a new Beta release.
- Do not overwrite immutable tags or releases.

## Commit messages

Use concise conventional-style messages, for example:

- `feat: add household export preview`
- `fix: preserve profile data during account refresh`
- `test: cover expense retry behaviour`
- `docs: clarify local emulator setup`

## Review and merge

The maintainer reviews and merges pull requests. Resolve review conversations and ensure the required GitHub Actions checks pass before merging. Prefer a squash merge for focused changes, unless preserving a multi-commit release history is important.

## Licensing

The repository currently does not declare an open-source license. Do not assume that public visibility grants reuse rights. Confirm the maintainer's licensing decision before contributing material that depends on redistribution rights.
