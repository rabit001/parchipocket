import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

const _projectId = 'demo-parchipocket-phase4';
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8088;
const _authPort = 9099;

late FirebaseApp _firebaseApp;
late FirebaseAuth _auth;
late FirebaseFirestore _firestore;
late FirestoreService _service;
late FirebaseApp _claimantApp;
late FirebaseAuth _claimantAuth;
late FirebaseFirestore _claimantFirestore;
late FirestoreService _claimantService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> signInSafely(FirebaseAuth auth) async {
    for (var i = 0; i < 3; i++) {
      try {
        await auth.signInAnonymously();
        return;
      } catch (_) {
        if (i == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  setUpAll(() async {
    if (!_projectId.startsWith('demo-') || _emulatorHost != '10.0.2.2') {
      throw StateError(
          'Integration tests must use the local demo Firebase Emulator project.');
    }

    try {
      _firebaseApp = Firebase.app('parchipocket-phase4-owner-tests');
    } catch (_) {
      _firebaseApp = await Firebase.initializeApp(
        name: 'parchipocket-phase4-owner-tests',
        options: const FirebaseOptions(
          apiKey: 'fake-emulator-api-key',
          appId: '1:123456789012:android:0123456789abcdef',
          messagingSenderId: '123456789012',
          projectId: _projectId,
        ),
      );
    }
    _auth = FirebaseAuth.instanceFor(app: _firebaseApp);
    await _auth.useAuthEmulator(_emulatorHost, _authPort);

    _firestore = FirebaseFirestore.instanceFor(app: _firebaseApp);
    _firestore.settings = const Settings(persistenceEnabled: false);
    _firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
    _service = FirestoreService(firestore: _firestore, auth: _auth);

    try {
      _claimantApp = Firebase.app('parchipocket-phase4-claimant-tests');
    } catch (_) {
      _claimantApp = await Firebase.initializeApp(
        name: 'parchipocket-phase4-claimant-tests',
        options: const FirebaseOptions(
          apiKey: 'fake-emulator-api-key',
          appId: '1:123456789012:android:0123456789abcdef',
          messagingSenderId: '123456789012',
          projectId: _projectId,
        ),
      );
    }
    _claimantAuth = FirebaseAuth.instanceFor(app: _claimantApp);
    await _claimantAuth.useAuthEmulator(_emulatorHost, _authPort);
    _claimantFirestore = FirebaseFirestore.instanceFor(app: _claimantApp);
    _claimantFirestore.settings = const Settings(persistenceEnabled: false);
    _claimantFirestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
    _claimantService =
        FirestoreService(firestore: _claimantFirestore, auth: _claimantAuth);

    // Warm up the emulator gRPC channels and transaction pipeline to prevent cold-start deadline-exceeded timeouts
    try {
      await signInSafely(_auth);
      final warmupRef = _firestore.collection('_warmup').doc('init');
      await warmupRef.set(<String, dynamic>{'ts': FieldValue.serverTimestamp()});
      await warmupRef.get();
      await warmupRef.delete();
      await _auth.signOut();
    } catch (_) {}
  });

  tearDownAll(() async {
    try {
      if (_auth.currentUser != null) await _auth.signOut();
    } catch (_) {}
    try {
      if (_claimantAuth.currentUser != null) await _claimantAuth.signOut();
    } catch (_) {}
    try {
      await _firebaseApp.delete();
    } catch (_) {}
    try {
      await _claimantApp.delete();
    } catch (_) {}
  });

  setUp(() async {
    await signInSafely(_auth);
    await signInSafely(_claimantAuth);
  });

  tearDown(() async {
    if (_auth.currentUser != null) await _auth.signOut();
    if (_claimantAuth.currentUser != null) await _claimantAuth.signOut();
  });

  testWidgets(
      'FirestoreService creates bills under matching document IDs and owner can read/update',
      (tester) async {
    final bill = _newBill();

    await _service.createBill(bill);

    final reference = _billReference(_auth.currentUser!.uid, bill.id);
    final snapshot = await reference.get();
    expect(snapshot.exists, isTrue);
    expect(reference.id, bill.id);
    expect(snapshot.data()!['id'], bill.id);
    expect(snapshot.data()!['store'], bill.store);

    await _service.saveBill(_copyBill(bill, isSaved: true));
    expect((await reference.get()).data()!['isSaved'], isTrue);
  });

  testWidgets(
      'identical create retry is idempotent and conflicting ID cannot overwrite',
      (tester) async {
    final bill = _newBill();
    final reference = _billReference(_auth.currentUser!.uid, bill.id);

    await _service.createBill(bill);
    final original = (await reference.get()).data()!;
    await _service.createBill(bill);

    final bills = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('bills')
        .get();
    expect(bills.docs, hasLength(1));

    final conflictingBill = DemoBill(
      id: bill.id,
      store: 'Different Store',
      items: <BillLine>[
        BillLine(name: 'Changed item', quantity: 1, unitPrice: 999)
      ],
      createdAt: bill.createdAt,
      paymentMode: bill.paymentMode,
      customerPhone: bill.customerPhone,
      isUdhaar: bill.isUdhaar,
      isSettled: bill.isSettled,
      isSaved: bill.isSaved,
    );
    await expectLater(
      _service.createBill(conflictingBill),
      throwsA(isA<BillIdCollisionException>()),
    );
    expect((await reference.get()).data(), equals(original));
  });

  testWidgets('saveBill cannot recreate a missing document', (tester) async {
    final missingBill = _newBill(id: 'missing-bill-document');
    final reference = _billReference(_auth.currentUser!.uid, missingBill.id);

    await expectLater(
      _service.saveBill(_copyBill(missingBill, isSaved: true)),
      throwsA(isA<FirebaseException>()),
    );
    expect((await reference.get()).exists, isFalse);
  });

  testWidgets('another authenticated user cannot read or modify the owner bill',
      (tester) async {
    final ownerUid = _auth.currentUser!.uid;
    final bill = _newBill();
    await _service.createBill(bill);
    final ownerBill = _billReference(ownerUid, bill.id);

    await _auth.signOut();
    await _auth.signInAnonymously();
    expect(_auth.currentUser!.uid, isNot(ownerUid));

    await expectLater(
      ownerBill.get(),
      throwsA(isA<FirebaseException>()
          .having((error) => error.code, 'code', 'permission-denied')),
    );
    await expectLater(
      ownerBill.update(<String, Object>{'isSaved': true}),
      throwsA(isA<FirebaseException>()
          .having((error) => error.code, 'code', 'permission-denied')),
    );
  });

  testWidgets(
      'bill IDs remain unique across FirestoreService and AppState instances',
      (tester) async {
    final anotherService = FirestoreService(firestore: _firestore, auth: _auth);
    final ids = <String>{
      _service.newBillId(),
      _service.newBillId(),
      anotherService.newBillId(),
      FirestoreService(firestore: _claimantFirestore, auth: _claimantAuth)
          .newBillId(),
    };
    expect(ids, hasLength(4));
  });

  testWidgets(
      'owner issues digest-only code; customer claims a minimized copy idempotently',
      (tester) async {
    await _saveRoleProfile(_service, UserRole.shopOwner);
    expect(
        (await _service.loadUserProfile())?['role'], UserRole.shopOwner.name);
    final bill = _newBill(isUdhaar: true, customerPhone: '+919999999999');
    await _service.createBill(bill);
    expect(
        (await _billReference(_auth.currentUser!.uid, bill.id).get())
            .data()?['id'],
        bill.id);

    final rawCode = _service.newReceiptClaimCode();
    expect(rawCode, matches(RegExp(r'^[0-9a-f]{32}$')));
    await _service.createReceiptClaim(bill, rawCode: rawCode);
    final digest = sha256.convert(rawCode.codeUnits).toString();
    final claimRef = _firestore.collection('receiptClaims').doc(digest);
    final originalExpiry = (await claimRef.get()).data()!['expiresAt'];
    // Replaying the owner operation with the same raw code preserves the
    // original expiry; retries never renew the bearer code.
    await _service.createReceiptClaim(bill, rawCode: rawCode);
    await _service.createReceiptClaim(bill, rawCode: rawCode);
    final conflictingBill = _newBill();
    await _service.createBill(conflictingBill);
    final differentReceipt = DemoBill(
      id: conflictingBill.id,
      store: 'Different Shop',
      items: conflictingBill.items,
      createdAt: conflictingBill.createdAt,
      paymentMode: conflictingBill.paymentMode,
    );
    await expectLater(
      _service.createReceiptClaim(differentReceipt, rawCode: rawCode),
      throwsA(isA<ReceiptClaimException>()),
    );
    final claim = (await claimRef.get()).data()!;
    expect(claim['status'], 'open');
    expect(claim['expiresAt'], originalExpiry);
    expect(claim['sourceBillId'], bill.id);
    expect(claim.containsKey(rawCode), isFalse);
    final snapshot = claim['receipt'] as Map<String, dynamic>;
    expect(snapshot.keys.toSet(),
        {'id', 'store', 'items', 'createdAt', 'paymentMode'});

    await _saveRoleProfile(_claimantService, UserRole.customer);
    final claimed = await _claimantService.claimReceipt(rawCode);
    expect(claimed.sourceBillId, bill.id);
    expect(claimed.bill.id, bill.id);
    expect(claimed.bill.customerPhone, isEmpty);
    expect(claimed.bill.isUdhaar, isFalse);

    final copyRef = _claimantFirestore
        .collection('users')
        .doc(_claimantAuth.currentUser!.uid)
        .collection('claimedReceipts')
        .doc(_auth.currentUser!.uid)
        .collection('bills')
        .doc(bill.id);
    final copy = (await copyRef.get()).data()!;
    expect(copy['receipt']['id'], copyRef.id);
    expect(copy.containsKey('customerPhone'), isFalse);
    expect(copy.containsKey('isSettled'), isFalse);
    expect(copy.containsKey('isUdhaar'), isFalse);

    final retry = await _claimantService.claimReceipt(rawCode);
    expect(retry.sourceBillId, bill.id);
    final index = await _claimantFirestore
        .collection('users')
        .doc(_claimantAuth.currentUser!.uid)
        .collection('claimedReceiptsIndex')
        .get();
    expect(index.docs, hasLength(1));
    final ownerClaim = (await claimRef.get()).data()!;
    expect(ownerClaim['status'], 'claimed');
    expect(ownerClaim['claimedBy'], _claimantAuth.currentUser!.uid);
    final claimantClaim =
        await _claimantFirestore.collection('receiptClaims').doc(digest).get();
    expect(claimantClaim.data()?['claimedBy'], _claimantAuth.currentUser!.uid);

    final ownerBills = await _service.loadBills();
    expect(ownerBills, hasLength(2));
    expect(
      ownerBills.map((ownerBill) => ownerBill.id),
      containsAll(<String>[bill.id, conflictingBill.id]),
    );

    // An unrelated authenticated customer must not read a consumed token,
    // even when they know its SHA-256 document ID.
    await _auth.signOut();
    await _auth.signInAnonymously();
    await _saveRoleProfile(_service, UserRole.customer);
    await expectLater(
      _firestore.collection('receiptClaims').doc(digest).get(),
      throwsA(isA<FirebaseException>().having(
        (error) => error.code,
        'code',
        'permission-denied',
      )),
    );
  });

  testWidgets('concurrent customer claims allow one recipient only',
      (tester) async {
    await _saveRoleProfile(_service, UserRole.shopOwner);
    final ownerUidForClaim = _auth.currentUser!.uid;
    final bill = _newBill();
    await _service.createBill(bill);
    final code = _service.newReceiptClaimCode();
    await _service.createReceiptClaim(bill, rawCode: code);

    await _saveRoleProfile(_claimantService, UserRole.customer);
    await _auth.signOut();
    await _auth.signInAnonymously();
    await _saveRoleProfile(_service, UserRole.customer);

    final results = await Future.wait<Object>(<Future<Object>>[
      _service
          .claimReceipt(code)
          .then<Object>((value) => value, onError: (Object error) => error),
      _claimantService
          .claimReceipt(code)
          .then<Object>((value) => value, onError: (Object error) => error),
    ]);
    final successes = results.whereType<ClaimedReceipt>().toList();
    expect(successes, hasLength(1));
    expect(results.where((result) => result is! ClaimedReceipt), hasLength(1));
    final primaryCopy = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('claimedReceipts')
        .doc(ownerUidForClaim)
        .collection('bills')
        .doc(bill.id)
        .get();
    final secondaryCopy = await _claimantFirestore
        .collection('users')
        .doc(_claimantAuth.currentUser!.uid)
        .collection('claimedReceipts')
        .doc(ownerUidForClaim)
        .collection('bills')
        .doc(bill.id)
        .get();
    expect(primaryCopy.exists ^ secondaryCopy.exists, isTrue);
    final winnerFirestore =
        primaryCopy.exists ? _firestore : _claimantFirestore;
    final claim = (await winnerFirestore
            .collection('receiptClaims')
            .doc(sha256.convert(code.codeUnits).toString())
            .get())
        .data()!;
    expect(claim['status'], 'claimed');
  });

  testWidgets('expired claim cannot be consumed by Firestore rules',
      (tester) async {
    await _saveRoleProfile(_service, UserRole.shopOwner);
    final bill = _newBill();
    await _service.createBill(bill);
    final code = _service.newReceiptClaimCode();
    await _service.createReceiptClaim(
      bill,
      rawCode: code,
      expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 10)),
    );
    // `testWidgets` runs inside fake async. Use runAsync so wall-clock time
    // advances and the emulator's server-side expiresAt check can really expire.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 11)),
    );
    await _saveRoleProfile(_claimantService, UserRole.customer);
    await expectLater(
      _claimantService.claimReceipt(code),
      throwsA(isA<ReceiptClaimException>()),
    );
  });

  testWidgets('invalid claim does not create customer receipts',
      (tester) async {
    await _saveRoleProfile(_claimantService, UserRole.customer);
    await expectLater(
      _claimantService.claimReceipt(_claimantService.newReceiptClaimCode()),
      throwsA(isA<ReceiptClaimException>()),
    );
    final index = await _claimantFirestore
        .collection('users')
        .doc(_claimantAuth.currentUser!.uid)
        .collection('claimedReceiptsIndex')
        .get();
    expect(index.docs, isEmpty);
  });

  testWidgets(
    'expense retry is idempotent and conflicting ID reuse cannot overwrite',
    (tester) async {
      final ownerUid = _auth.currentUser!.uid;
      final expenseId = _service.newExpenseId();
      final expense = DemoExpense(
        id: expenseId,
        title: 'Integration transport',
        category: 'Transport',
        amount: 42,
        createdAt: DateTime.utc(2026, 10, 26, 10),
      );

      await _service.addExpense(expense);
      await _service.addExpense(expense);

      final expenseRef = _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('expenses')
          .doc(expenseId);
      final saved = await expenseRef.get();
      expect(saved.exists, isTrue);
      expect(saved.data()!['title'], 'Integration transport');

      await expectLater(
        _service.addExpense(
          DemoExpense(
            id: expenseId,
            title: 'Altered transport',
            category: 'Transport',
            amount: 999,
            createdAt: expense.createdAt,
          ),
        ),
        throwsA(isA<ExpenseIdCollisionException>()),
      );
      final unchanged = await expenseRef.get();
      expect(unchanged.data()!['title'], 'Integration transport');
      expect(unchanged.data()!['amount'], 42);
    },
  );

  testWidgets(
    'saved-shop IDs do not collide for names that sanitize to the same legacy ID',
    (tester) async {
      await _service.saveShop('A/B');
      await _service.saveShop('A_B');

      final shops = await _service.loadSavedShops();
      expect(shops, containsAll(<String>['A/B', 'A_B']));

      await _service.removeSavedShop('A/B');
      final afterRemoval = await _service.loadSavedShops();
      expect(afterRemoval, isNot(contains('A/B')));
      expect(afterRemoval, contains('A_B'));
    },
  );

  group('HouseholdExpense lifecycle in Firestore emulator', () {
    testWidgets(
      'addHouseholdExpense writes record with optional expenseDate and without isVoided',
      (tester) async {
        final ownerUid = _auth.currentUser!.uid;
        final expenseId = _service.newHouseholdExpenseId();
        final expenseDate = DateTime.utc(2026, 10, 20, 15, 30);
        final createdAt = DateTime.utc(2026, 10, 25, 12, 0);

        final expense = HouseholdExpense(
          id: expenseId,
          title: 'Sunflower Oil 1L',
          category: 'Groceries',
          amount: 145.50,
          createdAt: createdAt,
          source: 'manual',
          expenseDate: expenseDate,
        );

        await _service.addHouseholdExpense(expense);

        final docRef = _householdExpenseReference(ownerUid, expenseId);
        final snapshot = await docRef.get();
        expect(snapshot.exists, isTrue);

        final data = snapshot.data()!;
        expect(data['id'], expenseId);
        expect(data['title'], 'Sunflower Oil 1L');
        expect(data['category'], 'Groceries');
        expect(data['amount'], 145.50);
        expect(data['source'], 'manual');
        expect(data['createdAt'], isA<Timestamp>());
        expect((data['createdAt'] as Timestamp).toDate().toUtc(), createdAt);
        expect(data['expenseDate'], isA<Timestamp>());
        expect((data['expenseDate'] as Timestamp).toDate().toUtc(), expenseDate);
        expect(data.containsKey('isVoided'), isFalse);
        expect(data.containsKey('updatedAt'), isFalse);
        expect(data.containsKey('history'), isFalse);

        // Idempotent retry succeeds
        await _service.addHouseholdExpense(expense);

        // Conflict fails
        await expectLater(
          _service.addHouseholdExpense(
            expense.copyWith(title: 'Conflicting Oil'),
          ),
          throwsA(isA<ExpenseIdCollisionException>()),
        );
      },
    );

    testWidgets(
      'updateHouseholdExpense executes first and second corrections with strict audit history',
      (tester) async {
        final ownerUid = _auth.currentUser!.uid;
        final expenseId = _service.newHouseholdExpenseId();
        final initialExpenseDate = DateTime.utc(2026, 10, 21, 10, 0);
        final createdAt = DateTime.utc(2026, 10, 26, 8, 0);

        final initialExpense = HouseholdExpense(
          id: expenseId,
          title: 'Basmati Rice 5kg',
          category: 'Groceries',
          amount: 350.0,
          createdAt: createdAt,
          expenseDate: initialExpenseDate,
        );
        await _service.addHouseholdExpense(initialExpense);

        // First correction: edit title and amount
        final correctedExpense1 = initialExpense.copyWith(
          title: 'Basmati Rice 10kg',
          amount: 680.0,
        );
        await _service.updateHouseholdExpense(correctedExpense1);

        final docRef = _householdExpenseReference(ownerUid, expenseId);
        final snap1 = await docRef.get();
        final data1 = snap1.data()!;

        expect(data1['title'], 'Basmati Rice 10kg');
        expect(data1['amount'], 680.0);
        expect(data1['updatedAt'], isA<Timestamp>());
        final firstUpdatedAt = data1['updatedAt'] as Timestamp;

        final history1 = (data1['history'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(history1.length, 1);
        expect(history1[0]['title'], 'Basmati Rice 5kg');
        expect(history1[0]['amount'], 350.0);
        expect(history1[0]['category'], 'Groceries');
        expect(history1[0]['expenseDate'], isA<Timestamp>());
        expect(history1[0].containsKey('modifiedAt'), isFalse);

        // Second correction: change category and date
        final updatedExpenseDate = DateTime.utc(2026, 10, 22, 11, 0);
        final correctedExpense2 = correctedExpense1.copyWith(
          category: 'Pantry',
          expenseDate: updatedExpenseDate,
        );
        await _service.updateHouseholdExpense(correctedExpense2);

        final snap2 = await docRef.get();
        final data2 = snap2.data()!;

        expect(data2['category'], 'Pantry');
        expect((data2['expenseDate'] as Timestamp).toDate().toUtc(), updatedExpenseDate);
        expect(data2['updatedAt'], isA<Timestamp>());

        final history2 = (data2['history'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(history2.length, 2);
        // First snapshot preserved
        expect(history2[0]['title'], 'Basmati Rice 5kg');
        expect(history2[0].containsKey('modifiedAt'), isFalse);
        // Second snapshot has previous values and modifiedAt == firstUpdatedAt
        expect(history2[1]['title'], 'Basmati Rice 10kg');
        expect(history2[1]['amount'], 680.0);
        expect(history2[1]['category'], 'Groceries');
        expect(history2[1]['modifiedAt'], firstUpdatedAt);
      },
    );

    testWidgets(
      'updateHouseholdExpense enforces history limit of 10 without truncation',
      (tester) async {
        final expenseId = _service.newHouseholdExpenseId();
        var current = HouseholdExpense(
          id: expenseId,
          title: 'Correction Step 0',
          category: 'Groceries',
          amount: 10.0,
          createdAt: DateTime.utc(2026, 10, 26, 10, 0),
        );
        await _service.addHouseholdExpense(current);

        // Perform 10 corrections (filling history to 10 entries)
        for (var i = 1; i <= 10; i++) {
          current = current.copyWith(
            title: 'Correction Step $i',
            amount: 10.0 + i,
          );
          await _service.updateHouseholdExpense(current);
        }

        // 11th correction must fail
        final eleventhCorrection = current.copyWith(
          title: 'Correction Step 11',
          amount: 99.0,
        );
        await expectLater(
          _service.updateHouseholdExpense(eleventhCorrection),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Maximum correction history limit of 10 reached'),
            ),
          ),
        );

        final ownerUid = _auth.currentUser!.uid;
        final snap = await _householdExpenseReference(ownerUid, expenseId).get();
        final history = snap.data()!['history'] as List<dynamic>;
        expect(history.length, 10);
        expect(snap.data()!['title'], 'Correction Step 10');
      },
    );

    testWidgets(
      'voidHouseholdExpense marks expense voided, records voidReason, and prevents further edit/void',
      (tester) async {
        final ownerUid = _auth.currentUser!.uid;
        final expenseId = _service.newHouseholdExpenseId();
        final expense = HouseholdExpense(
          id: expenseId,
          title: 'Wrong Bill Entry',
          category: 'Utilities',
          amount: 550.0,
          createdAt: DateTime.utc(2026, 10, 26, 12, 0),
        );
        await _service.addHouseholdExpense(expense);

        // Reason length validation
        final tooLongReason = 'A' * 201;
        expect(
          () => _service.voidHouseholdExpense(expenseId, reason: tooLongReason),
          throwsA(isA<ArgumentError>()),
        );

        // Void the expense
        await _service.voidHouseholdExpense(
          expenseId,
          reason: 'Billed twice by electricity provider',
        );

        final docRef = _householdExpenseReference(ownerUid, expenseId);
        final snap = await docRef.get();
        final data = snap.data()!;

        expect(data['isVoided'], isTrue);
        expect(data['voidedAt'], isA<Timestamp>());
        expect(data['voidReason'], 'Billed twice by electricity provider');
        expect(data['title'], 'Wrong Bill Entry');
        expect(data['amount'], 550.0);

        // Repeated void fails
        await expectLater(
          _service.voidHouseholdExpense(expenseId),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Expense is already voided'),
            ),
          ),
        );

        // Modifying voided expense fails
        await expectLater(
          _service.updateHouseholdExpense(
            expense.copyWith(title: 'Trying to resurrect'),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Cannot update a voided household expense'),
            ),
          ),
        );
      },
    );

    testWidgets(
      'another authenticated user cannot read, update or delete owner household expense',
      (tester) async {
        final ownerUid = _auth.currentUser!.uid;
        final expenseId = _service.newHouseholdExpenseId();
        final expense = HouseholdExpense(
          id: expenseId,
          title: 'Owner Private Expense',
          category: 'Personal',
          amount: 200.0,
          createdAt: DateTime.utc(2026, 10, 26, 14, 0),
        );
        await _service.addHouseholdExpense(expense);
        final ownerExpenseRef = _householdExpenseReference(ownerUid, expenseId);

        // Sign in as a different user
        await _auth.signOut();
        await _auth.signInAnonymously();
        expect(_auth.currentUser!.uid, isNot(ownerUid));

        // Attempting to read owner's expense is denied
        await expectLater(
          ownerExpenseRef.get(),
          throwsA(isA<FirebaseException>()
              .having((error) => error.code, 'code', 'permission-denied')),
        );

        // Attempting to write/update owner's expense is denied
        await expectLater(
          ownerExpenseRef.update(<String, Object>{'title': 'Claimant Tampering'}),
          throwsA(isA<FirebaseException>()
              .having((error) => error.code, 'code', 'permission-denied')),
        );

        // Attempting to delete owner's expense is denied
        await expectLater(
          ownerExpenseRef.delete(),
          throwsA(isA<FirebaseException>()
              .having((error) => error.code, 'code', 'permission-denied')),
        );
      },
    );

    testWidgets(
      'loadHouseholdExpensesPage deserializes modern corrected and voided expenses',
      (tester) async {
        final expenseId = _service.newHouseholdExpenseId();
        final customDate = DateTime.utc(2026, 10, 18, 9, 0);
        final initialExpense = HouseholdExpense(
          id: expenseId,
          title: 'Milk Pack 1L',
          category: 'Groceries',
          amount: 60.0,
          createdAt: DateTime.utc(2026, 10, 26, 15, 0),
          expenseDate: customDate,
        );
        await _service.addHouseholdExpense(initialExpense);

        await _service.updateHouseholdExpense(
          initialExpense.copyWith(title: 'Milk Pack 2L', amount: 118.0),
        );

        await _service.voidHouseholdExpense(
          expenseId,
          reason: 'Spoiled on arrival',
        );

        final page = await _service.loadHouseholdExpensesPage(limit: 50);
        final loaded = page.items.firstWhere((e) => e.id == expenseId);

        expect(loaded.title, 'Milk Pack 2L');
        expect(loaded.amount, 118.0);
        expect(loaded.isVoided, isTrue);
        expect(loaded.voidReason, 'Spoiled on arrival');
        expect(loaded.voidedAt, isNotNull);
        expect(loaded.updatedAt, isNotNull);
        expect(loaded.history.length, 1);
        expect(loaded.history[0].title, 'Milk Pack 1L');
        expect(loaded.history[0].amount, 60.0);
        expect(loaded.effectiveDate.toUtc(), customDate);
      },
    );
  });
}

