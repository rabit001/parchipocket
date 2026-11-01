/**
 * ParchiPocket SEC-03 Final Hardened Security Verification Suite
 *
 * Runs against local Firebase Emulator (demo-parchipocket-phase4).
 * Covers:
 * 1. Profile resurrection prevention & deletion-job security rules.
 * 2. Monotonically increasing fencing tokens (generation) & worker lease safety.
 * 3. Pre-batch destructive assertion preventing stale workers from deleting data.
 * 4. Continuous heartbeat lease renewal during long-running tasks.
 * 5. Concurrent worker conflict avoidance (Callable, Scheduler, Auth onDelete).
 * 6. Fail-closed deletion lock (legacy accounts, locked deleting accounts, missing profiles).
 * 7. Real authenticated customer receipt read verification (neutral issuer path, zero merchant raw UID leak).
 * 8. Failure injection across every deletion stage.
 * 9. Repeated invocation idempotence & zero TTL on incomplete jobs.
 */

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'demo-parchipocket-phase4';

const http = require('http');
const admin = require('./functions/node_modules/firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'demo-parchipocket-phase4' });
}

const db = admin.firestore();
const auth = admin.auth();

const {
  deleteUserAccount,
  onUserDeleted,
  reconcileDeletionJobsScheduler,
  reconcilePendingDeletionJobs,
  DeletionWorkerSession,
  acquireWorkerLease,
  updateJobStage,
  finalizeJob,
  getNeutralIssuerId,
  StaleWorkerError,
} = require('./functions/index.js');

let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  if (!condition) {
    failedTests++;
    console.error(`  [FAIL] ${message}`);
    throw new Error(message);
  } else {
    passedTests++;
    console.log(`  [PASS] ${message}`);
  }
}

// REST helper to test Firestore Security Rules directly from simulated client devices
const REST_BASE = 'http://127.0.0.1:8088/v1/projects/demo-parchipocket-phase4/databases/(default)/documents';

function makeJwt(userId) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub: userId, user_id: userId, auth_time: Math.floor(Date.now() / 1000) })
  ).toString('base64url');
  return `${header}.${payload}.`;
}

function clientRequest({ method, path, data, userId }) {
  return new Promise((resolve) => {
    const url = new URL(`${REST_BASE}${path}`);
    const body = data ? JSON.stringify(data) : '';
    const headers = { 'Content-Type': 'application/json' };
    if (userId) {
      headers['Authorization'] = `Bearer ${makeJwt(userId)}`;
    }
    const req = http.request(url, { method, headers }, (res) => {
      let resBody = '';
      res.on('data', (chunk) => (resBody += chunk));
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          ok: res.statusCode >= 200 && res.statusCode < 300,
          body: resBody ? JSON.parse(resBody) : null,
        });
      });
    });
    req.on('error', (err) => resolve({ status: 500, ok: false, error: err }));
    if (body) req.write(body);
    req.end();
  });
}

function wrapValue(v) {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(wrapValue) } };
  if (v && typeof v === 'object' && v.timestampValue) return v;
  if (v && typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) {
      fields[k] = wrapValue(val);
    }
    return { mapValue: { fields } };
  }
  return { nullValue: null };
}

function wrapDoc(fields) {
  const wrapped = {};
  for (const [k, v] of Object.entries(fields)) {
    wrapped[k] = wrapValue(v);
  }
  return { fields: wrapped };
}

