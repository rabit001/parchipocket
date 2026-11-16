# Branching and Release Workflow

This repository intentionally keeps a small branch model for a solo-maintained project.

## Branch model

Only two long-lived branches should remain:

- `main` is the canonical, reviewed branch used for official Beta releases and public source.
- `develop` is the single active working branch for application, backend, documentation, and maintenance changes.

Do day-to-day work on `develop`. When a set of changes is ready, open one pull request from `develop` to `main`. Wait for the complete backend-validation workflow to pass, review the diff, then merge it. After the merge, bring `develop` up to date with `main` before starting the next batch of work.

Do not create a separate long-lived branch for each task. When a short-lived experiment is genuinely necessary, merge it back into `develop` and remove it after integration.

Example local workflow:

```powershell
git switch develop
git pull --ff-only
# Make and verify the changes
git add .
git commit -m "feat: describe the change"
git push origin develop
```

When the work is ready, open a pull request:

- **Base:** `main`
- **Compare:** `develop`

Do not push routine development work directly to `main`, and do not force-push either long-lived branch.

## Review and protection

Configure GitHub rules for `main`:

- Require pull requests before merging.
- Require the backend-validation checks to pass.
- Require review conversations to be resolved.
- Block force pushes and branch deletion.
- Require an independent approval only when another maintainer is available; do not make the solo-maintainer workflow impossible.

Keep `develop` as the only active working branch. Old merged task branches and obsolete automation branches should be deleted after confirming their changes are already in `main` or intentionally abandoned.

## Beta release process

The signed Beta workflow is `.github/workflows/publish-beta-release.yml`. It must be manually dispatched from `main` after a reviewed merge.

1. Implement and verify the changes on `develop`.
2. Open the `develop` → `main` pull request.
3. Wait for Flutter tests, static analysis, Firestore/Auth emulator checks, Android build, and applicable integration tests.
4. Increment the semantic version and Android build number in the Flutter pubspec only when preparing a new signed Beta.
5. Review release notes and workflow inputs.
6. Manually dispatch the signed Beta workflow from `main`.
7. Verify the package ID, approved signing certificate, APK checksum, update manifest, release assets, and immutability.
8. Test the Beta on supported Android devices; CI does not prove physical-device verification.

The repository also publishes a separate unsigned debug preview after successful main-branch CI. Debug previews are not production-signed releases and must not be distributed as the official Beta.

The signed workflow uses the protected `direct-apk-release` environment. Signing secrets and keystore material must remain outside Git.

## Versioning

The Flutter package version uses `versionName+versionCode`, for example `0.1.5+5`. Increase the Android version code for every distributable signed APK. Never overwrite a published immutable release or reuse its tag.

## Firebase deployment

GitHub merges and releases do not deploy Firebase services. Firestore Rules, Cloud Functions, and Hosting have separate deployment procedures. Review [Backend Runbook](BACKEND_RUNBOOK.md), verify the intended Firebase project, and deploy only the explicitly approved service.
