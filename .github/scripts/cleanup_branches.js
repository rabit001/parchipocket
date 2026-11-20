/**
 * ParchiPocket Safe Branch Cleanup Automation Engine
 *
 * Implements conservative, auditable, and recoverable branch cleanup.
 * A branch is NEVER deleted merely because it has no open pull request.
 * Deletion strictly requires proof of successful integration into the protected
 * target branch (normally 'main') via a merged pull request with matching head commit SHA.
 *
 * Concurrency Safety:
 * Reference deletion is executed atomically via Git transport:
 * git push --force-with-lease=refs/heads/<branch>:<expected_sha> origin :refs/heads/<branch>
 * This eliminates the TOCTOU race condition present in the REST deleteRef endpoint.
 */

'use strict';

/**
 * Determines whether a branch is permanently protected from deletion.
 *
 * @param {string} branchName
 * @param {string} [defaultBranch='main']
 * @param {boolean} [isRepoProtected=false]
 * @returns {boolean}
 */
function isProtectedBranch(branchName, defaultBranch = 'main', isRepoProtected = false) {
  if (!branchName) return true;

  // 1. Canonical long-lived repository branches
  if (branchName === 'main' || branchName === 'develop') {
    return true;
  }

  // 2. Repository default branch
  if (defaultBranch && branchName === defaultBranch) {
    return true;
  }

  // 3. GitHub repository ruleset / branch protection setting
  if (isRepoProtected === true) {
    return true;
  }

  // 4. Release and version branch prefixes
  if (/^release(\/|-)/i.test(branchName)) return true;
  if (/^beta(\/|-)/i.test(branchName)) return true;
  if (/^v\d+(\.\d+)*/i.test(branchName)) return true;

  // 5. Explicit reserved permanent branch names
  const reserved = new Set(['master', 'staging', 'production', 'release', 'beta']);
  if (reserved.has(branchName.toLowerCase())) {
    return true;
  }

  return false;
}

/**
 * Evaluates a single candidate branch against safety rules.
 *
 * @param {Object} params
 * @param {Object} params.github Octokit API client
 * @param {string} params.owner Repository owner
 * @param {string} params.repo Repository name
 * @param {Object} params.branch Branch metadata { name, commit: { sha }, protected: boolean }
 * @param {string} params.targetBranch Target integration branch (e.g. 'main')
 * @param {string} params.defaultBranch Repository default branch
 * @returns {Promise<Object>} Evaluation result
 */