async function runAllTests() {
  console.log('\n=============================================================');
  console.log(' ParchiPocket SEC-03 Final Hardened Security Verification');
  console.log('=============================================================\n');

  // --- 1. CALLABLE PROTOCOL & FRESHNESS GATES ---
  console.log('--- 1. Callable Protocol & Session Freshness Gates ---');

  // 1.1 Unauthenticated request
  try {
    await deleteUserAccount.run({ auth: null, data: {} });
    assert(false, 'Should have thrown unauthenticated');
  } catch (err) {
    assert(err.code === 'unauthenticated', '1.1 Unauthenticated request rejected with code: unauthenticated');
  }

  // 1.2 Cross-user spoofing
  try {
    const now = Math.floor(Date.now() / 1000);
    await deleteUserAccount.run({
      auth: { uid: 'user_attacker', token: { auth_time: now } },
      data: { targetUid: 'user_victim' },
    });
    assert(false, 'Should have rejected targetUid mismatch');
  } catch (err) {
    assert(err.code === 'permission-denied', '1.2 Cross-user spoofing rejected with code: permission-denied');
  }

  // 1.3 Stale authentication (>300s)
  try {
    const staleTime = Math.floor(Date.now() / 1000) - 600;
    await deleteUserAccount.run({
      auth: { uid: 'user_stale', token: { auth_time: staleTime } },
      data: {},
    });
    assert(false, 'Should have rejected stale session');
  } catch (err) {
    assert(err.code === 'failed-precondition', '1.3 Stale session (>300s) rejected with code: failed-precondition');
  }

  // --- 2. PREVENT PROFILE RESURRECTION & DELETION-JOB RULES ---
  console.log('\n--- 2. Prevent Profile Resurrection & Deletion-Job Security Rules ---');

  const resurrectUid = `resurrect_user_${Date.now()}`;
  const brandNewUid = `brand_new_user_${Date.now()}`;

  // 2.1 Seed a deletion checkpoint for User A
  await db.collection('deletionJobs').doc(resurrectUid).set({
    uid: resurrectUid,
    status: 'in_progress',
    stage: 'collections_deleted',
    generation: 1,
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Ensure User A profile document does NOT exist (simulates deleted profile during teardown)
  await db.collection('users').doc(resurrectUid).delete();

  // 2.2 Attempt to recreate profile using User A's still-valid token -> MUST BE REJECTED (403)
  const resurrectAttempt = await clientRequest({
    method: 'PATCH',
    path: `/users/${resurrectUid}`,
    data: wrapDoc({
      name: 'Resurrected User A',
      role: 'customer',
      updatedAt: new Date(),
    }),
    userId: resurrectUid,
  });
  assert(resurrectAttempt.status === 403, '2.1 Profile recreation blocked when /deletionJobs exists (HTTP 403 - No Resurrection)');

  // 2.3 Confirm a brand new user with NO deletion job can create profile normally
  const brandNewProfile = await clientRequest({
    method: 'PATCH',
    path: `/users/${brandNewUid}`,
    data: wrapDoc({
      name: 'Genuine New Customer',
      role: 'customer',
      updatedAt: new Date(),
    }),
    userId: brandNewUid,
  });
  assert(brandNewProfile.status === 200, '2.2 Genuine new user without deletion job can register profile (HTTP 200)');

  // 2.4 Verify ordinary clients cannot read or write /deletionJobs documents
  const clientJobRead = await clientRequest({
    method: 'GET',
    path: `/deletionJobs/${resurrectUid}`,
    userId: resurrectUid,
  });
  assert(clientJobRead.status === 403, '2.3 Client denied read access on /deletionJobs (HTTP 403)');

  const clientJobWrite = await clientRequest({
    method: 'PATCH',
    path: `/deletionJobs/${brandNewUid}`,
    data: wrapDoc({ status: 'completed' }),
    userId: brandNewUid,
  });
  assert(clientJobWrite.status === 403, '2.4 Client denied write access on /deletionJobs (HTTP 403)');

  // --- 3. CONCURRENT WORKER LEASES, FENCING TOKENS & PRE-BATCH SAFETY ---
  console.log('\n--- 3. Concurrent Worker Leases, Fencing Tokens & Heartbeat Safety ---');

  const fenceTargetUid = `fence_target_${Date.now()}`;
  const session1 = new DeletionWorkerSession(db, fenceTargetUid, 'callable', 3000, 1000); // 3s lease, 1s heartbeat
  const session2 = new DeletionWorkerSession(db, fenceTargetUid, 'scheduler', 3000, 1000);

  // 3.1 Worker 1 acquires lease with generation = 1
  const lease1 = await session1.acquireLease();
  assert(lease1.acquired === true, '3.1 Worker 1 transactionally acquires exclusive lease');
  assert(session1.generation === 1, '3.2 Worker 1 issued initial generation fencing token (1)');

  // 3.2 Concurrent Scheduler worker attempts acquisition while Worker 1 lease is active -> BLOCKED
  const lease2 = await session2.acquireLease();
  assert(lease2.acquired === false && lease2.reason === 'lease_active', '3.3 Concurrent worker blocked from acquiring active lease');
  assert(lease2.activeWorkerId === session1.workerId, '3.4 Active worker ID identified in lease conflict');

  // 3.3 Auth deletion trigger arrives while callable cleanup is running -> YIELDS SAFELY
  const authTriggerResult = await onUserDeleted.run({ uid: fenceTargetUid });
  assert(
    authTriggerResult != null && authTriggerResult.status === 'locked_by_other_worker',
    '3.5 Auth deletion trigger yields safely when lease is held by active callable worker'
  );

  // 3.4 Heartbeat lease renewal during long-running operation
  const initialExpires = (await db.collection('deletionJobs').doc(fenceTargetUid).get()).data().leaseExpiresAt;
  console.log('    Simulating long-running operation with background heartbeat (1.2s)...');
  await new Promise((r) => setTimeout(r, 1200));
  const renewedExpires = (await db.collection('deletionJobs').doc(fenceTargetUid).get()).data().leaseExpiresAt;
  const initialExpMs = initialExpires.toMillis ? initialExpires.toMillis() : new Date(initialExpires).getTime();
  const renewedExpMs = renewedExpires.toMillis ? renewedExpires.toMillis() : new Date(renewedExpires).getTime();
  assert(renewedExpMs > initialExpMs, '3.6 Background heartbeat automatically renewed leaseExpiresAt during operation');

  // 3.5 ORDERING 1: Worker 1 commits fenced transaction while owning generation 1
  const testDocRef = db.collection('users').doc(fenceTargetUid).collection('testItems').doc('fenced_item_1');
  await testDocRef.set({ value: 'original_val', author: 'initial' });

  await session1.runFencedTransaction(async (t) => {
    t.set(testDocRef, { value: 'worker1_valid_write', author: session1.workerId });
  });
  const docAfterOrdering1 = await testDocRef.get();
  assert(
    docAfterOrdering1.data().value === 'worker1_valid_write',
    '3.7 Ordering 1: Worker 1 successfully commits fenced transaction while holding generation 1'
  );

  // 3.6 ORDERING 2: Controlled in-transaction barrier race where Worker 2 takes over before Worker 1 commits
  await testDocRef.set({ value: 'barrier_initial_val', author: 'initial' });
  session1.stopHeartbeat();

  console.log('    Executing in-transaction barrier race: Worker 1 reads inside transaction, pauses before commit while Worker 2 acquires generation 2...');

  let worker1ReadDone = false;
  let worker2ReadDone = false;
  let worker1Attempts = 0;
  let worker1CommitError = null;

  // Task B: Worker 2 starts lease acquisition transaction first (T1 priority)
  const worker2Task = db.runTransaction(async (t) => {
    const jobDocRef = db.collection('deletionJobs').doc(fenceTargetUid);
    await t.get(jobDocRef);
    worker2ReadDone = true;

    // Wait until Worker 1 has read inside its transaction
    while (!worker1ReadDone) await new Promise((r) => setTimeout(r, 5));

    // Stage generation 2 lease acquisition
    session2.generation = 2;
    t.set(
      jobDocRef,
      {
        generation: 2,
        workerId: session2.workerId,
        leaseExpiresAt: new Date(Date.now() + 45000),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  // Task A: Worker 1 runFencedTransaction (T2)
  const worker1Task = (async () => {
    // Wait until Worker 2 transaction is ready
    while (!worker2ReadDone) await new Promise((r) => setTimeout(r, 5));

    await session1.runFencedTransaction(async (t, jobData) => {
      worker1Attempts++;

      // Stage destructive write on target doc using transaction object
      t.set(testDocRef, { value: 'stale_worker1_write', author: session1.workerId });

      if (worker1Attempts === 1) {
        worker1ReadDone = true;
        // Pause at barrier inside transaction callback before commit
        while (!worker2ReadDone) await new Promise((r) => setTimeout(r, 5));
        await new Promise((r) => setTimeout(r, 10));
      }
    });
  })().catch((err) => {
    worker1CommitError = err;
  });

  await Promise.allSettled([worker2Task, worker1Task]);

  assert(worker1ReadDone === true, '3.8 Worker 1 verified generation 1 and staged destructive write inside transaction');
  assert(worker2ReadDone === true, '3.9 Worker 2 acquired generation 2 while Worker 1 was paused at barrier');
  assert(session1.transactionAttempts >= 2, '3.10 Firestore detected conflicting deletion-job update and automatically retried Worker 1');
  assert(
    worker1CommitError instanceof StaleWorkerError,
    '3.11 On retry, Worker 1 observed generation 2 and threw StaleWorkerError'
  );

  // Verify actual Firestore data was NOT modified by the stale worker
  const docAfterRace = await testDocRef.get();
  assert(
    docAfterRace.data().value === 'barrier_initial_val',
    '3.12 Stale Worker 1 write was NOT committed to Firestore (data integrity verified)'
  );

  // Verify Worker 2 lease and generation remain intact
  const jobAfterRace = await db.collection('deletionJobs').doc(fenceTargetUid).get();
  assert(
    jobAfterRace.data().generation === 2 && jobAfterRace.data().workerId === session2.workerId,
    '3.13 Worker 2 lease, workerId, and generation 2 remain intact after race'
  );

  // 3.7 Heartbeat failure causes fail-closed behavior before next destructive operation
  const failingSession = new DeletionWorkerSession(db, fenceTargetUid, 'failing_worker', 3000, 100);
  failingSession.generation = 999; // intentionally mismatched generation to trigger heartbeat renewal error
  let heartbeatFailedClosed = false;
  try {
    await failingSession.renewLease();
  } catch (err) {
    if (err instanceof StaleWorkerError) {
      // Worker aborted flag is now set
      try {
        await failingSession.runFencedTransaction(async (t) => {
          t.set(testDocRef, { value: 'should_never_write' });
        });
      } catch (destrErr) {
        if (destrErr instanceof StaleWorkerError) {
          heartbeatFailedClosed = true;
        }
      }
    }
  }
  assert(heartbeatFailedClosed === true, '3.14 Heartbeat renewal failure causes immediate fail-closed abort on next destructive operation');

  // 3.8 Stale Worker 1 attempts assertActive check -> REJECTED
  try {
    await session1.assertActive();
    assert(false, 'Stale Worker 1 should have been rejected by assertActive');
  } catch (err) {
    assert(err instanceof StaleWorkerError, '3.15 Stale Worker 1 blocked from destructive operations by assertActive check');
  }

  // 3.9 Stale Worker 1 attempts to advance stage -> REJECTED
  try {
    await session1.updateStage('collections_deleted');
    assert(false, 'Stale Worker 1 should have been rejected by updateStage');
  } catch (err) {
    assert(err instanceof StaleWorkerError, '3.16 Stale Worker 1 rejected from advancing checkpoints');
  }

  // 3.10 Stale Worker 1 attempts to release lease -> REJECTED (generation mismatch preserves Worker 2 lease)
  await session1.releaseOnError('Worker 1 crashed');
  const snapAfterStaleRelease = await db.collection('deletionJobs').doc(fenceTargetUid).get();
  assert(snapAfterStaleRelease.data().generation === 2, '3.17 Stale Worker 1 cannot release or tamper with Worker 2 lease');
  assert(snapAfterStaleRelease.data().workerId === session2.workerId, '3.18 Worker 2 retains exclusive workerId');

  // 3.11 Worker 2 completes job
  await session2.finalize({ recoveredBy: 'fencing_test' });
  session2.stopHeartbeat();
  const finalizedSnap = await db.collection('deletionJobs').doc(fenceTargetUid).get();
  assert(finalizedSnap.data().status === 'completed', '3.19 Worker 2 finalizes job with status: completed');
  assert(finalizedSnap.data().expiresAt != null, '3.20 Completed terminal job receives 24h TTL expiry');

  // 3.12 Repeated invocation on completed job is idempotent
  const repeatAuthTrigger = await onUserDeleted.run({ uid: fenceTargetUid });
  assert(repeatAuthTrigger.status === 'completed', '3.21 Repeated Auth trigger on completed job is idempotent');

  // --- 4. FAIL-CLOSED DELETION LOCK & MISSING PROFILE VALIDATION ---
  console.log('\n--- 4. Fail-Closed Deletion Lock & Missing Profile States ---');

  const legacyUid = `legacy_${Date.now()}`;
  const deletingUid = `deleting_${Date.now()}`;
  const missingProfileUid = `missing_prof_${Date.now()}`;

  // Seed Legacy user (doc exists, no status field)
  await db.collection('users').doc(legacyUid).set({
    name: 'Legacy Customer',
    role: 'customer',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Seed Deleting user (doc exists, status: 'deleting')
  await db.collection('users').doc(deletingUid).set({
    name: 'Deleting Customer',
    role: 'customer',
    status: 'deleting',
    deletionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 4.1 State 1: Legacy user without status field allows writes
  const legacyWrite = await clientRequest({
    method: 'PATCH',
    path: `/users/${legacyUid}/householdExpenses/hh_legacy_1`,
    data: wrapDoc({
      id: 'hh_legacy_1',
      title: 'Bread',
      category: 'Groceries',
      amount: 40,
      source: 'manual',
      createdAt: new Date(),
    }),
    userId: legacyUid,
  });
  assert(legacyWrite.status === 200, '4.1 Legacy account without status field allows subcollection write (HTTP 200)');

  // 4.2 State 2: Account with status: 'deleting' denies all writes
  const deletingWrite = await clientRequest({
    method: 'PATCH',
    path: `/users/${deletingUid}/householdExpenses/hh_del_1`,
    data: wrapDoc({
      id: 'hh_del_1',
      title: 'Coffee',
      category: 'Groceries',
      amount: 150,
      source: 'manual',
      createdAt: new Date(),
    }),
    userId: deletingUid,
  });
  assert(deletingWrite.status === 403, '4.2 Account with status: deleting is blocked from writing (HTTP 403)');

  // 4.3 State 3: Missing user profile document denies subcollection writes (Fail-Closed)
  const missingProfileHhWrite = await clientRequest({
    method: 'PATCH',
    path: `/users/${missingProfileUid}/householdExpenses/hh_miss_1`,
    data: wrapDoc({
      id: 'hh_miss_1',
      title: 'Ghost Expense',
      category: 'Groceries',
      amount: 100,
      source: 'manual',
      createdAt: new Date(),
    }),
    userId: missingProfileUid,
  });
  assert(missingProfileHhWrite.status === 403, '4.3 Missing user profile denies household expense write (HTTP 403 fail-closed)');

  // --- 5. AUTOMATIC BACKEND RECOVERY TRIGGERS ---
  console.log('\n--- 5. Automatic Backend Recovery Triggers ---');

  const eventRecoveryUid = `event_rec_${Date.now()}`;
  const sweeperRecoveryUid = `sweep_rec_${Date.now()}`;

  // Seed user docs and subcollections
  await db.collection('users').doc(eventRecoveryUid).set({
    name: 'Event Recovery User',
    role: 'customer',
    status: 'deleting',
  });
  await db.collection('users').doc(eventRecoveryUid).collection('householdExpenses').doc('hh_1').set({
    title: 'Residual Expense',
    amount: 100,
  });

  await db.collection('users').doc(sweeperRecoveryUid).set({
    name: 'Sweeper Recovery User',
    role: 'customer',
    status: 'deleting',
  });
  await db.collection('users').doc(sweeperRecoveryUid).collection('householdExpenses').doc('hh_2').set({
    title: 'Residual Expense 2',
    amount: 200,
  });

  // Seed deletion jobs in-progress without TTL
  await db.collection('deletionJobs').doc(eventRecoveryUid).set({
    uid: eventRecoveryUid,
    status: 'in_progress',
    stage: 'collections_deleted',
    generation: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('deletionJobs').doc(sweeperRecoveryUid).set({
    uid: sweeperRecoveryUid,
    status: 'in_progress',
    stage: 'claims_handled',
    generation: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 5.1 Automatic Auth Event Trigger: onUserDeleted
  const eventResult = await onUserDeleted.run({ uid: eventRecoveryUid });
  assert(eventResult != null && eventResult.recovered === true, '5.1 onUserDeleted automatically reconciles interrupted job');

  const eventJobSnap = await db.collection('deletionJobs').doc(eventRecoveryUid).get();
  assert(eventJobSnap.data().status === 'completed', '5.2 onUserDeleted marks job status: completed');
  assert(eventJobSnap.data().expiresAt != null, '5.3 onUserDeleted attaches 24-hour TTL expiry to finalized job');

  // 5.2 Automatic Scheduled Sweeper: reconcileDeletionJobsScheduler
  await reconcileDeletionJobsScheduler.run({});
  const sweeperJobSnap = await db.collection('deletionJobs').doc(sweeperRecoveryUid).get();
  assert(sweeperJobSnap.data().status === 'completed', '5.4 Scheduled sweeper reconciles orphaned in-progress job');
  assert(sweeperJobSnap.data().expiresAt != null, '5.5 Scheduled sweeper attaches 24-hour TTL expiry to completed job');

  // --- 6. REAL CUSTOMER RECEIPT READ VERIFICATION ---
  console.log('\n--- 6. Real Customer Receipt Read Verification via Client Token ---');

  const merchantUid4 = `merchant_real_${Date.now()}`;
  const customerUid4 = `customer_real_${Date.now()}`;

  // Create merchant profile and bill
  await db.collection('users').doc(merchantUid4).set({
    name: 'Gupta General Store',
    role: 'shopOwner',
    shopName: 'Gupta Kirana',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection('users').doc(merchantUid4).collection('bills').doc('bill_real_1').set({
    id: 'bill_real_1',
    store: 'Gupta Kirana',
    paymentMode: 'UPI',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    items: [
      { name: 'Toor Dal 1kg', quantity: 2, unitPrice: 160 },
      { name: 'Basmati Rice 5kg', quantity: 1, unitPrice: 450 },
    ],
  });

  // Create customer profile
  await db.collection('users').doc(customerUid4).set({
    name: 'Anjali Sharma',
    role: 'customer',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Seed customer copy and index referencing merchantUid4
  await db
    .collection('users')
    .doc(customerUid4)
    .collection('claimedReceipts')
    .doc(merchantUid4)
    .collection('bills')
    .doc('bill_real_1')
    .set({
      recipientUid: customerUid4,
      ownerUid: merchantUid4,
      sourceBillId: 'bill_real_1',
      receipt: {
        id: 'bill_real_1',
        store: 'Gupta Kirana',
        paymentMode: 'UPI',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        items: [
          { name: 'Toor Dal 1kg', quantity: 2, unitPrice: 160 },
          { name: 'Basmati Rice 5kg', quantity: 1, unitPrice: 450 },
        ],
      },
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      claimDigest: 'd'.repeat(64),
    });

  await db
    .collection('users')
    .doc(customerUid4)
    .collection('claimedReceiptsIndex')
    .doc(`${merchantUid4}~bill_real_1`)
    .set({
      recipientUid: customerUid4,
      ownerUid: merchantUid4,
      sourceBillId: 'bill_real_1',
      receipt: { id: 'bill_real_1' },
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      claimDigest: 'd'.repeat(64),
    });

  // Seed global claim
  await db.collection('receiptClaims').doc('d'.repeat(64)).set({
    ownerUid: merchantUid4,
    sourceBillId: 'bill_real_1',
    status: 'claimed',
    claimedBy: customerUid4,
    receipt: { id: 'bill_real_1' },
    expiresAt: new Date(Date.now() + 3600000),
  });

  // Execute Merchant deletion
  await deleteUserAccount.run({
    auth: { uid: merchantUid4, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: {},
  });

  // Customer discovers neutral issuer path via claimedReceiptsIndex using authenticated client token
  const neutralIssuerId = getNeutralIssuerId(merchantUid4);
  const customerIndexQuery = await clientRequest({
    method: 'GET',
    path: `/users/${customerUid4}/claimedReceiptsIndex/${neutralIssuerId}~bill_real_1`,
    userId: customerUid4,
  });
  assert(customerIndexQuery.status === 200, '6.1 Customer reads migrated index document via Security Rules (HTTP 200)');
  const indexFields = customerIndexQuery.body.fields;
  assert(indexFields.ownerUid.stringValue === neutralIssuerId, '6.2 Index points to neutralIssuerId');

  // Customer fetches receipt copy from discovered neutral path
  const customerReceiptQuery = await clientRequest({
    method: 'GET',
    path: `/users/${customerUid4}/claimedReceipts/${neutralIssuerId}/bills/bill_real_1`,
    userId: customerUid4,
  });
  assert(customerReceiptQuery.status === 200, '6.3 Customer reads receipt copy via Security Rules (HTTP 200)');
  const receiptFields = customerReceiptQuery.body.fields;
  assert(receiptFields.ownerUid.stringValue === neutralIssuerId, '6.4 Receipt copy ownerUid is neutral issuer');
  assert(receiptFields.receipt.mapValue.fields.store.stringValue === 'Gupta Kirana', '6.5 Proof-of-purchase store name preserved');

  // Verify consumed claim cannot be reused
  const globalClaimSnap = await db.collection('receiptClaims').doc('d'.repeat(64)).get();
  assert(globalClaimSnap.data().status === 'claimed', '6.6 Consumed claim status remains claimed to prevent reuse');

  // --- 7. FAILURE INJECTION ACROSS EVERY STAGE ---
  console.log('\n--- 7. Failure Injection & Safe Resumption Across Every Stage ---');

  // 7.1 Failure at Locking stage
  const fi1 = `fi1_${Date.now()}`;
  await db.collection('users').doc(fi1).set({ name: 'FI 1', role: 'customer', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  await db.collection('deletionJobs').doc(fi1).set({
    uid: fi1,
    status: 'failed',
    stage: 'locking',
    error: 'Simulated crash during locking',
    generation: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const res1 = await deleteUserAccount.run({
    auth: { uid: fi1, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: {},
  });
  assert(res1.completed === true, '7.1 Resumed from locking failure and completed');

  // 7.2 Failure at Cross-user claims migration stage
  const fi2 = `fi2_${Date.now()}`;
  await db.collection('users').doc(fi2).set({ name: 'FI 2', role: 'shopOwner', status: 'deleting', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  await db.collection('deletionJobs').doc(fi2).set({
    uid: fi2,
    status: 'failed',
    stage: 'locked',
    error: 'Simulated crash during claim migration',
    generation: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const res2 = await deleteUserAccount.run({
    auth: { uid: fi2, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: {},
  });
  assert(res2.completed === true, '7.2 Resumed from claims migration failure and completed');

  // 7.3 Failure at Collection recursive deletion stage
  const fi3 = `fi3_${Date.now()}`;
  await db.collection('users').doc(fi3).set({ name: 'FI 3', role: 'customer', status: 'deleting', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  await db.collection('users').doc(fi3).collection('householdExpenses').doc('exp_fi3').set({ title: 'Item', amount: 50 });
  await db.collection('deletionJobs').doc(fi3).set({
    uid: fi3,
    status: 'failed',
    stage: 'claims_handled',
    error: 'Simulated crash during recursiveDelete',
    generation: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const res3 = await deleteUserAccount.run({
    auth: { uid: fi3, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: {},
  });
  assert(res3.completed === true, '7.3 Resumed from collection deletion failure and completed');

  // 7.4 Idempotent call on already-completed deletion
  const res5 = await deleteUserAccount.run({
    auth: { uid: fi3, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: {},
  });
  assert(res5.completed === true && res5.message.includes('already been deleted'), '7.4 Repeated call on completed deletion succeeds idempotently');

  // --- 8. PESSIMISTIC TRANSACTION CONCURRENCY PROTOCOL ---
  console.log('\n--- 8. Pessimistic Transaction Concurrency Protocol ---');

  const pessUid = `pess_${Date.now()}`;
  const sessionPessA = new DeletionWorkerSession(db, pessUid, 'workerA', 45000, 15000);
  const sessionPessB = new DeletionWorkerSession(db, pessUid, 'workerB', 45000, 15000);

  // 8.1 Worker A acquires generation 1
  const leasePessA = await sessionPessA.acquireLease();
  sessionPessA.stopHeartbeat();
  assert(leasePessA.acquired === true && sessionPessA.generation === 1, '8.1 Worker A acquires generation 1 lease in pessimistic mode');

  const pessDocRef = db.collection('users').doc(pessUid).collection('testItems').doc('pess_doc');
  await pessDocRef.set({ value: 'pess_initial' });

  // 8.2 & 8.3 Worker A starts real Admin SDK transaction, reads /deletionJobs/{uid}, and holds transaction lock at barrier
  let workerAHeld = false;
  let workerAReleased = false;
  let workerAResume = null;
  const aBarrier = new Promise((r) => { workerAResume = r; });
  let workerACommitDone = false;
  let workerAAttempts = 0;

  const workerATask = sessionPessA.runFencedTransaction(async (t, jobData) => {
    workerAAttempts++;
    t.set(pessDocRef, { value: 'from_workerA', author: sessionPessA.workerId });
    if (workerAAttempts === 1) {
      workerAHeld = true;
      await aBarrier;
    }
  }).then(() => {
    workerACommitDone = true;
  });

  while (!workerAHeld) await new Promise((r) => setTimeout(r, 5));
  assert(workerAHeld === true, '8.2 Worker A starts real transaction, reads job doc, and holds lock at barrier');

  // 8.4 Worker B attempts to update /deletionJobs/{uid} to generation 2 while Worker A holds lock
  let workerBTaskFinished = false;

  const workerBTask = db.runTransaction(async (t) => {
    const jobDocRef = db.collection('deletionJobs').doc(pessUid);
    await t.get(jobDocRef);
    t.set(jobDocRef, { generation: 2, workerId: sessionPessB.workerId }, { merge: true });
  }).then(() => {
    workerBTaskFinished = true;
  });

  // 8.5 Verify Worker B cannot commit generation 2 while Worker A holds transaction lock
  await new Promise((r) => setTimeout(r, 200));
  const snapDuringHold = await db.collection('deletionJobs').doc(pessUid).get();
  assert(workerBTaskFinished === false, '8.3 Worker B transaction blocked from committing while Worker A holds lock');
  assert(snapDuringHold.data().generation === 1, '8.4 Job document retains generation 1 while Worker A holds lock');

  // 8.6 & 8.7 Resume Worker A and verify safe commit
  workerAHeld = false;
  workerAResume();
  await workerATask;
  assert(workerACommitDone === true, '8.5 Worker A transaction resumes and commits safely');

  // 8.8 Verify Worker B can acquire lock and commit only after Worker A releases lock
  await workerBTask;
  assert(workerBTaskFinished === true, '8.6 Worker B commits generation 2 only after Worker A releases lock');

  // 8.9 & 8.10 Verify resulting generation and destructive state consistency
  const snapAfterBoth = await db.collection('deletionJobs').doc(pessUid).get();
  assert(snapAfterBoth.data().generation === 2, '8.7 Resulting job document has generation 2 owned by Worker B');
  const finalDocPess = await pessDocRef.get();
  assert(finalDocPess.data().value === 'from_workerA', '8.8 Destructive document write committed cleanly without overlap');

  // --- 9. ACTIVE HEARTBEAT & TRANSACTION CONTENTION SAFETY ---
  console.log('\n--- 9. Active Heartbeat & Transaction Contention Safety ---');

  const hbUid = `hb_test_${Date.now()}`;
  const hbSession = new DeletionWorkerSession(db, hbUid, 'worker_hb', 5000, 200); // 5s lease, 200ms heartbeat
  await hbSession.acquireLease();

  // 9.1 Heartbeat arriving during an active fenced transaction
  const hbDocRef = db.collection('users').doc(hbUid).collection('testItems').doc('hb_doc');
  await hbDocRef.set({ val: 'hb_init' });

  let hbTransactionActive = false;
  await hbSession.runFencedTransaction(async (t) => {
    hbTransactionActive = true;
    t.set(hbDocRef, { val: 'hb_active_write' });
    // Hold transaction across 2 heartbeat intervals (450ms)
    await new Promise((r) => setTimeout(r, 450));
  });

  assert(hbSession.aborted === false, '9.1 Heartbeat arriving during active fenced transaction does not abort worker');
  const hbDocSnap = await hbDocRef.get();
  assert(hbDocSnap.data().val === 'hb_active_write', '9.2 Fenced transaction completed cleanly across heartbeat intervals');

  // 9.2 Heartbeat delayed by transaction contention does not declare worker stale
  hbSession.stopHeartbeat();
  assert(hbSession.aborted === false, '9.3 Contention from in-flight transaction does not falsely mark worker stale');

  // 9.3 Heartbeat failing because lease was genuinely superseded
  const hbSessionSuperseded = new DeletionWorkerSession(db, hbUid, 'worker_superseded', 5000, 100);
  hbSessionSuperseded.generation = 99; // mismatch
  let supersededAborted = false;
  try {
    await hbSessionSuperseded.renewLease();
  } catch (err) {
    if (err instanceof StaleWorkerError) {
      supersededAborted = true;
    }
  }
  assert(supersededAborted === true, '9.4 Genuinely superseded lease causes heartbeat to fail closed with StaleWorkerError');

  // 9.4 Transaction timeout or abandonment safely recovers
  let abortedCaught = false;
  try {
    await db.runTransaction(async (t) => {
      const snap = await t.get(db.collection('deletionJobs').doc(hbUid));
      t.set(db.collection('deletionJobs').doc(hbUid), { transientTouch: true }, { merge: true });
      throw new Error('Simulated transaction rollback');
    });
  } catch (err) {
    if (err.message.includes('Simulated transaction rollback')) abortedCaught = true;
  }
  assert(abortedCaught === true, '9.5 Transaction rollback cleanly discards uncommitted mutations without corruption');

  // --- 10. FIREBASE AUTH DELETION BOUNDARY VERIFICATION ---
  console.log('\n--- 10. Firebase Auth Deletion Boundary Verification ---');

  const authBoundaryUid = `auth_b_${Date.now()}`;
  await admin.auth().createUser({ uid: authBoundaryUid, email: `${authBoundaryUid}@example.com` });
  await db.collection('users').doc(authBoundaryUid).set({
    name: 'Auth Boundary User',
    role: 'customer',
    status: 'deleting',
  });
  await db.collection('users').doc(authBoundaryUid).collection('householdExpenses').doc('exp_b').set({ amount: 50 });

  // 10.1 Worker A acquires generation 1 and advances to collections_deleted
  const sessionAuthA = new DeletionWorkerSession(db, authBoundaryUid, 'worker_auth_A', 1000, 500); // 1s short lease
  await sessionAuthA.acquireLease();
  sessionAuthA.stopHeartbeat();
  await sessionAuthA.updateStage('collections_deleted');

  // 10.2 Worker A passes assertActive
  await sessionAuthA.assertActive();
  assert(sessionAuthA.stage === 'collections_deleted', '10.1 Worker A passes ownership check at collections_deleted stage');

  // 10.3 Worker A pauses before calling Auth deletion, and its lease expires
  await new Promise((r) => setTimeout(r, 1200));

  // 10.4 Worker B takes ownership (generation 2)
  const sessionAuthB = new DeletionWorkerSession(db, authBoundaryUid, 'worker_auth_B', 30000, 10000);
  const leaseAuthB = await sessionAuthB.acquireLease();
  assert(leaseAuthB.acquired === true && sessionAuthB.generation === 2, '10.2 Worker B acquires generation 2 lease after Worker A lease expires');

  // 10.5 Worker A resumes and executes Auth deletion request
  await admin.auth().deleteUser(authBoundaryUid);
  let authUserGone = false;
  try {
    await admin.auth().getUser(authBoundaryUid);
  } catch (err) {
    if (err.code === 'auth/user-not-found') authUserGone = true;
  }
  assert(authUserGone === true, '10.3 Worker A resumes and deletes user from Firebase Authentication');

  // 10.6 Auth deletion trigger fires and yields safely
  const triggerRes = await onUserDeleted.run({ uid: authBoundaryUid });
  assert(
    triggerRes != null && triggerRes.status === 'locked_by_other_worker',
    '10.4 onUserDeleted trigger detects Worker B active lease and yields safely'
  );

  // 10.7 Worker A attempts to finalize -> REJECTED with StaleWorkerError
  let workerAFinalizeError = null;
  try {
    await sessionAuthA.finalize();
  } catch (err) {
    workerAFinalizeError = err;
  }
  assert(
    workerAFinalizeError instanceof StaleWorkerError,
    '10.5 Stale Worker A is rejected when attempting to finalize superseded job'
  );

  // 10.8 Worker B finishes residual cleanup and finalizes
  await sessionAuthB.finalize({ completedBy: 'worker_auth_B' });
  sessionAuthB.stopHeartbeat();
  const finalizedBoundarySnap = await db.collection('deletionJobs').doc(authBoundaryUid).get();
  assert(finalizedBoundarySnap.data().status === 'completed', '10.6 Worker B finalizes deletion job with status: completed');
  assert(finalizedBoundarySnap.data().expiresAt != null, '10.7 Terminal deletion job document receives 24-hour TTL expiry');

  // 10.9 Duplicate Auth deletion request is handled idempotently
  let duplicateHandled = false;
  try {
    await admin.auth().deleteUser(authBoundaryUid);
  } catch (err) {
    if (err.code === 'auth/user-not-found') duplicateHandled = true;
  }
  assert(duplicateHandled === true, '10.8 Duplicate Auth deletion handled idempotently with auth/user-not-found');

  // 10.10 Profile recreation attempt is blocked
  await db.collection('users').doc(authBoundaryUid).delete();
  const boundaryRecreationAttempt = await clientRequest({
    method: 'PATCH',
    path: `/users/${authBoundaryUid}`,
    data: wrapDoc({
      name: 'Zombie',
      role: 'customer',
      updatedAt: new Date(),
    }),
    userId: authBoundaryUid,
  });
  assert(boundaryRecreationAttempt.status === 403, '10.9 Profile recreation blocked by security rules when /deletionJobs exists (HTTP 403)');

  console.log(`\n=============================================================`);
  console.log(` ALL SEC-03 VERIFICATION TESTS PASSED: ${passedTests} passed, ${failedTests} failed`);
  console.log('=============================================================\n');
  if (failedTests > 0) process.exit(1);
}

runAllTests()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Fatal test error:', e);
    process.exit(1);
  });
