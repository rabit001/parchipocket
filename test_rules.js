const http = require('http');

const PORT = 8088;
const PROJECT_ID = process.env.FIRESTORE_EMULATOR_PROJECT_ID || 'demo-parchipocket-phase3';
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