async function evaluateBranch({ github, owner, repo, branch, targetBranch, defaultBranch }) {
  const branchName = branch.name;
  const liveSha = branch.commit ? branch.commit.sha : null;

  // Rule B: Protect important branches
  if (isProtectedBranch(branchName, defaultBranch, branch.protected)) {
    return {
      name: branchName,
      status: 'PROTECTED',
      reason: 'PROTECTED_BRANCH',
      detail: `Branch '${branchName}' is protected (canonical, default, release, or GitHub-protected).`,
      eligible: false
    };
  }

  // Fetch pull requests associated with this head branch (with pagination)
  let prs = [];
  try {
    prs = await github.paginate(github.rest.pulls.list, {
      owner,
      repo,
      head: `${owner}:${branchName}`,
      state: 'all',
      per_page: 100
    });
  } catch (error) {
    // Rule C & E: If PR lookup fails (API error / rate limit), fail safe and preserve branch
    return {
      name: branchName,
      status: 'PRESERVED',
      reason: 'API_ERROR',
      detail: `GitHub API error fetching pull requests: ${error.message}. Preserving branch for safety.`,
      eligible: false
    };
  }

  // Rule A & C: Check for any open pull requests
  const openPRs = prs.filter(pr => pr.state === 'open');
  if (openPRs.length > 0) {
    const prList = openPRs.map(p => `#${p.number}`).join(', ');
    return {
      name: branchName,
      status: 'PRESERVED',
      reason: 'OPEN_PR',
      detail: `Branch has active open pull request(s) (${prList}).`,
      eligible: false
    };
  }

  // Rule A & C: If no pull requests exist at all, preserve branch
  if (prs.length === 0) {
    return {
      name: branchName,
      status: 'PRESERVED',
      reason: 'NO_PR',
      detail: 'No pull requests found for this branch. Cannot prove integration.',
      eligible: false
    };
  }

  // Rule A: Filter for merged pull requests targeting the intended target branch (e.g. 'main')
  const mergedTargetPRs = prs.filter(pr => {
    return Boolean(pr.merged_at) && pr.base && pr.base.ref === targetBranch;
  });

  if (mergedTargetPRs.length === 0) {
    // Check if PR was merged into another branch (not targetBranch)
    const otherMerged = prs.filter(pr => Boolean(pr.merged_at));
    if (otherMerged.length > 0) {
      const bases = otherMerged.map(p => `${p.base ? p.base.ref : 'unknown'} (PR #${p.number})`).join(', ');
      return {
        name: branchName,
        status: 'PRESERVED',
        reason: 'TARGET_BRANCH_MISMATCH',
        detail: `Pull request was merged into non-target base: ${bases}, but not into '${targetBranch}'.`,
        eligible: false
      };
    }

    // PRs exist, but were closed without merging
    const closedList = prs.map(p => `#${p.number}`).join(', ');
    return {
      name: branchName,
      status: 'PRESERVED',
      reason: 'CLOSED_UNMERGED',
      detail: `Pull request(s) (${closedList}) were closed without being merged. Work may be unintegrated.`,
      eligible: false
    };
  }

  // Sort by merged_at descending to inspect the most recently merged PR
  mergedTargetPRs.sort((a, b) => new Date(b.merged_at).getTime() - new Date(a.merged_at).getTime());
  const qualifyingPR = mergedTargetPRs[0];
  const prHeadSha = qualifyingPR.head ? qualifyingPR.head.sha : null;

  // Rule A & C: Check commit SHA integrity
  // If live branch SHA does not match PR head SHA, the branch moved forward with unmerged commits
  if (!liveSha || !prHeadSha || liveSha !== prHeadSha) {
    return {
      name: branchName,
      status: 'PRESERVED',
      reason: 'BRANCH_MOVED_AFTER_MERGE',
      detail: `Branch commit SHA (${(liveSha || '').slice(0, 7)}) differs from merged PR #${qualifyingPR.number} head SHA (${(prHeadSha || '').slice(0, 7)}). Unmerged commits exist.`,
      eligible: false
    };
  }

  // All safety checks satisfied
  return {
    name: branchName,
    status: 'ELIGIBLE',
    reason: 'INTEGRATED_VIA_MERGED_PR',
    detail: `Integrated into '${targetBranch}' via merged PR #${qualifyingPR.number} on ${qualifyingPR.merged_at} with matching commit SHA ${(liveSha || '').slice(0, 7)}.`,
    eligible: true,
    prNumber: qualifyingPR.number,
    expectedSha: liveSha
  };
}

/**
 * Plans branch cleanup by evaluating all repository branches against safety rules.
 *
 * @param {Object} params
 * @param {Object} params.github
 * @param {Object} params.context
 * @param {Object} params.core
 * @param {Object} params.options
 * @returns {Promise<Object>}
 */
