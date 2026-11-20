/**
 * ParchiPocket Safe Branch Cleanup Automation Test Suite
 *
 * Covers all safety, security, and atomic concurrency verification cases:
 * 1. Fully merged PR with unchanged branch SHA is evaluated as ELIGIBLE
 * 2. Branch with no PR is PRESERVED (NO_PR)
 * 3. Closed but unmerged PR is PRESERVED (CLOSED_UNMERGED)
 * 4. Open PR is PRESERVED (OPEN_PR)
 * 5. Merged PR targeting wrong base branch is PRESERVED (TARGET_BRANCH_MISMATCH)
 * 6. Branch containing new commits after PR merge is PRESERVED (BRANCH_MOVED_AFTER_MERGE)
 * 7. Main branch protection is strictly enforced
 * 8. Develop branch protection is strictly enforced
 * 9. Repository default branch protection is enforced even if not named main
 * 10. Protected release branch handling (release/*, beta/*, v*, staging, production)
 * 11. API pagination handles multi-page branch and PR responses
 * 12. API errors and rate-limit failures fail safe and preserve branches
 * 13. Expected SHA missing or malformed causes safe rejection (deleteBranchWithLease)
 * 14. Dangerous or malformed branch names are rejected
 * 15. Dry-run mode never calls deletion commands
 * 16. Unexpected git failure is reported without falling back to unsafe REST deleteRef
 * 17. Real isolated bare Git repo: Unchanged remote branch SHA allows atomic conditional deletion
 * 18. Real isolated bare Git repo: Branch moved before conditional deletion causes lease failure (TOCTOU race) and concurrent commit remains reachable
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execSync } = require('node:child_process');
const engine = require('./.github/scripts/cleanup_branches.js');

/**
 * Creates a mocked GitHub Octokit client and context.
 */
function createMockHarness(options = {}) {
  const {
    repoData = { default_branch: 'main' },
    branches = [],
    pullsByBranch = {},
    pullsByNumber = {},
    refs = {},
    paginateError = null,
    deleteRefCalls = [],
    getRefCalls = []
  } = options;

  const github = {
    rest: {
      repos: {
        get: async () => ({ data: repoData }),
        listBranches: async () => ({ data: branches })
      },
      pulls: {
        list: async (params) => {
          const head = params.head;
          return { data: pullsByBranch[head] || [] };
        },
        get: async (params) => {
          const pr = pullsByNumber[params.pull_number];
          if (!pr) throw { status: 404, message: 'Not found' };
          return { data: pr };
        }
      },
      git: {
        getRef: async (params) => {
          getRefCalls.push(params);
          const refKey = params.ref;
          if (refs[refKey]) {
            return { data: { object: { sha: refs[refKey] } } };
          }
          throw { status: 404, message: 'Reference does not exist' };
        },
        deleteRef: async (params) => {
          deleteRefCalls.push(params);
          throw new Error('SECURITY VIOLATION: github.rest.git.deleteRef must NEVER be invoked!');
        }
      }
    },
    paginate: async (method, params) => {
      if (paginateError) {
        throw paginateError;
      }
      if (options.paginateHandler) {
        return options.paginateHandler(method, params);
      }
      const res = await method(params);
      return res.data;
    }
  };

  const context = {
    repo: {
      owner: 'rabit001',
      repo: 'parchipocket'
    }
  };

  const logged = {
    info: [],
    warning: [],
    error: []
  };

  const outputs = {};

  const core = {
    info: (msg) => logged.info.push(msg),
    warning: (msg) => logged.warning.push(msg),
    error: (msg) => logged.error.push(msg),
    setOutput: (key, val) => { outputs[key] = val; },
    setFailed: (msg) => { throw new Error(msg); }
  };

  return { github, context, core, logged, outputs, deleteRefCalls, getRefCalls };
}

// --------------------------------------------------------------------------
// BRANCH EVALUATION & LOGIC UNIT TESTS
// --------------------------------------------------------------------------

