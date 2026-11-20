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

Keep `develop` as the only active working branch. Old merged task branches and obsolete automation branches should be deleted only after confirming their changes are already integrated into `main` or intentionally abandoned.

## Safe automated branch cleanup

Branch cleanup is managed safely and conservatively via `.github/workflows/cleanup-integrated-branches.yml`.

### Safety rules and eligibility

A branch is **never deleted merely because it lacks an open pull request**. Deletion strictly requires verifiable cryptographic and metadata evidence of full integration:

1. **Merged PR Verification:** The branch must have an associated pull request that is closed, marked `merged_at`, and whose base branch is the protected target branch (`main`).
2. **Commit SHA Match:** The current live branch head SHA must exactly match the `pr.head.sha` recorded at the time of merge. If additional commits were pushed to the branch after the PR was merged, the branch is **preserved** to prevent loss of unmerged work.
3. **Protected Branches Excluded:** `main`, `develop`, repository default branches, release/beta branches (`release/*`, `beta/*`, `v*`), and branches marked as protected in GitHub rulesets are permanently preserved from deletion.
4. **Preserve on Uncertainty:** Branches without pull requests, branches with closed but unmerged pull requests, branches with active open PRs, or branches encountering API errors/rate limits are automatically **preserved**.

### Atomic concurrency safeguards (TOCTOU race protection)

Standard GitHub REST reference deletion (`DELETE /repos/{owner}/{repo}/git/refs/{ref}`) only accepts the ref name without an expected commit SHA. This creates a **time-of-check-to-time-of-use (TOCTOU) race window**: if a developer pushes a new commit after an API pre-check but before the DELETE call completes, the branch would be deleted anyway, permanently destroying unmerged commits.

To provide true atomicity, the cleanup engine uses **Git transport atomic reference deletion with an explicit expected-SHA lease**:

```bash
git push --force-with-lease=refs/heads/<branch>:<expected_sha> origin :refs/heads/<branch>
```

- **Server-Side Atomic Compare-and-Swap (CAS):** The Git server executes the lease check and deletion in a single atomic transaction.
- **Concurrent Commits Preserved:** If the remote branch moves or receives new commits at any millisecond before deletion, the server immediately rejects the push with `(stale info)`. The engine catches this rejection, aborts the operation, classifies the outcome as `CONCURRENT_MODIFICATION_ABORTED`, and guarantees the branch remains preserved.
- **No Unsafe REST Fallback:** The workflow never falls back to unconditioned REST deletion. If conditional Git transport fails for any reason, the branch remains intact.
- **PR Re-verification:** Pull request merge status and target base branch are re-verified immediately prior to deletion to defend against reopened or modified pull requests.

### Execution modes

The cleanup workflow is strictly **manual (`workflow_dispatch`)** and restricted to execution from `main`:

- **Dry-run simulation (Default):** Run with `dry_run: true` (or leave as default). The inspection job runs with read-only permissions (`contents: read`, `pull-requests: read`), audits all candidate branches, logs the classification for each branch, and publishes a complete Markdown breakdown to the workflow step summary. No branch is deleted.
- **Explicit live cleanup:** Triggered only by explicitly setting `dry_run: false`. Only branches verified as eligible in the planning phase are forwarded to the deletion job, which operates under least-privilege `contents: write` permissions and re-verifies ref integrity immediately before issuing the deletion API call.
- **Branch filter:** An optional `branch_filter` input allows targeting specific branches or patterns (e.g. `feat/*`, `dependabot/*`) while preserving all other branches.

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