async function evaluateAndPlan({ github, context, core, options = {} }) {
  const { owner, repo } = context.repo;
  const targetBranch = options.targetBranch || 'main';
  const dryRun = options.dryRun !== false;
  const branchFilter = options.branchFilter ? options.branchFilter.trim() : '';

  core.info('====================================================');
  core.info('PARCHIPOCKET SAFE BRANCH CLEANUP - EVALUATION PHASE');
  core.info(`Repository:     ${owner}/${repo}`);
  core.info(`Target Branch:  ${targetBranch}`);
  core.info(`Dry Run Mode:   ${dryRun ? 'TRUE (simulation only)' : 'FALSE (destructive)'}`);
  if (branchFilter) {
    core.info(`Branch Filter:  ${branchFilter}`);
  }
  core.info('====================================================');

  // Discover repository metadata to determine default branch
  let defaultBranch = 'main';
  try {
    const repoInfo = await github.rest.repos.get({ owner, repo });
    defaultBranch = repoInfo.data.default_branch || 'main';
  } catch (err) {
    core.warning(`Could not fetch repo metadata (${err.message}); defaulting defaultBranch to 'main'.`);
  }

  // Fetch all repository branches with pagination
  let allBranches = [];
  try {
    allBranches = await github.paginate(github.rest.repos.listBranches, {
      owner,
      repo,
      per_page: 100
    });
  } catch (err) {
    core.setFailed(`Failed to list repository branches: ${err.message}`);
    throw err;
  }

  core.info(`Discovered ${allBranches.length} branch(es) in repository.`);

  // Optional filter
  let candidateBranches = allBranches;
  if (branchFilter) {
    let filterRegex;
    try {
      filterRegex = new RegExp(branchFilter);
    } catch {
      filterRegex = new RegExp(`^${branchFilter.replace(/\*/g, '.*')}$`);
    }
    candidateBranches = allBranches.filter(b => filterRegex.test(b.name));
    core.info(`Filtered down to ${candidateBranches.length} candidate branch(es) matching '${branchFilter}'.`);
  }

  const results = {
    eligible: [],
    protected: [],
    preserved: []
  };

  for (const branch of candidateBranches) {
    const evaluation = await evaluateBranch({
      github,
      owner,
      repo,
      branch,
      targetBranch,
      defaultBranch
    });

    if (evaluation.status === 'ELIGIBLE') {
      results.eligible.push(evaluation);
      core.info(`[ELIGIBLE]  ${evaluation.name} -> ${evaluation.detail}`);
    } else if (evaluation.status === 'PROTECTED') {
      results.protected.push(evaluation);
      core.info(`[PROTECTED] ${evaluation.name} -> ${evaluation.detail}`);
    } else {
      results.preserved.push(evaluation);
      core.info(`[PRESERVED] ${evaluation.name} [${evaluation.reason}] -> ${evaluation.detail}`);
    }
  }

  // Summary counts
  const eligibleCount = results.eligible.length;
  const protectedCount = results.protected.length;
  const preservedCount = results.preserved.length;

  core.info('----------------------------------------------------');
  core.info('EVALUATION SUMMARY:');
  core.info(`  Total Evaluated: ${candidateBranches.length}`);
  core.info(`  Protected:       ${protectedCount}`);
  core.info(`  Preserved:       ${preservedCount}`);
  core.info(`  Eligible:        ${eligibleCount}`);
  core.info('----------------------------------------------------');

  if (dryRun) {
    core.info('[DRY RUN ACTIVE] No branches were deleted.');
  }

  // Format step summary markdown for GitHub Actions UI
  if (process.env.GITHUB_STEP_SUMMARY) {
    const summaryRows = [
      '# Branch Cleanup Evaluation Plan',
      '',
      `| Metric | Value |`,
      `| :--- | :--- |`,
      `| **Execution Mode** | ${dryRun ? '🔍 Dry Run (Safe Simulation)' : '⚡ Live Execution'} |`,
      `| **Target Branch** | \`${targetBranch}\` |`,
      `| **Total Branches** | ${candidateBranches.length} |`,
      `| **Protected** | ${protectedCount} |`,
      `| **Preserved** | ${preservedCount} |`,
      `| **Eligible for Cleanup** | ${eligibleCount} |`,
      '',
      '## Detailed Breakdown',
      '',
      '| Branch | Classification | Reason / Evidence |',
      '| :--- | :--- | :--- |'
    ];

    for (const item of results.protected) {
      summaryRows.push(`| \`${item.name}\` | 🛡️ Protected | ${item.detail} |`);
    }
    for (const item of results.preserved) {
      summaryRows.push(`| \`${item.name}\` | ⏸️ Preserved (${item.reason}) | ${item.detail} |`);
    }
    for (const item of results.eligible) {
      summaryRows.push(`| \`${item.name}\` | ✅ **Eligible** | ${item.detail} |`);
    }

    try {
      const fs = require('fs');
      fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summaryRows.join('\n') + '\n', 'utf8');
    } catch {
      // Step summary failure must not break execution
    }
  }

  // Export outputs for downstream GitHub Actions steps/jobs
  if (core.setOutput) {
    const eligibleJson = JSON.stringify(results.eligible.map(e => ({
      name: e.name,
      expectedSha: e.expectedSha,
      prNumber: e.prNumber
    })));
    core.setOutput('eligible_branches', eligibleJson);
    core.setOutput('eligible_count', String(eligibleCount));
    core.setOutput('dry_run', String(dryRun));
  }

  return results;
}

/**
 * Safely deletes a remote branch using atomic Git transport with an explicit expected-SHA lease.
 *
 * Command form:
 * git push --force-with-lease=refs/heads/<branch>:<expected_sha> origin :refs/heads/<branch>
 *
 * @param {Object} params
 * @param {string} params.branchName Candidate branch name
 * @param {string} params.expectedSha Full 40-character commit SHA verified during evaluation
 * @param {string} [params.remote='origin'] Remote name
 * @param {Function} [params.execFn] Optional injected runner for execution
 * @returns {Object} { success: boolean, outcome: string, detail: string, error?: string }
 */