test('1. Fully merged PR with unchanged branch SHA is evaluated as ELIGIBLE', async () => {
  const branchSha = 'aaaa111122223333444455556666777788889999';
  const branch = {
    name: 'feature/completed-task',
    commit: { sha: branchSha },
    protected: false
  };

  const pr = {
    number: 101,
    state: 'closed',
    merged_at: '2026-11-19T12:00:00Z',
    base: { ref: 'main' },
    head: { sha: branchSha, ref: 'feature/completed-task' }
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/completed-task': [pr]
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'ELIGIBLE');
  assert.strictEqual(res.eligible, true);
  assert.strictEqual(res.prNumber, 101);
  assert.strictEqual(res.expectedSha, branchSha);
  assert.match(res.detail, /Integrated into 'main'/);
});

test('2. Branch with no PR is PRESERVED', async () => {
  const branch = {
    name: 'feature/unsubmitted-work',
    commit: { sha: 'bbbb111122223333444455556666777788889999' },
    protected: false
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/unsubmitted-work': []
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'NO_PR');
  assert.match(res.detail, /No pull requests found/);
});

test('3. Closed but unmerged PR is PRESERVED', async () => {
  const branch = {
    name: 'feature/abandoned-idea',
    commit: { sha: 'cccc111122223333444455556666777788889999' },
    protected: false
  };

  const pr = {
    number: 102,
    state: 'closed',
    merged_at: null,
    base: { ref: 'main' },
    head: { sha: 'cccc111122223333444455556666777788889999', ref: 'feature/abandoned-idea' }
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/abandoned-idea': [pr]
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'CLOSED_UNMERGED');
  assert.match(res.detail, /closed without being merged/);
});

test('4. Open PR is PRESERVED', async () => {
  const branch = {
    name: 'feature/active-work',
    commit: { sha: 'dddd111122223333444455556666777788889999' },
    protected: false
  };

  const pr = {
    number: 103,
    state: 'open',
    merged_at: null,
    base: { ref: 'main' },
    head: { sha: 'dddd111122223333444455556666777788889999', ref: 'feature/active-work' }
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/active-work': [pr]
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'OPEN_PR');
  assert.match(res.detail, /active open pull request/);
});

test('5. Merged PR targeting wrong base branch is PRESERVED', async () => {
  const branchSha = 'eeee111122223333444455556666777788889999';
  const branch = {
    name: 'feature/intermediate-step',
    commit: { sha: branchSha },
    protected: false
  };

  const pr = {
    number: 104,
    state: 'closed',
    merged_at: '2026-11-19T10:00:00Z',
    base: { ref: 'feature/some-epic' },
    head: { sha: branchSha, ref: 'feature/intermediate-step' }
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/intermediate-step': [pr]
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'TARGET_BRANCH_MISMATCH');
  assert.match(res.detail, /merged into non-target base/);
});

test('6. Branch containing new commits after PR merge is PRESERVED (SHA mismatch)', async () => {
  const prMergedSha = 'ffff111122223333444455556666777788889999';
  const branchLiveSha = 'ffff999988887777666655554444333322221111';

  const branch = {
    name: 'feature/continuation',
    commit: { sha: branchLiveSha },
    protected: false
  };

  const pr = {
    number: 105,
    state: 'closed',
    merged_at: '2026-11-18T12:00:00Z',
    base: { ref: 'main' },
    head: { sha: prMergedSha, ref: 'feature/continuation' }
  };

  const { github } = createMockHarness({
    pullsByBranch: {
      'rabit001:feature/continuation': [pr]
    }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'BRANCH_MOVED_AFTER_MERGE');
  assert.match(res.detail, /differs from merged PR/);
});

test('7. Main branch protection is strictly enforced', async () => {
  const branch = {
    name: 'main',
    commit: { sha: '1111222233334444555566667777888899990000' },
    protected: false
  };

  const { github } = createMockHarness();
  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PROTECTED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(engine.isProtectedBranch('main'), true);
});

test('8. Develop branch protection is strictly enforced', async () => {
  const branch = {
    name: 'develop',
    commit: { sha: '2222333344445555666677778888999900001111' },
    protected: false
  };

  const { github } = createMockHarness();
  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PROTECTED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(engine.isProtectedBranch('develop'), true);
});

test('9. Repository default branch protection is enforced even if not named main', async () => {
  const branch = {
    name: 'production-canon',
    commit: { sha: '3333444455556666777788889999000011112222' },
    protected: false
  };

  const { github } = createMockHarness();
  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'production-canon'
  });

  assert.strictEqual(res.status, 'PROTECTED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(engine.isProtectedBranch('production-canon', 'production-canon'), true);
});

