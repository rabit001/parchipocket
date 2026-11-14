# Branching and Release Workflow

This document describes the intended Git workflow after the current integration pull request is merged.

## Branch model

- `main` is the canonical integration branch and source of reviewed releases.
- Short-lived `feat/*`, `fix/*`, `docs/*`, and `chore/*` branches hold focused work.
- All application and backend changes enter `main` through pull requests.
- Do not force-push or develop directly on `main`.

Create a branch from an up-to-date main:

```powershell
git switch main
git pull --ff-only
git switch -c fix/short-description
```

After implementation and local verification:

```powershell
git push -u origin fix/short-description
```

Open a pull request targeting `main`. Keep the PR focused, explain the user impact, list test commands/results, and call out Firebase deployment requirements.

## Required review gates

The repository owner should configure GitHub branch protection or a ruleset for `main`:

- Require pull requests before merging.
- Require the backend-validation workflow's relevant checks to pass.
- Require conversations to be resolved.
- Block force pushes and branch deletion.
- Require at least one independent approval when another maintainer/reviewer is available.

Do not make a required approval impossible for a single-maintainer repository. Review settings should match the actual team size.

## Beta release process

The signed Beta workflow is `.github/workflows/publish-beta-release.yml`. It is intended to run from `main` after this integration PR is merged.

1. Implement and review the change through a pull request.
2. Run Flutter tests, static analysis, Firestore/Auth emulator tests, and applicable Android build checks.
3. Increment the semantic version and Android build number in the Flutter pubspec.
4. Review the release notes and the exact workflow inputs.
5. Manually dispatch the signed Beta workflow from `main`.
6. Verify the GitHub Actions run, APK package ID, approved signing certificate, SHA-256 checksum, update manifest, prerelease assets, and immutability.
7. Install and test the Beta on supported Android devices; do not claim device verification from CI alone.

The workflow uses the protected `direct-apk-release` environment. Signing secrets and keystore material must remain outside Git.

## Versioning

The Flutter package version uses `versionName+versionCode`, for example `0.1.5+5`. Increase the Android version code for every distributable APK. The Beta workflow derives the tag from both values and refuses to overwrite an existing tag or reuse a version code.

## Firebase deployment

GitHub merges and releases do not deploy Firebase services. Firestore Rules, Cloud Functions, and Hosting have separate deployment procedures. Review [Backend Runbook](BACKEND_RUNBOOK.md), verify the intended Firebase project, and deploy only the explicitly approved service.