function deleteBranchWithLease({ branchName, expectedSha, remote = 'origin', execFn = null }) {
  // 1. Validate branch name
  if (!branchName || typeof branchName !== 'string') {
    return {
      success: false,
      outcome: 'INVALID_INPUT',
      detail: 'Branch name is missing or invalid'
    };
  }
  const cleanBranch = branchName.trim();
  if (
    cleanBranch.startsWith('-') ||
    cleanBranch.includes('..') ||
    cleanBranch.includes('*') ||
    cleanBranch.includes('~') ||
    cleanBranch.includes('^') ||
    cleanBranch.includes(':') ||
    cleanBranch.includes(' ')
  ) {
    return {
      success: false,
      outcome: 'INVALID_INPUT',
      detail: `Branch name '${cleanBranch}' contains illegal characters, wildcards, or formatting`
    };
  }

  // 2. Validate expected SHA (must be 40-character hexadecimal string)
  if (!expectedSha || !/^[0-9a-f]{40}$/i.test(expectedSha)) {
    return {
      success: false,
      outcome: 'INVALID_EXPECTED_SHA',
      detail: `Expected SHA for branch '${cleanBranch}' is missing or malformed: '${expectedSha}'`
    };
  }

  const fullRef = `refs/heads/${cleanBranch}`;
  const leaseArg = `--force-with-lease=${fullRef}:${expectedSha}`;
  const deleteRefspec = `:${fullRef}`;

  const gitArgs = [
    'push',
    leaseArg,
    remote,
    deleteRefspec
  ];

  const runner = execFn || ((args) => {
    const { execFileSync } = require('child_process');
    return execFileSync('git', args, {
      stdio: 'pipe',
      encoding: 'utf8'
    });
  });

  try {
    const stdout = runner(gitArgs);
    return {
      success: true,
      outcome: 'DELETED',
      detail: `Deleted '${cleanBranch}' atomically via Git transport (lease verified SHA ${expectedSha.slice(0, 7)})`,
      stdout: stdout ? stdout.toString() : ''
    };
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString() : (err.message || '');
    const combined = `${stderr} ${err.stdout ? err.stdout.toString() : ''}`;

    // Detect atomic compare-and-swap lease rejection from Git transport
    if (/stale info|\[rejected\]/i.test(combined)) {
      return {
        success: false,
        outcome: 'CONCURRENT_MODIFICATION_ABORTED',
        detail: `Git server rejected conditional deletion: remote ref '${cleanBranch}' changed or moved (stale info). Branch preserved.`,
        error: stderr.trim()
      };
    }

    // Detect ref already absent on remote
    if (/remote ref does not exist|unable to delete/i.test(combined)) {
      return {
        success: false,
        outcome: 'ALREADY_ABSENT',
        detail: `Remote ref '${cleanBranch}' is already absent on '${remote}'.`,
        error: stderr.trim()
      };
    }

    // Generic git failure - fail safe, DO NOT fall back to unguarded REST deletion!
    return {
      success: false,
      outcome: 'GIT_ERROR',
      detail: `Git push conditional deletion failed for '${cleanBranch}': ${stderr.trim() || err.message}`,
      error: stderr.trim() || err.message
    };
  }
}

/**
 * Executes verified branch deletion with atomic Git transport concurrency checks.
 *
 * @param {Object} params
 * @param {Object} params.github
 * @param {Object} params.context
 * @param {Object} params.core
 * @param {Array<Object>} params.eligibleBranches
 * @param {Object} params.options
 * @param {Function} [params.execGit] Optional injected Git runner
 * @returns {Promise<Object>} Deletion execution report
 */