test('10. Protected release branch handling (release/*, beta/*, v*, staging, production)', () => {
  assert.strictEqual(engine.isProtectedBranch('release/v1.0.0'), true);
  assert.strictEqual(engine.isProtectedBranch('release-2026'), true);
  assert.strictEqual(engine.isProtectedBranch('beta/v0.1.5'), true);
  assert.strictEqual(engine.isProtectedBranch('beta-preview'), true);
  assert.strictEqual(engine.isProtectedBranch('v1.2.3'), true);
  assert.strictEqual(engine.isProtectedBranch('staging'), true);
  assert.strictEqual(engine.isProtectedBranch('production'), true);
  assert.strictEqual(engine.isProtectedBranch('feature/safe-to-delete'), false);
});

test('11. API pagination handles multi-page branch and PR responses', async () => {
  const page1 = [
    { name: 'main', commit: { sha: 'sha-main' }, protected: true },
    { name: 'develop', commit: { sha: 'sha-dev' }, protected: false }
  ];
  const page2 = [
    { name: 'branch-page2', commit: { sha: 'sha-p2' }, protected: false }
  ];
  const page3 = [
    { name: 'branch-page3', commit: { sha: 'sha-p3' }, protected: false }
  ];

  let paginateCallCount = 0;
  const harness = createMockHarness({
    paginateHandler: async (method, params) => {
      paginateCallCount++;
      if (method === harness.github.rest.repos.listBranches) {
        return [...page1, ...page2, ...page3];
      }
      if (method === harness.github.rest.pulls.list) {
        if (params.head === 'rabit001:branch-page2') {
          return [{
            number: 201,
            state: 'closed',
            merged_at: '2026-11-19T00:00:00Z',
            base: { ref: 'main' },
            head: { sha: 'sha-p2', ref: 'branch-page2' }
          }];
        }
        return [];
      }
      return [];
    }
  });

  const plan = await engine.evaluateAndPlan({
    github: harness.github,
    context: harness.context,
    core: harness.core,
    options: { dryRun: true, targetBranch: 'main' }
  });

  assert.strictEqual(paginateCallCount >= 3, true);
  assert.strictEqual(plan.eligible.length, 1);
  assert.strictEqual(plan.eligible[0].name, 'branch-page2');
  assert.strictEqual(plan.protected.length, 2);
  assert.strictEqual(plan.preserved.length, 1);
});

test('12. API errors and rate-limit failures fail safe and preserve branches', async () => {
  const branch = {
    name: 'feature/api-failure-test',
    commit: { sha: 'error-sha' },
    protected: false
  };

  const { github } = createMockHarness({
    paginateError: { status: 403, message: 'API rate limit exceeded' }
  });

  const res = await engine.evaluateBranch({
    github,
    owner: 'rabit001',
    repo: 'parchipocket',
    branch,
    targetBranch: 'main',
    defaultBranch: 'main'
  });

  assert.strictEqual(res.status, 'PRESERVED');
  assert.strictEqual(res.eligible, false);
  assert.strictEqual(res.reason, 'API_ERROR');
  assert.match(res.detail, /API rate limit exceeded/);
});

// --------------------------------------------------------------------------
// CONDITIONAL GIT DELETION & ATOMIC LEASE TESTS
// --------------------------------------------------------------------------

test('13. Expected SHA missing or malformed causes safe rejection in deleteBranchWithLease', () => {
  // Empty SHA
  const res1 = engine.deleteBranchWithLease({ branchName: 'feature/test', expectedSha: '' });
  assert.strictEqual(res1.success, false);
  assert.strictEqual(res1.outcome, 'INVALID_EXPECTED_SHA');

  // Short SHA (not 40 chars)
  const res2 = engine.deleteBranchWithLease({ branchName: 'feature/test', expectedSha: 'abc123' });
  assert.strictEqual(res2.success, false);
  assert.strictEqual(res2.outcome, 'INVALID_EXPECTED_SHA');

  // Non-hex SHA
  const res3 = engine.deleteBranchWithLease({ branchName: 'feature/test', expectedSha: 'zzzz111122223333444455556666777788889999' });
  assert.strictEqual(res3.success, false);
  assert.strictEqual(res3.outcome, 'INVALID_EXPECTED_SHA');
});

