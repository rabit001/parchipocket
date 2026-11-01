const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const functionsV1 = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Custom error thrown when a worker attempts to perform destructive operations
 * or update a deletion job after losing its exclusive lease or being superseded
 * by a higher fencing generation token.
 */
class StaleWorkerError extends Error {
  constructor(message = 'Worker lost exclusive lease or was superseded by a higher fencing token') {
    super(message);
    this.name = 'StaleWorkerError';
  }
}

/**
 * DeletionWorkerSession
 *
 * Implements an exclusive worker ownership model with:
 * - Monotonically increasing fencing token (generation).
 * - Bounded lease duration with background heartbeat lease renewal during long operations.
 * - Pre-batch lease assertion before every destructive action.
 * - Prevention of stale workers advancing checkpoints, releasing leases, or finalizing jobs.
 */
class DeletionWorkerSession {
  constructor(db, targetUid, workerType = 'worker', leaseDurationMs = 45000, heartbeatIntervalMs = 15000) {
    this.db = db;
    this.targetUid = targetUid;
    this.workerId = `${workerType}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    this.leaseDurationMs = leaseDurationMs;
    this.heartbeatIntervalMs = heartbeatIntervalMs;
    this.generation = 0;
    this.stage = 'not_started';
    this.aborted = false;
    this.heartbeatTimer = null;
  }

  async acquireLease() {
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const result = await this.db.runTransaction(async (transaction) => {
      const jobSnap = await transaction.get(jobRef);
      const nowMs = Date.now();
      const newLeaseExpiresAt = new Date(nowMs + this.leaseDurationMs);

      if (!jobSnap.exists) {
        this.generation = 1;
        transaction.set(jobRef, {
          uid: this.targetUid,
          status: 'in_progress',
          stage: 'not_started',
          generation: this.generation,
          workerId: this.workerId,
          leaseAcquiredAt: admin.firestore.FieldValue.serverTimestamp(),
          leaseExpiresAt: newLeaseExpiresAt,
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { acquired: true, stage: 'not_started', generation: 1, jobData: {} };
      }

      const job = jobSnap.data();
      if (job.status === 'completed') {
        return { acquired: false, alreadyCompleted: true, jobData: job };
      }

      let isLeaseActive = false;
      if (job.leaseExpiresAt) {
        const expMs = job.leaseExpiresAt.toMillis
          ? job.leaseExpiresAt.toMillis()
          : new Date(job.leaseExpiresAt).getTime();
        isLeaseActive = expMs > nowMs;
      }

      if (isLeaseActive && job.workerId && job.workerId !== this.workerId) {
        return {
          acquired: false,
          reason: 'lease_active',
          activeWorkerId: job.workerId,
          generation: job.generation || 1,
          jobData: job,
        };
      }

      // Increment fencing token monotonically
      this.generation = (job.generation || 0) + 1;
      transaction.set(
        jobRef,
        {
          uid: this.targetUid,
          status: 'in_progress',
          generation: this.generation,
          workerId: this.workerId,
          leaseAcquiredAt: admin.firestore.FieldValue.serverTimestamp(),
          leaseExpiresAt: newLeaseExpiresAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { acquired: true, stage: job.stage || 'not_started', generation: this.generation, jobData: job };
    });

    if (result.acquired) {
      this.stage = result.stage;
      this.startHeartbeat();
    }
    return result;
  }

  startHeartbeat() {
    if (this.heartbeatTimer) return;
    this.heartbeatTimer = setInterval(async () => {
      if (this.aborted) {
        this.stopHeartbeat();
        return;
      }
      // If a fenced transaction is actively in-flight on this session, skip heartbeat tick
      // to avoid self-contention on /deletionJobs/{uid}; the transaction itself touches and extends the lease.
      if (this.activeTransactionCount > 0) {
        return;
      }
      try {
        await this.renewLease();
      } catch (err) {
        if (err instanceof StaleWorkerError) {
          this.aborted = true;
          this.stopHeartbeat();
        } else {
          // Transient transaction contention (e.g. lock wait or lock timeout from an active
          // fenced transaction holding the document lock) does not abort the worker.
        }
      }
    }, this.heartbeatIntervalMs);
    if (this.heartbeatTimer.unref) this.heartbeatTimer.unref();
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  async renewLease() {
    if (this.aborted) throw new StaleWorkerError('Worker was already aborted');
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const generation = this.generation;
    const workerId = this.workerId;
    const duration = this.leaseDurationMs;

    await this.db.runTransaction(async (transaction) => {
      const snap = await transaction.get(jobRef);
      if (!snap.exists) throw new StaleWorkerError('Job document disappeared');
      const data = snap.data();
      if (data.generation !== generation || data.workerId !== workerId) {
        throw new StaleWorkerError(`Heartbeat failed: generation mismatch (expected ${generation}, found ${data.generation})`);
      }
      if (data.status === 'completed') {
        throw new StaleWorkerError('Job is already completed');
      }
      transaction.set(
        jobRef,
        {
          leaseExpiresAt: new Date(Date.now() + duration),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  }

  async assertActive() {
    if (this.aborted) {
      throw new StaleWorkerError('Worker lease was aborted due to preemption or heartbeat failure');
    }
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const snap = await jobRef.get();
    if (!snap.exists) throw new StaleWorkerError('Job document disappeared');
    const data = snap.data();
    if (data.generation !== this.generation || data.workerId !== this.workerId) {
      this.aborted = true;
      this.stopHeartbeat();
      throw new StaleWorkerError(
        `Fencing token mismatch: worker generation ${this.generation} superseded by generation ${data.generation}`
      );
    }
    const nowMs = Date.now();
    const expMs = data.leaseExpiresAt && data.leaseExpiresAt.toMillis
      ? data.leaseExpiresAt.toMillis()
      : new Date(data.leaseExpiresAt).getTime();
    if (expMs <= nowMs) {
      this.aborted = true;
      this.stopHeartbeat();
      throw new StaleWorkerError('Worker lease has expired');
    }
  }

  /**
   * Executes an atomic, fenced transaction for destructive operations.
   *
   * Transaction lifecycle:
   * 1. Reads /deletionJobs/{targetUid} inside the transaction.
   * 2. Asserts workerId, fencing generation, status !== 'completed', and leaseExpiresAt > now.
   * 3. Executes operationFn(transaction, jobData). All reads must precede all writes.
   * 4. If beforeCommitHook is provided (for deterministic race testing), executes it before commit.
   * 5. Commits atomically. If a secondary worker updated /deletionJobs/{targetUid}
   *    between step 1 and commit, Firestore transaction isolation aborts and retries,
   *    where the generation mismatch immediately throws StaleWorkerError without committing.
   */
  async runFencedTransaction(operationFn, beforeCommitHook = null) {
    if (this.aborted) {
      throw new StaleWorkerError('Worker lease was aborted due to preemption or heartbeat failure');
    }
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const generation = this.generation;
    const workerId = this.workerId;
    const duration = this.leaseDurationMs;

    this.activeTransactionCount = (this.activeTransactionCount || 0) + 1;
    let attempts = 0;
    try {
      const res = await this.db.runTransaction(async (transaction) => {
        attempts++;
        // 1. Transactionally read the job document first
        const jobSnap = await transaction.get(jobRef);
        if (!jobSnap.exists) {
          throw new StaleWorkerError('Job document disappeared');
        }
        const jobData = jobSnap.data();

        // 2. Strict fencing token and lease assertion
        if (jobData.generation !== generation || jobData.workerId !== workerId) {
          this.aborted = true;
          this.stopHeartbeat();
          throw new StaleWorkerError(
            `Fencing token mismatch: worker generation ${generation} superseded by generation ${jobData.generation}`
          );
        }

        if (jobData.status === 'completed') {
          this.aborted = true;
          this.stopHeartbeat();
          throw new StaleWorkerError('Job is already completed');
        }

        const nowMs = Date.now();
        const expMs = jobData.leaseExpiresAt && jobData.leaseExpiresAt.toMillis
          ? jobData.leaseExpiresAt.toMillis()
          : new Date(jobData.leaseExpiresAt).getTime();

        if (expMs <= nowMs) {
          this.aborted = true;
          this.stopHeartbeat();
          throw new StaleWorkerError('Worker lease has expired');
        }

        // 3. Execute caller reads and buffered writes
        const opResult = await operationFn(transaction, jobData);

        // 4. Touch jobRef inside transaction to establish audit record and enforce write-set fencing
        transaction.set(
          jobRef,
          {
            lastOperationAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // 5. Controlled barrier hook for deterministic race testing
        if (beforeCommitHook) {
          await beforeCommitHook(transaction, jobData);
        }

        return opResult;
      });
      this.transactionAttempts = attempts;
      return res;
    } catch (err) {
      this.transactionAttempts = attempts;
      throw err;
    } finally {
      this.activeTransactionCount = Math.max(0, (this.activeTransactionCount || 1) - 1);
    }
  }

  async updateStage(newStage, updates = {}) {
    await this.assertActive();
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const generation = this.generation;
    const workerId = this.workerId;
    const duration = this.leaseDurationMs;

    await this.db.runTransaction(async (transaction) => {
      const snap = await transaction.get(jobRef);
      if (!snap.exists) throw new StaleWorkerError('Job document disappeared');
      const data = snap.data();
      if (data.generation !== generation || data.workerId !== workerId) {
        throw new StaleWorkerError(`Stage update failed: generation ${generation} superseded by ${data.generation}`);
      }
      transaction.set(
        jobRef,
        {
          stage: newStage,
          leaseExpiresAt: new Date(Date.now() + duration),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...updates,
        },
        { merge: true }
      );
    });
    this.stage = newStage;
  }

  async finalize(finalUpdates = {}) {
    this.stopHeartbeat();
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const generation = this.generation;
    const workerId = this.workerId;

    await this.db.runTransaction(async (transaction) => {
      const snap = await transaction.get(jobRef);
      if (!snap.exists) return;
      const data = snap.data();
      if (data.generation !== generation || (data.workerId && data.workerId !== workerId)) {
        throw new StaleWorkerError(`Finalize failed: generation ${generation} superseded by ${data.generation}`);
      }
      transaction.set(
        jobRef,
        {
          uid: this.targetUid,
          status: 'completed',
          stage: 'completed',
          workerId: admin.firestore.FieldValue.delete(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // only terminal completed receives TTL
          ...finalUpdates,
        },
        { merge: true }
      );
    });
  }

  async releaseOnError(errorMessage) {
    this.stopHeartbeat();
    const jobRef = this.db.collection('deletionJobs').doc(this.targetUid);
    const generation = this.generation;
    const workerId = this.workerId;

    try {
      await this.db.runTransaction(async (transaction) => {
        const snap = await transaction.get(jobRef);
        if (!snap.exists) return;
        const data = snap.data();
        if (data.generation === generation && data.workerId === workerId) {
          transaction.set(
            jobRef,
            {
              status: 'failed',
              error: errorMessage,
              workerId: admin.firestore.FieldValue.delete(),
              leaseExpiresAt: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      });
    } catch (_) {}
  }
}

/**
 * Standalone lease wrappers for backward compatibility and test access.
 */
async function acquireWorkerLease(db, targetUid, workerId, leaseDurationMs = 45000) {
  const session = new DeletionWorkerSession(db, targetUid, 'worker', leaseDurationMs);
  session.workerId = workerId;
  const res = await session.acquireLease();
  session.stopHeartbeat();
  return { ...res, session };
}

async function updateJobStage(db, targetUid, workerId, newStage, updates = {}, leaseDurationMs = 45000) {
  const jobRef = db.collection('deletionJobs').doc(targetUid);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    if (!snap.exists) throw new StaleWorkerError('Job document disappeared');
    const data = snap.data();
    if (data.workerId !== workerId) {
      throw new StaleWorkerError(`Worker ${workerId} lost exclusive lease to ${data.workerId}`);
    }
    transaction.set(
      jobRef,
      {
        stage: newStage,
        leaseExpiresAt: new Date(Date.now() + leaseDurationMs),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...updates,
      },
      { merge: true }
    );
  });
}

async function finalizeJob(db, targetUid, workerId, finalUpdates = {}) {
  const jobRef = db.collection('deletionJobs').doc(targetUid);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    if (!snap.exists) return;
    const data = snap.data();
    if (data.workerId && data.workerId !== workerId) {
      throw new StaleWorkerError(`Cannot finalize: exclusive lease owned by ${data.workerId}`);
    }
    transaction.set(
      jobRef,
      {
        uid: targetUid,
        status: 'completed',
        stage: 'completed',
        workerId: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        ...finalUpdates,
      },
      { merge: true }
    );
  });
}

/**
 * Generates a stable, neutral pseudonymous issuer reference for a deleted merchant.
 */
function getNeutralIssuerId(merchantUid) {
  const hash = crypto.createHash('sha256').update(`parchipocket:issuer:${merchantUid}`).digest('hex');
  return `issuer_neutral_${hash.substring(0, 16)}`;
}

/**
 * Trusted backend recovery mechanism to reconcile interrupted or unresumable deletion jobs.
 */
async function reconcilePendingDeletionJobs(db, auth, specificUid = null, leaseDurationMs = 45000) {
  const jobsRef = db.collection('deletionJobs');
  if (specificUid) {
    const doc = await jobsRef.doc(specificUid).get();
    if (!doc.exists) return null;
    return await reconcileSingleJob(doc, db, auth, leaseDurationMs);
  }

  const inProgressSnap = await jobsRef.where('status', 'in', ['in_progress', 'failed']).get();
  const results = [];
  for (const doc of inProgressSnap.docs) {
    results.push(await reconcileSingleJob(doc, db, auth, leaseDurationMs));
  }
  return results;
}

async function reconcileSingleJob(doc, db, auth, leaseDurationMs = 45000) {
  const targetUid = doc.id;
  const session = new DeletionWorkerSession(db, targetUid, 'reconciler', leaseDurationMs, 10000);
  const lease = await session.acquireLease();

  if (!lease.acquired) {
    if (lease.alreadyCompleted) {
      return { uid: targetUid, recovered: false, status: 'completed' };
    }
    return {
      uid: targetUid,
      recovered: false,
      status: 'locked_by_other_worker',
      activeWorkerId: lease.activeWorkerId,
    };
  }

  try {
    let authExists = false;
    try {
      await auth.getUser(targetUid);
      authExists = true;
    } catch (authErr) {
      if (authErr.code === 'auth/user-not-found') {
        authExists = false;
      } else {
        throw authErr;
      }
    }

    const userRef = db.collection('users').doc(targetUid);

    if (!authExists) {
      // Auth user was already deleted. Complete residual collections wipe under exclusive lease.
      await deleteUserCollectionsFenced(db, userRef, session, 50);
      await session.finalize({ recoveredBy: 'backend_reconciliation' });
      return { uid: targetUid, recovered: true, status: 'completed' };
    }

    // Auth user still exists: release lease so user can retry or callable can resume
    await session.releaseOnError('Awaiting user retry or client completion');
    return {
      uid: targetUid,
      recovered: false,
      status: lease.jobData ? lease.jobData.status : 'in_progress',
      stage: lease.jobData ? lease.jobData.stage : 'not_started',
    };
  } catch (error) {
    await session.releaseOnError(error.message || String(error));
    throw error;
  }
}

/**
 * Deletes user subcollections and profile document using bounded, fenced transactions.
 * Each batch of up to `batchSize` documents is deleted inside an atomic transaction that
 * transactionally reads and verifies the worker's fencing token against /deletionJobs/{uid}.
 */
async function deleteUserCollectionsFenced(db, userRef, session, batchSize = 50) {
  let collections = [];
  try {
    collections = await userRef.listCollections();
  } catch (_) {
    collections = [];
  }

  const knownNames = ['bills', 'expenses', 'householdExpenses', 'savedShops', 'claimedReceipts', 'claimedReceiptsIndex'];
  const colMap = new Map();
  for (const c of collections) {
    colMap.set(c.id, c);
  }
  for (const name of knownNames) {
    if (!colMap.has(name)) {
      colMap.set(name, userRef.collection(name));
    }
  }

  for (const col of colMap.values()) {
    let hasMore = true;
    while (hasMore) {
      const snap = await col.limit(batchSize).get();
      if (snap.empty) {
        hasMore = false;
        break;
      }

      // Check for nested subcollections (e.g. claimedReceipts/{issuer}/bills)
      for (const doc of snap.docs) {
        let subcols = [];
        try {
          subcols = await doc.ref.listCollections();
        } catch (_) {
          subcols = [];
        }

        // If claimedReceipts, also explicitly check bills subcollection
        if (col.id === 'claimedReceipts' && !subcols.some(s => s.id === 'bills')) {
          subcols.push(doc.ref.collection('bills'));
        }

        for (const subcol of subcols) {
          let subHasMore = true;
          while (subHasMore) {
            const subSnap = await subcol.limit(batchSize).get();
            if (subSnap.empty) {
              subHasMore = false;
              break;
            }
            await session.runFencedTransaction(async (t) => {
              for (const subDoc of subSnap.docs) {
                t.delete(subDoc.ref);
              }
            });
            if (subSnap.docs.length < batchSize) subHasMore = false;
          }
        }
      }

      // Transactionally fenced deletion of current batch
      await session.runFencedTransaction(async (t) => {
        for (const doc of snap.docs) {
          t.delete(doc.ref);
        }
      });

      if (snap.docs.length < batchSize) {
        hasMore = false;
      }
    }
  }

  // Finally delete the root user document itself transactionally fenced
  await session.runFencedTransaction(async (t) => {
    t.delete(userRef);
  });
}

/**
 * Callable Cloud Function: deleteUserAccount
 */
exports.deleteUserAccount = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    // 1. Authenticated Identity Verification
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Authentication required. You must be signed in to request account deletion.'
      );
    }

    const targetUid = request.auth.uid;

    // 2. Reject Cross-User Deletion Spoofing
    if (request.data && request.data.targetUid && request.data.targetUid !== targetUid) {
      throw new HttpsError(
        'permission-denied',
        'Access denied. You cannot request account deletion for another user.'
      );
    }

    // 3. Enforce 5-Minute Reauthentication Freshness Policy
    const authTime = request.auth.token ? request.auth.token.auth_time : null;
    const nowSeconds = Math.floor(Date.now() / 1000);
    const maxAgeSeconds = 300; // 5 minutes

    const isEmulator = Boolean(
      process.env.FUNCTIONS_EMULATOR ||
      process.env.FIRESTORE_EMULATOR_HOST ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST
    );
    const allowTestOverride = isEmulator && request.data && request.data.__skipFreshnessCheckForTest === true;

    if (!allowTestOverride) {
      if (!authTime || (nowSeconds - authTime) > maxAgeSeconds) {
        throw new HttpsError(
          'failed-precondition',
          'Recent authentication required. Please re-authenticate with a fresh SMS OTP before deleting your account.'
        );
      }
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(targetUid);
    const session = new DeletionWorkerSession(db, targetUid, 'callable', 45000, 15000);

    // 4. Transactional Worker Lease Acquisition with Fencing Token
    const lease = await session.acquireLease();
    if (!lease.acquired) {
      if (lease.alreadyCompleted) {
        return {
          success: true,
          message: 'Account has already been deleted.',
          completed: true,
        };
      }
      return {
        success: true,
        message: 'Account deletion is already actively in progress by an authorized worker. Please check back shortly.',
        completed: false,
        stage: lease.jobData ? lease.jobData.stage : 'in_progress',
        leaseActive: true,
      };
    }

    let stage = session.stage;

    try {
      // 5. Stage 1: Enforce Deletion Lock on User Document
      if (stage === 'not_started' || stage === 'locking') {
        await session.runFencedTransaction(async (t) => {
          const userSnap = await t.get(userRef);
          if (userSnap.exists) {
            t.set(
              userRef,
              {
                status: 'deleting',
                deletionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
        });
        await session.updateStage('locked');
        stage = 'locked';
      }

      // 6. Stage 2: Cross-User Receipt Claims & Customer Proofs-of-Purchase
      if (stage === 'locked') {
        // 6A. Handle claims created by this user (Merchant role)
        const claimsAsOwner = await db
          .collection('receiptClaims')
          .where('ownerUid', '==', targetUid)
          .get();

        if (!claimsAsOwner.empty) {
          const neutralIssuerId = getNeutralIssuerId(targetUid);

          for (const claimDoc of claimsAsOwner.docs) {
            const claim = claimDoc.data();
            if (claim.status === 'open') {
              await session.runFencedTransaction(async (t) => {
                t.delete(claimDoc.ref);
              });
            } else if (claim.status === 'claimed') {
              const customerUid = claim.claimedBy;
              const sourceBillId = claim.sourceBillId;

              let oldCopyRef = null;
              let oldIndexRef = null;
              let newCopyRef = null;
              let newIndexRef = null;

              if (customerUid && customerUid !== '[DELETED_USER]' && sourceBillId) {
                const customerUserRef = db.collection('users').doc(customerUid);
                oldCopyRef = customerUserRef
                  .collection('claimedReceipts')
                  .doc(targetUid)
                  .collection('bills')
                  .doc(sourceBillId);
                oldIndexRef = customerUserRef
                  .collection('claimedReceiptsIndex')
                  .doc(`${targetUid}~${sourceBillId}`);

                newCopyRef = customerUserRef
                  .collection('claimedReceipts')
                  .doc(neutralIssuerId)
                  .collection('bills')
                  .doc(sourceBillId);
                newIndexRef = customerUserRef
                  .collection('claimedReceiptsIndex')
                  .doc(`${neutralIssuerId}~${sourceBillId}`);
              }

              await session.runFencedTransaction(async (t) => {
                // Reads first inside the fenced transaction
                const oldCopySnap = oldCopyRef ? await t.get(oldCopyRef) : null;
                const oldIndexSnap = oldIndexRef ? await t.get(oldIndexRef) : null;

                // Writes next inside the same transaction
                t.update(claimDoc.ref, {
                  ownerUid: neutralIssuerId,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                if (oldCopySnap && oldCopySnap.exists) {
                  const copyData = oldCopySnap.data();
                  t.set(newCopyRef, {
                    ...copyData,
                    ownerUid: neutralIssuerId,
                  });
                  t.delete(oldCopyRef);
                }

                if (oldIndexSnap && oldIndexSnap.exists) {
                  const indexData = oldIndexSnap.data();
                  t.set(newIndexRef, {
                    ...indexData,
                    ownerUid: neutralIssuerId,
                  });
                  t.delete(oldIndexRef);
                }
              });
            }
          }
        }

        // 6B. Handle claims claimed by this user (Customer role)
        const claimsAsCustomer = await db
          .collection('receiptClaims')
          .where('claimedBy', '==', targetUid)
          .get();

        if (!claimsAsCustomer.empty) {
          const CHUNK_SIZE = 50;
          for (let i = 0; i < claimsAsCustomer.docs.length; i += CHUNK_SIZE) {
            const chunk = claimsAsCustomer.docs.slice(i, i + CHUNK_SIZE);
            await session.runFencedTransaction(async (t) => {
              for (const doc of chunk) {
                t.update(doc.ref, {
                  claimedBy: '[DELETED_USER]',
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
            });
          }
        }

        await session.updateStage('claims_handled');
        stage = 'claims_handled';
      }

      // 7. Stage 3: Recursive Subcollection and Profile Document Deletion
      if (stage === 'claims_handled') {
        await deleteUserCollectionsFenced(db, userRef, session, 50);
        await session.updateStage('collections_deleted');
        stage = 'collections_deleted';
      }

      // 8. Stage 4: Firebase Authentication Account Deletion
      if (stage === 'collections_deleted') {
        await session.assertActive();
        try {
          await admin.auth().deleteUser(targetUid);
        } catch (authErr) {
          if (authErr.code !== 'auth/user-not-found') {
            throw new HttpsError(
              'internal',
              `Failed to delete authentication user: ${authErr.message}`
            );
          }
        }

        // Finalize terminal completed job with 24h TTL
        await session.finalize();
      }

      return {
        success: true,
        message: 'Account and associated data deleted successfully.',
        completed: true,
      };
    } catch (error) {
      await session.releaseOnError(error.message || String(error));
      throw error;
    }
  }
);

/**
 * Automatic Event-Driven Recovery Trigger:
 * Invoked automatically by Firebase Authentication when an Auth account is deleted.
 */
exports.onUserDeleted = functionsV1.auth.user().onDelete(async (userRecord) => {
  const db = admin.firestore();
  const auth = admin.auth();
  return await reconcilePendingDeletionJobs(db, auth, userRecord.uid);
});

/**
 * Automatic Scheduled Recovery Sweeper:
 * Runs periodically to reconcile any orphaned or stalled deletion jobs.
 */
exports.reconcileDeletionJobsScheduler = onSchedule(
  {
    schedule: 'every 10 minutes',
    timeZone: 'UTC',
    retryCount: 3,
  },
  async (event) => {
    const db = admin.firestore();
    const auth = admin.auth();
    return await reconcilePendingDeletionJobs(db, auth);
  }
);

exports.DeletionWorkerSession = DeletionWorkerSession;
exports.acquireWorkerLease = acquireWorkerLease;
exports.updateJobStage = updateJobStage;
exports.finalizeJob = finalizeJob;
exports.reconcilePendingDeletionJobs = reconcilePendingDeletionJobs;
exports.getNeutralIssuerId = getNeutralIssuerId;
exports.deleteUserCollectionsFenced = deleteUserCollectionsFenced;
exports.StaleWorkerError = StaleWorkerError;