async function executeDeletion({ github, context, core, eligibleBranches = [], options = {}, execGit = null }) {
  const { owner, repo } = context.repo;
  const targetBranch = options.targetBranch || 'main';
  const remote = options.remote || 'origin';

  core.info('====================================================');
  core.info('PARCHIPOCKET SAFE BRANCH CLEANUP - ATOMIC EXECUTION');
  core.info(`Repository:     ${owner}/${repo}`);
  core.info(`Target Branch:  ${targetBranch}`);
  core.info(`Remote:         ${remote}`);
  core.info(`Branches:       ${eligibleBranches.length}`);
  core.info('====================================================');

  const report = {
    deleted: [],
    skipped: [],
    failed: []
  };

  if (eligibleBranches.length === 0) {
    core.info('No eligible branches to delete.');
    return report;
  }

  for (const branch of eligibleBranches) {
    const branchName = branch.name;
    const expectedSha = branch.expectedSha;
    const prNumber = branch.prNumber;

    core.info(`Checking branch before atomic deletion: '${branchName}' (expected SHA: ${(expectedSha || '').slice(0, 7)})`);

    // Safety 1: Never delete protected branch regardless of prior eligibility payload
    if (isProtectedBranch(branchName, targetBranch)) {
      core.warning(`SAFETY ABORT: Refusing to delete protected branch '${branchName}'.`);
      report.skipped.push({ name: branchName, reason: 'PROTECTED_SAFETY_OVERRIDE' });
      continue;
    }

    // Safety 2: Validate expected SHA exists and is valid 40-char hex
    if (!expectedSha || !/^[0-9a-f]{40}$/i.test(expectedSha)) {
      core.warning(`SAFETY ABORT: Missing or malformed expected SHA for '${branchName}': '${expectedSha}'.`);
      report.skipped.push({ name: branchName, reason: 'INVALID_EXPECTED_SHA' });
      continue;
    }

    // Safety 3: Re-verify qualifying PR status via API to guard against reopened/tampered PR
    if (prNumber) {
      try {
        const prResponse = await github.rest.pulls.get({
          owner,
          repo,
          pull_number: prNumber
        });
        const pr = prResponse.data;
        if (!pr.merged_at || !pr.base || pr.base.ref !== targetBranch) {
          core.warning(`SAFETY ABORT: PR #${prNumber} is no longer recorded as merged into '${targetBranch}'. Skipping '${branchName}'.`);
          report.skipped.push({ name: branchName, reason: 'PR_STATUS_CHANGED' });
          continue;
        }
        if (pr.head && pr.head.sha && pr.head.sha !== expectedSha) {
          core.warning(`SAFETY ABORT: PR #${prNumber} head SHA changed (${pr.head.sha} != ${expectedSha}). Skipping '${branchName}'.`);
          report.skipped.push({ name: branchName, reason: 'PR_SHA_CHANGED' });
          continue;
        }
      } catch (err) {
        core.warning(`Could not re-verify PR #${prNumber} (${err.message}). Skipping '${branchName}' for safety.`);
        report.skipped.push({ name: branchName, reason: 'PR_VERIFICATION_FAILED' });
        continue;
      }
    }

    // Safety 4: Execute ATOMIC CONDITIONAL DELETION via Git transport
    // git push --force-with-lease=refs/heads/<branch>:<expectedSha> origin :refs/heads/<branch>
    const result = deleteBranchWithLease({
      branchName,
      expectedSha,
      remote,
      execFn: execGit
    });

    if (result.success) {
      core.info(`Successfully deleted integrated branch: '${branchName}'`);
      report.deleted.push({ name: branchName, sha: expectedSha });
    } else if (result.outcome === 'CONCURRENT_MODIFICATION_ABORTED') {
      core.warning(`CONCURRENCY LEASE ABORT: ${result.detail}`);
      report.skipped.push({ name: branchName, reason: 'CONCURRENT_MODIFICATION_ABORTED', detail: result.detail });
    } else if (result.outcome === 'ALREADY_ABSENT') {
      core.info(`Branch '${branchName}' was already absent on remote.`);
      report.skipped.push({ name: branchName, reason: 'ALREADY_ABSENT' });
    } else {
      core.error(`Failed to delete branch '${branchName}': ${result.detail}`);
      report.failed.push({ name: branchName, error: result.detail });
    }
  }

  core.info('----------------------------------------------------');
  core.info('EXECUTION REPORT:');
  core.info(`  Deleted: ${report.deleted.length}`);
  core.info(`  Skipped: ${report.skipped.length}`);
  core.info(`  Failed:  ${report.failed.length}`);
  core.info('----------------------------------------------------');

  return report;
}

module.exports = {
  isProtectedBranch,
  evaluateBranch,
  evaluateAndPlan,
  deleteBranchWithLease,
  executeDeletion
};