test('14. Dangerous or malformed branch names are safely rejected', () => {
  const validSha = 'aaaa111122223333444455556666777788889999';

  const badBranches = [
    '-rf',
    '--delete',
    'feature/../main',
    'feature/*',
    'feature:other',
    'feature branch'
  ];

  for (const b of badBranches) {
    const res = engine.deleteBranchWithLease({ branchName: b, expectedSha: validSha });
    assert.strictEqual(res.success, false, `Expected failure for dangerous branch: ${b}`);
    assert.strictEqual(res.outcome, 'INVALID_INPUT');
  }
});

test('15. Dry-run mode never calls deletion commands', async () => {
  const branchSha = 'eligible-sha-44445555666677778888999900001111';
  const branch = {
    name: 'feature/dry-run-test',
    commit: { sha: branchSha },
    protected: false
  };

  const pr = {
    number: 401,
    state: 'closed',
    merged_at: '2026-11-19T12:00:00Z',
    base: { ref: 'main' },
    head: { sha: branchSha, ref: 'feature/dry-run-test' }
  };

  const harness = createMockHarness({
    branches: [branch],
    pullsByBranch: {
      'rabit001:feature/dry-run-test': [pr]
    }
  });

  const plan = await engine.evaluateAndPlan({
    github: harness.github,
    context: harness.context,
    core: harness.core,
    options: { dryRun: true, targetBranch: 'main' }
  });

  assert.strictEqual(plan.eligible.length, 1);
  assert.strictEqual(harness.deleteRefCalls.length, 0);
  assert.strictEqual(harness.outputs.dry_run, 'true');
});

test('16. Unexpected git failure is reported without falling back to unsafe REST deleteRef', async () => {
  const branchSha = '5555666677778888999900001111222233334444';
  const eligibleBranch = {
    name: 'feature/network-failure-test',
    expectedSha: branchSha,
    prNumber: 501
  };

  const harness = createMockHarness({
    pullsByNumber: {
      501: {
        number: 501,
        merged_at: '2026-11-19T12:00:00Z',
        base: { ref: 'main' },
        head: { sha: branchSha }
      }
    }
  });

  // Inject a simulated git failure (e.g. network timeout or transport failure)
  const simulatedGitRunner = () => {
    const error = new Error('Connection reset by peer');
    error.stderr = Buffer.from('fatal: unable to access https://github.com/... Connection reset by peer');
    throw error;
  };

  const report = await engine.executeDeletion({
    github: harness.github,
    context: harness.context,
    core: harness.core,
    eligibleBranches: [eligibleBranch],
    options: { targetBranch: 'main' },
    execGit: simulatedGitRunner
  });

  // Verify failure is reported, branch is preserved, and REST deleteRef was NEVER called
  assert.strictEqual(report.deleted.length, 0);
  assert.strictEqual(report.failed.length, 1);
  assert.strictEqual(harness.deleteRefCalls.length, 0);
  assert.match(report.failed[0].error, /Connection reset by peer/);
});

// --------------------------------------------------------------------------
// ISOLATED LOCAL BARE REPOSITORY TESTS FOR --force-with-lease ATOMIC DELETION
// --------------------------------------------------------------------------