Future<void> _saveRoleProfile(FirestoreService service, UserRole role) =>
    service.saveUserProfile(
      role: role,
      name: role == UserRole.shopOwner ? 'Emulator Shop' : 'Emulator Customer',
      email: '',
      city: 'Test City',
      shopName: 'Emulator Shop',
      shopCategory: 'Kirana',
      shopAddress: 'Test Address',
      vendorName: 'Test Vendor',
      vendorCategory: 'Tea',
    );

DemoBill _newBill(
        {String? id, String customerPhone = '', bool isUdhaar = false}) =>
    DemoBill(
      id: id ?? _service.newBillId(),
      store: 'Emulator Test Shop',
      items: <BillLine>[BillLine(name: 'Tea', quantity: 2, unitPrice: 10)],
      createdAt: DateTime.utc(2026, 10, 23, 12),
      paymentMode: 'Cash',
      customerPhone: customerPhone,
      isUdhaar: isUdhaar,
      isSettled: false,
      isSaved: false,
    );

DemoBill _copyBill(DemoBill bill, {required bool isSaved}) => DemoBill(
      id: bill.id,
      store: bill.store,
      items: bill.items,
      createdAt: bill.createdAt,
      paymentMode: bill.paymentMode,
      customerPhone: bill.customerPhone,
      isUdhaar: bill.isUdhaar,
      isSettled: bill.isSettled,
      isSaved: isSaved,
    );

DocumentReference<Map<String, dynamic>> _billReference(String uid, String id) =>
    _firestore.collection('users').doc(uid).collection('bills').doc(id);


DocumentReference<Map<String, dynamic>> _householdExpenseReference(
        String uid, String id) =>
    _firestore
        .collection('users')
        .doc(uid)
        .collection('householdExpenses')
        .doc(id);
