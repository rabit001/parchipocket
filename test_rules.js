const http = require('http');

const PORT = 8088;
const PROJECT_ID = process.env.FIRESTORE_EMULATOR_PROJECT_ID || 'demo-parchipocket-phase4';
if (!PROJECT_ID.startsWith('demo-')) {
  throw new Error('Rules tests must use an isolated demo- Firestore Emulator project ID.');
}
const BASE_URL = `http://127.0.0.1:${PORT}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function makeJwt(userId) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ sub: userId, user_id: userId, auth_time: 123456789 })).toString('base64url');
  return `${header}.${payload}.`;
}

function request({ method, path, data, userId }) {
  return new Promise((resolve) => {
    const url = new URL(`${BASE_URL}${path}`);
    const body = data ? JSON.stringify(data) : '';
    const headers = {
      'Content-Type': 'application/json',
    };
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

function firestoreName(path) {
  return `projects/${PROJECT_ID}/databases/(default)/documents/${path}`;
}

function createWrite(path, data, serverTimestampFields = []) {
  const fields = { ...data };
  for (const field of serverTimestampFields) delete fields[field];
  const write = {
    update: { name: firestoreName(path), ...wrapDocument(fields) },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: { exists: false },
  };
  if (serverTimestampFields.length) {
    write.updateTransforms = serverTimestampFields.map((fieldPath) => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    }));
  }
  return write;
}

function updateWrite(path, data, serverTimestampFields = []) {
  const write = {
    update: { name: firestoreName(path), ...wrapDocument(data) },
    updateMask: { fieldPaths: Object.keys(data) },
    currentDocument: { exists: true },
  };
  if (serverTimestampFields.length) {
    write.updateTransforms = serverTimestampFields.map((fieldPath) => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    }));
  }
  return write;
}

async function commit(writes, userId) {
  return request({ method: 'POST', path: ':commit', data: { writes }, userId });
}

function timestampField(dateStr) {
  return { timestampValue: dateStr || new Date().toISOString() };
}

function stringField(str) {
  return { stringValue: str };
}

function integerField(val) {
  return { integerValue: val.toString() };
}

function doubleField(val) {
  return { doubleValue: val };
}

function booleanField(val) {
  return { booleanValue: val };
}

function mapField(map) {
  const fields = {};
  for (const [k, v] of Object.entries(map)) {
    fields[k] = wrapValue(v);
  }
  return { mapValue: { fields } };
}

function listField(list) {
  return { arrayValue: { values: list.map(wrapValue) } };
}

function wrapValue(v) {
  if (typeof v === 'string') return stringField(v);
  if (typeof v === 'boolean') return booleanField(v);
  if (typeof v === 'number') return Number.isInteger(v) ? integerField(v) : doubleField(v);
  if (v instanceof Date) return timestampField(v.toISOString());
  if (Array.isArray(v)) return listField(v);
  if (v && typeof v === 'object' && v.timestampValue) return v;
  if (v && typeof v === 'object') return mapField(v);
  return { nullValue: null };
}

function wrapDocument(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = wrapValue(v);
  }
  return { fields };
}

async function runTests() {
  console.log('--- Starting Firestore Security Rules Emulator Tests ---');
  let passed = 0;
  let failed = 0;

  async function assertRule({ description, method, path, data, userId, expectedStatus }) {
    const res = await request({ method, path, data, userId });
    const success = res.status === expectedStatus;
    if (success) {
      console.log(`[PASS] ${description} (HTTP ${res.status})`);
      passed++;
    } else {
      console.error(`[FAIL] ${description} (Expected HTTP ${expectedStatus}, got HTTP ${res.status})`);
      if (res.body) console.error('       Body:', JSON.stringify(res.body));
      failed++;
    }
  }

  const validProfile = {
    name: 'User A',
    role: 'customer',
    updatedAt: timestampField(),
  };

  const validBillItem = {
    name: 'Item 1',
    quantity: 1,
    unitPrice: 50.0,
  };

  const validBill = {
    id: 'PP-1001',
    store: 'Sharma Kirana Store',
    items: [validBillItem],
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };

  // 1. Unauthenticated access denied
  await assertRule({
    description: '1.1 Unauthenticated read denied on user profile',
    method: 'GET',
    path: '/users/userA',
    userId: null,
    expectedStatus: 403,
  });

  // Receipt claim security is tested with server-time transforms and atomic REST commits.
  const sellerProfile = { ...validProfile, name: 'Seller', role: 'shopOwner' };
  const customerProfile = { ...validProfile, name: 'Customer', role: 'customer' };
  const otherCustomerProfile = { ...validProfile, name: 'Other Customer', role: 'customer' };
  await assertRule({ description: '14.1 Seller profile for claim tests created', method: 'PATCH', path: '/users/seller', data: wrapDocument(sellerProfile), userId: 'seller', expectedStatus: 200 });
  await assertRule({ description: '14.2 Customer profile for claim tests created', method: 'PATCH', path: '/users/customer', data: wrapDocument(customerProfile), userId: 'customer', expectedStatus: 200 });
  await assertRule({ description: '14.3 Second customer profile for claim tests created', method: 'PATCH', path: '/users/otherCustomer', data: wrapDocument(otherCustomerProfile), userId: 'otherCustomer', expectedStatus: 200 });

  const sourceBillId = 'claim-source-1';
  const sourceDate = timestampField('2026-10-23T12:00:00.000Z');
  const sourceBill = { ...validBill, id: sourceBillId, createdAt: sourceDate, customerPhone: '+919999999999', isUdhaar: true, isSettled: false, isSaved: false };
  await assertRule({ description: '14.4 Seller can create source bill', method: 'PATCH', path: `/users/seller/bills/${sourceBillId}`, data: wrapDocument(sourceBill), userId: 'seller', expectedStatus: 200 });
  const receipt = { id: sourceBillId, store: sourceBill.store, items: sourceBill.items, createdAt: sourceDate, paymentMode: sourceBill.paymentMode };
  const digest = 'a'.repeat(64);
  const claim = {
    ownerUid: 'seller', sourceBillId, receipt,
    expiresAt: timestampField(new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString()),
    status: 'open',
  };
  const claimCreate = await commit([
    createWrite(`receiptClaims/${digest}`, claim),
  ], 'seller');
  if (claimCreate.ok) { console.log('[PASS] 14.5 Seller creates a source-bound, expiring claim'); passed++; }
  else { console.error('[FAIL] 14.5 Seller claim creation denied:', claimCreate.body); failed++; }

  const openRead = await request({ method: 'GET', path: `/receiptClaims/${digest}`, userId: 'customer' });
  if (openRead.status === 200) { console.log('[PASS] 14.6 Authenticated bearer can read only a known open claim'); passed++; }
  else { console.error('[FAIL] 14.6 Expected open claim get, got', openRead.status, openRead.body); failed++; }
  await assertRule({ description: '14.7 Claim collection enumeration denied', method: 'GET', path: '/receiptClaims', userId: 'customer', expectedStatus: 403 });

  const immutableClaimChanges = [
    ['expiry extension', { expiresAt: timestampField(new Date(Date.now() + 23 * 60 * 60 * 1000).toISOString()) }],
    ['owner UID', { ownerUid: 'otherSeller' }],
    ['source bill', { sourceBillId: 'different-bill' }],
    ['receipt snapshot', { receipt: { ...receipt, items: [{ name: 'Forged', quantity: 1, unitPrice: 1 }] } }],
    ['status', { status: 'claimed' }],
    ['claimedBy', { claimedBy: 'customer' }],
    ['claimedAt', { claimedAt: timestampField(new Date().toISOString()) }],
  ];
  for (const [label, patch] of immutableClaimChanges) {
    const result = await commit([
      updateWrite(`receiptClaims/${digest}`, patch),
    ], 'seller');
    if (result.status === 403) { console.log(`[PASS] 14.7a Seller cannot alter ${label} on an open claim`); passed++; }
    else { console.error(`[FAIL] 14.7a Seller unexpectedly altered ${label}:`, result.body); failed++; }
  }

  const copy = { recipientUid: 'customer', ownerUid: 'seller', sourceBillId, receipt, claimedAt: null, claimDigest: digest };
  const indexId = `seller~${sourceBillId}`;
  const claimCommit = await commit([
    updateWrite(`receiptClaims/${digest}`, {
      status: 'claimed',
      claimedBy: 'customer',
    }),
    createWrite(`users/customer/claimedReceipts/seller/bills/${sourceBillId}`, copy, ['claimedAt']),
    createWrite(`users/customer/claimedReceiptsIndex/${indexId}`, copy, ['claimedAt']),
  ], 'customer');
  if (claimCommit.ok) { console.log('[PASS] 14.8 Atomic claim consumes code and creates immutable copy plus customer index'); passed++; }
  else { console.error('[FAIL] 14.8 Atomic claim denied:', claimCommit.body); failed++; }

  await assertRule({ description: '14.9 Customer can read claimed receipt copy', method: 'GET', path: `/users/customer/claimedReceipts/seller/bills/${sourceBillId}`, userId: 'customer', expectedStatus: 200 });
  await assertRule({ description: '14.10 Customer can list own claim index', method: 'GET', path: '/users/customer/claimedReceiptsIndex', userId: 'customer', expectedStatus: 200 });
  await assertRule({ description: '14.11 Seller cannot read customer copy', method: 'GET', path: `/users/customer/claimedReceipts/seller/bills/${sourceBillId}`, userId: 'seller', expectedStatus: 403 });
  await assertRule({ description: '14.12 Other customer cannot read customer copy', method: 'GET', path: `/users/customer/claimedReceipts/seller/bills/${sourceBillId}`, userId: 'otherCustomer', expectedStatus: 403 });
  await assertRule({ description: '14.13 Claimant can read consumed claim for idempotent retry', method: 'GET', path: `/receiptClaims/${digest}`, userId: 'customer', expectedStatus: 200 });
  await assertRule({ description: '14.14 Seller can read own consumed claim', method: 'GET', path: `/receiptClaims/${digest}`, userId: 'seller', expectedStatus: 200 });
  await assertRule({ description: '14.15 Unrelated customer cannot read consumed claim even with known digest', method: 'GET', path: `/receiptClaims/${digest}`, userId: 'otherCustomer', expectedStatus: 403 });
  await assertRule({ description: '14.16 Customer cannot alter claimed copy', method: 'PATCH', path: `/users/customer/claimedReceipts/seller/bills/${sourceBillId}`, data: wrapDocument({ ...copy, receipt: { ...receipt, items: [{ name: 'Forged', quantity: 1, unitPrice: 1 }] } }), userId: 'customer', expectedStatus: 403 });

  const replay = await commit([
    createWrite(`users/otherCustomer/claimedReceipts/seller/bills/${sourceBillId}`, { ...copy, recipientUid: 'otherCustomer' }, ['claimedAt']),
    createWrite(`users/otherCustomer/claimedReceiptsIndex/${indexId}`, { ...copy, recipientUid: 'otherCustomer' }, ['claimedAt']),
  ], 'otherCustomer');
  if (replay.status === 403) { console.log('[PASS] 14.17 Second account cannot create a copy from an already consumed code'); passed++; }
  else { console.error('[FAIL] 14.17 Second account unexpectedly created a duplicate claim copy'); failed++; }

  // A claimant cannot assign the consumed claim to another UID in the same write.
  const sourceBillId2 = 'claim-source-wrong-claimant';
  const sourceDate2 = timestampField(new Date().toISOString());
  const sourceBill2 = { ...validBill, id: sourceBillId2, createdAt: sourceDate2 };
  await assertRule({ description: '14.18 Seller can create second source bill for claimant-binding test', method: 'PATCH', path: `/users/seller/bills/${sourceBillId2}`, data: wrapDocument(sourceBill2), userId: 'seller', expectedStatus: 200 });
  const receipt2 = { id: sourceBillId2, store: sourceBill2.store, items: sourceBill2.items, createdAt: sourceDate2, paymentMode: sourceBill2.paymentMode };
  const digest2 = 'c'.repeat(64);
  const claim2 = { ownerUid: 'seller', sourceBillId: sourceBillId2, receipt: receipt2, expiresAt: timestampField(new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString()), status: 'open' };
  const secondClaimCreate = await commit([createWrite(`receiptClaims/${digest2}`, claim2)], 'seller');
  if (secondClaimCreate.ok) { console.log('[PASS] 14.19 Seller creates second source-bound claim for claimant-binding test'); passed++; }
  else { console.error('[FAIL] 14.19 Could not create claim for claimant-binding test:', secondClaimCreate.body); failed++; }
  const wrongRecipientCopy = { recipientUid: 'customer', ownerUid: 'seller', sourceBillId: sourceBillId2, receipt: receipt2, claimedAt: null, claimDigest: digest2 };
  const wrongClaimantCommit = await commit([
    updateWrite(`receiptClaims/${digest2}`, { status: 'claimed', claimedBy: 'otherCustomer' }),
    createWrite(`users/customer/claimedReceipts/seller/bills/${sourceBillId2}`, wrongRecipientCopy, ['claimedAt']),
    createWrite(`users/customer/claimedReceiptsIndex/seller~${sourceBillId2}`, wrongRecipientCopy, ['claimedAt']),
  ], 'customer');
  if (wrongClaimantCommit.status === 403) { console.log('[PASS] 14.20 Claim claimant UID must match the customer copy recipient'); passed++; }
  else { console.error('[FAIL] 14.20 Claimant mismatch unexpectedly committed:', wrongClaimantCommit.body); failed++; }

  const alteredReceiptClaim = { ...claim, receipt: { ...receipt, items: [{ name: 'Forged', quantity: 1, unitPrice: 1 }] } };
  const alteredDigest = 'b'.repeat(64);
  const altered = await commit([createWrite(`receiptClaims/${alteredDigest}`, alteredReceiptClaim)], 'seller');
  if (altered.status === 403) { console.log('[PASS] 14.21 Seller cannot issue a snapshot that differs from source bill'); passed++; }
  else { console.error('[FAIL] 14.21 Forged receipt snapshot unexpectedly issued'); failed++; }

  await assertRule({
    description: '1.2 Unauthenticated write denied on user profile',
    method: 'PATCH',
    path: '/users/userA',
    data: wrapDocument(validProfile),
    userId: null,
    expectedStatus: 403,
  });

  // 2. Own user profile creation
  await assertRule({
    description: '2.1 User A can create own user profile',
    method: 'PATCH',
    path: '/users/userA',
    data: wrapDocument(validProfile),
    userId: 'userA',
    expectedStatus: 200,
  });

  // 3. Cross-user access denied
  await assertRule({
    description: '3.1 User B denied read on User A profile',
    method: 'GET',
    path: '/users/userA',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '3.2 User B denied write on User A profile',
    method: 'PATCH',
    path: '/users/userA',
    data: wrapDocument({ name: 'Hacked', role: 'customer', updatedAt: timestampField() }),
    userId: 'userB',
    expectedStatus: 403,
  });

  // 4. Role tampering & admin escalation rejection
  await assertRule({
    description: '4.1 User A denied role change on profile update',
    method: 'PATCH',
    path: '/users/userA',
    data: wrapDocument({ name: 'User A', role: 'shopOwner', updatedAt: timestampField() }),
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '4.2 User A denied admin field injection on profile update',
    method: 'PATCH',
    path: '/users/userA',
    data: wrapDocument({ name: 'User A', role: 'customer', admin: true, updatedAt: timestampField() }),
    userId: 'userA',
    expectedStatus: 403,
  });

  // 5. Valid 1-item bill creation
  await assertRule({
    description: '5.1 User A can create valid 1-item bill',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1001',
    data: wrapDocument(validBill),
    userId: 'userA',
    expectedStatus: 200,
  });

  // 6. Valid 10-item bill creation
  const tenItems = Array.from({ length: 10 }, (_, i) => ({
    name: `Item ${i + 1}`,
    quantity: i + 1,
    unitPrice: 10.0 * (i + 1),
  }));
  const tenItemBill = {
    id: 'PP-1010',
    store: 'Sharma Kirana Store',
    items: tenItems,
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };
  await assertRule({
    description: '6.1 User A can create valid 10-item bill',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1010',
    data: wrapDocument(tenItemBill),
    userId: 'userA',
    expectedStatus: 200,
  });

  // 7. Invalid items and 11-item bill rejection
  const elevenItems = Array.from({ length: 11 }, (_, i) => ({
    name: `Item ${i + 1}`,
    quantity: 1,
    unitPrice: 10.0,
  }));
  const elevenItemBill = {
    id: 'PP-1011',
    store: 'Sharma Kirana Store',
    items: elevenItems,
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };
  await assertRule({
    description: '7.1 11-item bill rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1011',
    data: wrapDocument(elevenItemBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  const malformedItemBill = {
    id: 'PP-1002',
    store: 'Sharma Kirana Store',
    items: [{ name: 'Bad Item', quantity: -1, unitPrice: 10.0 }],
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };
  await assertRule({
    description: '7.2 Malformed item (negative quantity) rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1002',
    data: wrapDocument(malformedItemBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  const extraKeyItemBill = {
    id: 'PP-1004',
    store: 'Sharma Kirana Store',
    items: [{ name: 'Item 1', quantity: 1, unitPrice: 10.0, extraKey: 'hacked' }],
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };
  await assertRule({
    description: '7.3 Item containing unexpected extra key rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1004',
    data: wrapDocument(extraKeyItemBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  const missingUnitPriceBill = {
    id: 'PP-1005',
    store: 'Sharma Kirana Store',
    items: [{ name: 'Item 1', quantity: 1 }],
    createdAt: timestampField(),
    paymentMode: 'Cash',
    isSaved: false,
    isSettled: false,
  };
  await assertRule({
    description: '7.4 Bill item missing unitPrice rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1005',
    data: wrapDocument(missingUnitPriceBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  // 8. Bill ID mismatch rejection
  await assertRule({
    description: '8.1 Bill doc ID mismatch rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-WRONG_DOC_ID',
    data: wrapDocument(validBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  // 9. Empty paymentMode rejection
  const emptyPaymentBill = {
    ...validBill,
    id: 'PP-1003',
    paymentMode: '',
  };
  await assertRule({
    description: '9.1 Empty paymentMode bill rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1003',
    data: wrapDocument(emptyPaymentBill),
    userId: 'userA',
    expectedStatus: 403,
  });

  // 10. Permitted and forbidden bill updates
  const billStateSavedTrue = {
    ...validBill,
    isSaved: true,
  };
  await assertRule({
    description: '10.1 Permitted state transition isSaved: false -> true allowed',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1001',
    data: wrapDocument(billStateSavedTrue),
    userId: 'userA',
    expectedStatus: 200,
  });

  const billStateSettledTrue = {
    ...billStateSavedTrue,
    isSettled: true,
  };
  await assertRule({
    description: '10.2 Permitted state transition isSettled: false -> true allowed',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1001',
    data: wrapDocument(billStateSettledTrue),
    userId: 'userA',
    expectedStatus: 200,
  });

  const billStateForbiddenChange = {
    ...billStateSavedTrue,
    store: 'Modified Store Name',
  };
  await assertRule({
    description: '10.3 Forbidden store modification on update rejected',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1001',
    data: wrapDocument(billStateForbiddenChange),
    userId: 'userA',
    expectedStatus: 403,
  });

  const billWithoutOptionalFields = {
    id: 'PP-2001',
    store: 'Sharma Kirana Store',
    items: [validBillItem],
    createdAt: timestampField(),
    paymentMode: 'Cash',
  };
  await assertRule({
    description: '10.4 Create bill without optional fields allowed',
    method: 'PATCH',
    path: '/users/userA/bills/PP-2001',
    data: wrapDocument(billWithoutOptionalFields),
    userId: 'userA',
    expectedStatus: 200,
  });

  await assertRule({
    description: '10.5 Update bill when optional fields are absent allowed',
    method: 'PATCH',
    path: '/users/userA/bills/PP-2001',
    data: wrapDocument(billWithoutOptionalFields),
    userId: 'userA',
    expectedStatus: 200,
  });

  // 11. Bill and Expense deletion policy (Disallowed)
  await assertRule({
    description: '11.1 Bill deletion denied',
    method: 'DELETE',
    path: '/users/userA/bills/PP-1001',
    userId: 'userA',
    expectedStatus: 403,
  });

  // 12. Saved shop validation and deletion
  const validSavedShop = {
    shopName: 'Sharma Kirana Store',
    updatedAt: timestampField(),
  };
  await assertRule({
    description: '12.1 User A can create valid saved shop',
    method: 'PATCH',
    path: '/users/userA/savedShops/shop1',
    data: wrapDocument(validSavedShop),
    userId: 'userA',
    expectedStatus: 200,
  });

  const invalidSavedShop = {
    shopName: 'Sharma Kirana Store',
    updatedAt: stringField('not a timestamp'),
  };
  await assertRule({
    description: '12.2 Saved shop with invalid updatedAt rejected',
    method: 'PATCH',
    path: '/users/userA/savedShops/shop2',
    data: wrapDocument(invalidSavedShop),
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '12.3 Saved shop deletion allowed for owner',
    method: 'DELETE',
    path: '/users/userA/savedShops/shop1',
    userId: 'userA',
    expectedStatus: 200,
  });

  // 13. Cross-user access denial on subcollections (bills, expenses, savedShops)
  await assertRule({
    description: '13.1 User B denied read on User A bill',
    method: 'GET',
    path: '/users/userA/bills/PP-1001',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.2 User B denied write on User A bill',
    method: 'PATCH',
    path: '/users/userA/bills/PP-1001',
    data: wrapDocument(validBill),
    userId: 'userB',
    expectedStatus: 403,
  });

  const validExpense = {
    title: 'Transport',
    category: 'Transport',
    amount: 150.0,
    createdAt: timestampField(),
  };
  await assertRule({
    description: '13.3 User A can create valid expense',
    method: 'PATCH',
    path: '/users/userA/expenses/exp1',
    data: wrapDocument(validExpense),
    userId: 'userA',
    expectedStatus: 200,
  });

  await assertRule({
    description: '13.3a Owner cannot update an existing expense',
    method: 'PATCH',
    path: '/users/userA/expenses/exp1',
    data: wrapDocument({
      title: 'Transport',
      category: 'Transport',
      amount: 999.0,
      createdAt: validExpense.createdAt,
    }),
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.3b Owner cannot delete an expense',
    method: 'DELETE',
    path: '/users/userA/expenses/exp1',
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.4 User B denied read on User A expense',
    method: 'GET',
    path: '/users/userA/expenses/exp1',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.5 User B denied write on User A expense',
    method: 'PATCH',
    path: '/users/userA/expenses/exp1',
    data: wrapDocument(validExpense),
    userId: 'userB',
    expectedStatus: 403,
  });

  const validHouseholdExpense = {
    id: 'home-exp1',
    title: 'Vegetables',
    category: 'Vegetables',
    amount: 250.0,
    createdAt: timestampField(),
    source: 'voice',
  };
  await assertRule({
    description: '13.6 User A can create a valid household expense',
    method: 'PATCH',
    path: '/users/userA/householdExpenses/home-exp1',
    data: wrapDocument(validHouseholdExpense),
    userId: 'userA',
    expectedStatus: 200,
  });

  await assertRule({
    description: '13.6a Household expense with zero amount is denied',
    method: 'PATCH',
    path: '/users/userA/householdExpenses/home-invalid',
    data: wrapDocument({
      ...validHouseholdExpense,
      id: 'home-invalid',
      amount: 0,
    }),
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6b Owner can read their household expense',
    method: 'GET',
    path: '/users/userA/householdExpenses/home-exp1',
    userId: 'userA',
    expectedStatus: 200,
  });

  await assertRule({
    description: '13.6c Owner can list their household expenses',
    method: 'GET',
    path: '/users/userA/householdExpenses',
    userId: 'userA',
    expectedStatus: 200,
  });

  await assertRule({
    description: '13.6d Another user cannot read a household expense',
    method: 'GET',
    path: '/users/userA/householdExpenses/home-exp1',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6e Another user cannot list household expenses',
    method: 'GET',
    path: '/users/userA/householdExpenses',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6f Unauthenticated user cannot read a household expense',
    method: 'GET',
    path: '/users/userA/householdExpenses/home-exp1',
    userId: null,
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6g Unauthenticated user cannot list household expenses',
    method: 'GET',
    path: '/users/userA/householdExpenses',
    userId: null,
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6h Owner cannot update a saved household expense',
    method: 'PATCH',
    path: '/users/userA/householdExpenses/home-exp1',
    data: wrapDocument({
      ...validHouseholdExpense,
      amount: 500.0,
    }),
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6i Owner cannot delete a saved household expense',
    method: 'DELETE',
    path: '/users/userA/householdExpenses/home-exp1',
    userId: 'userA',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.6 User B denied read on User A savedShop',
    method: 'GET',
    path: '/users/userA/savedShops/shop1',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.7 User B denied write on User A savedShop',
    method: 'PATCH',
    path: '/users/userA/savedShops/shop1',
    data: wrapDocument({ shopName: 'Shop' }),
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.8 User B denied delete on User A savedShop',
    method: 'DELETE',
    path: '/users/userA/savedShops/shop1',
    userId: 'userB',
    expectedStatus: 403,
  });

  await assertRule({
    description: '13.9 User B denied delete on User A profile',
    method: 'DELETE',
    path: '/users/userA',
    userId: 'userB',
    expectedStatus: 403,
  });

  console.log(`\n--- Test Results: ${passed} passed, ${failed} failed ---`);
  if (failed > 0) process.exit(1);
}

runTests();