test('17. Real isolated bare Git repo: Unchanged remote branch SHA allows atomic conditional deletion', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'git-bare-test-'));
  const remoteDir = path.join(tempDir, 'remote.git');
  const localDir = path.join(tempDir, 'local');

  try {
    // Set up bare remote and local clone
    execSync(`git init --bare "${remoteDir}"`, { stdio: 'pipe' });
    execSync(`git clone "${remoteDir}" "${localDir}"`, { stdio: 'pipe' });
    execSync('git config user.name "Tester"', { cwd: localDir, stdio: 'pipe' });
    execSync('git config user.email "tester@example.com"', { cwd: localDir, stdio: 'pipe' });

    // Initial commit on main
    fs.writeFileSync(path.join(localDir, 'main.txt'), 'main init');
    execSync('git checkout -b main', { cwd: localDir, stdio: 'pipe' });
    execSync('git add . && git commit -m "init main"', { cwd: localDir, stdio: 'pipe' });
    execSync('git push origin main', { cwd: localDir, stdio: 'pipe' });

    // Create and push feature branch
    execSync('git checkout -b feature/test-pass', { cwd: localDir, stdio: 'pipe' });
    fs.writeFileSync(path.join(localDir, 'feat.txt'), 'feature code');
    execSync('git add . && git commit -m "feat commit"', { cwd: localDir, stdio: 'pipe' });
    execSync('git push origin feature/test-pass', { cwd: localDir, stdio: 'pipe' });

    const expectedSha = execSync('git rev-parse HEAD', { cwd: localDir }).toString().trim();

    // Execute atomic conditional deletion using engine runner in localDir
    const customExec = (args) => {
      return execSync(`git ${args.join(' ')}`, { cwd: localDir, stdio: 'pipe' });
    };

    const res = engine.deleteBranchWithLease({
      branchName: 'feature/test-pass',
      expectedSha,
      remote: 'origin',
      execFn: customExec
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.outcome, 'DELETED');

    // Assert the branch is permanently removed on remote
    const remoteRefs = execSync('git ls-remote origin refs/heads/feature/test-pass', { cwd: localDir }).toString().trim();
    assert.strictEqual(remoteRefs, '', 'Branch should be absent on remote after verified deletion');
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
});

test('18. Real isolated bare Git repo: Branch moved before conditional deletion causes lease failure (TOCTOU race)', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'git-bare-race-'));
  const remoteDir = path.join(tempDir, 'remote.git');
  const localDir = path.join(tempDir, 'local');

  try {
    execSync(`git init --bare "${remoteDir}"`, { stdio: 'pipe' });
    execSync(`git clone "${remoteDir}" "${localDir}"`, { stdio: 'pipe' });
    execSync('git config user.name "Tester"', { cwd: localDir, stdio: 'pipe' });
    execSync('git config user.email "tester@example.com"', { cwd: localDir, stdio: 'pipe' });

    // Initial commit on main
    fs.writeFileSync(path.join(localDir, 'main.txt'), 'main init');
    execSync('git checkout -b main', { cwd: localDir, stdio: 'pipe' });
    execSync('git add . && git commit -m "init main"', { cwd: localDir, stdio: 'pipe' });
    execSync('git push origin main', { cwd: localDir, stdio: 'pipe' });

    // Create and push feature branch
    execSync('git checkout -b feature/race-condition', { cwd: localDir, stdio: 'pipe' });
    fs.writeFileSync(path.join(localDir, 'feat.txt'), 'original feature commit');
    execSync('git add . && git commit -m "commit 1"', { cwd: localDir, stdio: 'pipe' });
    execSync('git push origin feature/race-condition', { cwd: localDir, stdio: 'pipe' });

    // Record the verified SHA (as captured during evaluation phase)
    const evaluatedSha = execSync('git rev-parse HEAD', { cwd: localDir }).toString().trim();

    // SIMULATE CONCURRENT PUSH (TOCTOU): Developer pushes new commit before deletion occurs
    fs.writeFileSync(path.join(localDir, 'feat.txt'), 'concurrent second commit');
    execSync('git add . && git commit -m "commit 2 (concurrent)"', { cwd: localDir, stdio: 'pipe' });
    execSync('git push origin feature/race-condition', { cwd: localDir, stdio: 'pipe' });
    const newerSha = execSync('git rev-parse HEAD', { cwd: localDir }).toString().trim();

    assert.notStrictEqual(evaluatedSha, newerSha, 'Evaluated SHA and newer SHA must differ');

    // Attempt conditional deletion using the stale evaluatedSha
    const customExec = (args) => {
      return execSync(`git ${args.join(' ')}`, { cwd: localDir, stdio: 'pipe' });
    };

    const res = engine.deleteBranchWithLease({
      branchName: 'feature/race-condition',
      expectedSha: evaluatedSha,
      remote: 'origin',
      execFn: customExec
    });

    // Assert: Lease rejected, branch deletion aborted
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.outcome, 'CONCURRENT_MODIFICATION_ABORTED');
    assert.match(res.detail, /stale info/);

    // Assert 19: Concurrent commit remains reachable and intact on remote
    const remoteRefLine = execSync('git ls-remote origin refs/heads/feature/race-condition', { cwd: localDir }).toString().trim();
    assert.strictEqual(remoteRefLine.startsWith(newerSha), true, 'Remote branch must still exist and point to the newer commit SHA');
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
});
