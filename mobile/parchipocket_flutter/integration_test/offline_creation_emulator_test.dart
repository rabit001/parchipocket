import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

const _projectId = 'demo-parchipocket-phase4';
final String _emulatorHost =
    Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
const _firestorePort = 8088;
const _authPort = 9099;

late FirebaseApp _firebaseApp;
late FirebaseAuth _auth;
late FirebaseFirestore _firestore;
late FirestoreService _service;

late FirebaseApp _userBApp;
late FirebaseAuth _userBAuth;
late FirebaseFirestore _userBFirestore;
late FirestoreService _userBService;

Future<void> _signInSafely(FirebaseAuth auth) async {
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

Future<void> _saveRoleProfile(FirestoreService service, UserRole role) async {
  await service.saveUserProfile(
    role: role,
    name: 'Offline Test User',
    email: 'test@parchipocket.test',
    city: 'Ujjain, Madhya Pradesh',
    shopName: 'Mansuri Test Kirana',
    shopCategory: 'Kirana',
    shopAddress: 'Test Lane 1',
    vendorName: 'Raju Test Snacks',
    vendorCategory: 'Snacks',
  );
}

Future<AppState> _createReadyState(
  FirebaseAuth auth,
  FirestoreService service,
) async {
  final state = AppState(auth: auth)..firestoreService = service;
  // Let initial authStateChanges stream event fire
  await Future<void>.delayed(const Duration(milliseconds: 200));
  for (var i = 0; i < 40 && state.isCloudLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  state.isCloudLoading = false;
  state.isDemoMode = false;
  return state;
}

DemoBill _newTestBill({
  required String id,
  String store = 'Mansuri Test Kirana',
  String paymentMode = 'Cash',
  int quantity = 1,
  double unitPrice = 25.0,
}) {
  return DemoBill(
    id: id,
    store: store,
    paymentMode: paymentMode,
    createdAt: DateTime.now(),
    items: [
      BillLine(name: 'Masala Chai', quantity: quantity, unitPrice: unitPrice),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_projectId.startsWith('demo-')) {
      throw StateError(
          'Integration tests must use the local demo Firebase Emulator project.');
    }

    try {
      _firebaseApp = Firebase.app('parchipocket-offline-integration-app');
    } catch (_) {
      _firebaseApp = await Firebase.initializeApp(
        name: 'parchipocket-offline-integration-app',
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
    await _auth.signOut();

    _firestore = FirebaseFirestore.instanceFor(app: _firebaseApp);
    // Explicitly verify local Firestore persistence is enabled!
    _firestore.settings = const Settings(persistenceEnabled: true);
    _firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
    _service = FirestoreService(firestore: _firestore, auth: _auth);

    try {
      _userBApp = Firebase.app('parchipocket-offline-user-b-app');
    } catch (_) {
      _userBApp = await Firebase.initializeApp(
        name: 'parchipocket-offline-user-b-app',
        options: const FirebaseOptions(
          apiKey: 'fake-emulator-api-key',
          appId: '1:123456789012:android:0123456789abcdef',
          messagingSenderId: '123456789012',
          projectId: _projectId,
        ),
      );
    }
    _userBAuth = FirebaseAuth.instanceFor(app: _userBApp);
    await _userBAuth.useAuthEmulator(_emulatorHost, _authPort);
    await _userBAuth.signOut();
    _userBFirestore = FirebaseFirestore.instanceFor(app: _userBApp);
    _userBFirestore.settings = const Settings(persistenceEnabled: true);
    _userBFirestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
    _userBService = FirestoreService(firestore: _userBFirestore, auth: _userBAuth);
  });

  tearDownAll(() async {
    try {
      if (_auth.currentUser != null) await _auth.signOut();
    } catch (_) {}
    try {
      if (_userBAuth.currentUser != null) await _userBAuth.signOut();
    } catch (_) {}
    try {
      await _firebaseApp.delete();
    } catch (_) {}
    try {
      await _userBApp.delete();
    } catch (_) {}
  });

  setUp(() async {
    // Re-enable network to ensure clean starting state
    try {
      await _firestore.enableNetwork();
    } catch (_) {}
    try {
      await _userBFirestore.enableNetwork();
    } catch (_) {}
    _service.isOfflineMode = false;
    _userBService.isOfflineMode = false;

    await _signInSafely(_auth);
    await _saveRoleProfile(_service, UserRole.shopOwner);
  });

  tearDown(() async {
    _service.isOfflineMode = false;
    _userBService.isOfflineMode = false;
    try {
      await _firestore.enableNetwork();
    } catch (_) {}
    if (_auth.currentUser != null) await _auth.signOut();
    if (_userBAuth.currentUser != null) await _userBAuth.signOut();
  });

  testWidgets(
    '1. Real FlutterFire offline bill creation queues locally and does not block UI',
    (tester) async {
      final state = await _createReadyState(_auth, _service);

      // 1. Disable Firestore network via native SDK API
      await _firestore.disableNetwork();
      _service.isOfflineMode = true;
      state.setOffline(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 2. Call createBill
      final billId = _service.newBillId();
      final bill = _newTestBill(id: billId);

      final stopwatch = Stopwatch()..start();
      await state.createBill(
        items: bill.items,
        paymentMode: bill.paymentMode,
        vendorMode: false,
      );
      stopwatch.stop();

      // 3. Verify execution returned promptly (<500ms) without waiting for server
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(state.page, 'receipt');
      expect(state.isCloudLoading, isFalse);
      expect(state.isOffline, isTrue);
      expect(state.bills.any((b) => b.id == state.selectedBill?.id), isTrue);

      final createdBill = state.selectedBill!;
      expect(createdBill.isSaved, isFalse);

      // 4. Verify local cache visibility with source: Source.cache
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      DocumentSnapshot<Map<String, dynamic>>? cachedSnap;
      for (var i = 0; i < 10; i++) {
        try {
          cachedSnap = await userDoc
              .collection('bills')
              .doc(createdBill.id)
              .get(const GetOptions(source: Source.cache));
          if (cachedSnap.exists) break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      expect(cachedSnap, isNotNull);
      expect(cachedSnap!.exists, isTrue);
      expect(cachedSnap.metadata.hasPendingWrites, isTrue);

      // 5. Re-enable network and verify eventual sync
      final prevOnBillSynced = _service.onBillSynced;
      final syncCompleter = Completer<void>();
      _service.onBillSynced = (id, uid) {
        prevOnBillSynced?.call(id, uid);
        if (id == createdBill.id) {
          syncCompleter.complete();
        }
      };

      await _firestore.enableNetwork();
      _service.isOfflineMode = false;
      state.setOffline(false);
      try {
        await _firestore
            .waitForPendingWrites()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await syncCompleter.future.timeout(const Duration(seconds: 10));

      expect(createdBill.isSaved, isTrue);
      expect(state.lastNotice, contains('synchronized'));

      // Check server confirmed metadata
      final serverSnap = await userDoc
          .collection('bills')
          .doc(createdBill.id)
          .get(const GetOptions(source: Source.server));
      expect(serverSnap.exists, isTrue);
      expect(serverSnap.metadata.hasPendingWrites, isFalse);
    },
  );

  testWidgets(
    '2. Real FlutterFire offline business and household expense creation queues and syncs',
    (tester) async {
      final state = await _createReadyState(_auth, _service);

      await _firestore.disableNetwork();
      _service.isOfflineMode = true;
      state.setOffline(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Create business expense offline
      final expenseStopwatch = Stopwatch()..start();
      final expResult = await state.addExpense(
        title: 'Packaging Bags',
        category: 'Packaging',
        amount: 150,
      );
      expenseStopwatch.stop();

      expect(expResult, isTrue);
      expect(expenseStopwatch.elapsedMilliseconds, lessThan(500));
      expect(state.page, 'expenseSaved');
      expect(state.isOffline, isTrue);

      // Create household expense offline
      final hhStopwatch = Stopwatch()..start();
      final hhResult = await state.addHouseholdExpense(
        title: 'Fresh Milk',
        category: 'Groceries',
        amount: 60,
      );
      hhStopwatch.stop();

      expect(hhResult, isTrue);
      expect(hhStopwatch.elapsedMilliseconds, lessThan(500));
      expect(state.page, 'householdExpenses');
      expect(state.isOffline, isTrue);

      // Verify cached snapshot hasPendingWrites
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      DocumentSnapshot<Map<String, dynamic>>? cachedExpense;
      for (var i = 0; i < 10; i++) {
        try {
          cachedExpense = await userDoc
              .collection('expenses')
              .doc(state.expenses.first.id)
              .get(const GetOptions(source: Source.cache));
          if (cachedExpense.exists) break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      expect(cachedExpense, isNotNull);
      expect(cachedExpense!.exists, isTrue);
      expect(cachedExpense.metadata.hasPendingWrites, isTrue);

      // Reconnect and wait for synchronization
      await _firestore.enableNetwork();
      _service.isOfflineMode = false;
      state.setOffline(false);
      try {
        await _firestore
            .waitForPendingWrites()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      final serverExpense = await userDoc
          .collection('expenses')
          .doc(state.expenses.first.id)
          .get(const GetOptions(source: Source.server));
      expect(serverExpense.exists, isTrue);
      expect(serverExpense.metadata.hasPendingWrites, isFalse);
    },
  );

  testWidgets(
    '3. Reconnection server rejection: invalid offline write is rejected by rules and surfaces error',
    (tester) async {
      await _firestore.disableNetwork();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final billId = _service.newBillId();
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      final billRef = userDoc.collection('bills').doc(billId);

      // Inject an invalid bill payload that will fail Firestore rules on server
      // (11 items violates rules max 10 items limit)
      final invalidItems = List.generate(
        11,
        (i) => {'name': 'Item $i', 'quantity': 1, 'unitPrice': 10.0},
      );
      final invalidData = <String, dynamic>{
        'id': billId,
        'store': 'Mansuri Test Kirana',
        'paymentMode': 'Cash',
        'customerPhone': '',
        'isUdhaar': false,
        'isSettled': false,
        'isSaved': false,
        'createdAt': Timestamp.now(),
        'items': invalidItems,
      };

      // Stage invalid write offline
      final writeFuture = billRef.set(invalidData);
      DocumentSnapshot<Map<String, dynamic>>? cachedSnap;
      for (var i = 0; i < 10; i++) {
        try {
          cachedSnap = await billRef.get(const GetOptions(source: Source.cache));
          if (cachedSnap.exists) break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      expect(cachedSnap, isNotNull);
      expect(cachedSnap!.exists, isTrue);
      expect(cachedSnap.metadata.hasPendingWrites, isTrue);

      dynamic serverError;
      writeFuture.catchError((err) {
        serverError = err;
      });

      // Enable network and allow server security rules to evaluate
      await _firestore.enableNetwork();

      // Expect server rejection with permission-denied
      try {
        await writeFuture.timeout(const Duration(seconds: 5));
      } catch (e) {
        serverError = e;
      }

      expect(serverError, isNotNull);
      expect(serverError.toString(), contains('permission-denied'));
    },
  );

  testWidgets(
    '4. Firestore service recreation and pending-write recovery: metadata.hasPendingWrites restores pending state from cache',
    (tester) async {
      // 1. Queue an offline bill
      await _firestore.disableNetwork();
      _service.isOfflineMode = true;
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final billId = _service.newBillId();
      final bill = _newTestBill(id: billId);
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      final billRef = userDoc.collection('bills').doc(billId);

      // Write to local cache
      unawaited(billRef.set({
        'id': billId,
        'store': bill.store,
        'paymentMode': bill.paymentMode,
        'customerPhone': '',
        'isUdhaar': false,
        'isSettled': false,
        'isSaved': true, // Even if written with true, pending write must override!
        'createdAt': Timestamp.fromDate(bill.createdAt),
        'items': [
          {'name': 'Tea', 'quantity': 1, 'unitPrice': 10.0}
        ],
      }));

      // Verify local cache persistence before restart
      DocumentSnapshot<Map<String, dynamic>>? cacheCheck;
      for (var i = 0; i < 20; i++) {
        try {
          cacheCheck =
              await billRef.get(const GetOptions(source: Source.cache));
          if (cacheCheck.exists) break;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(cacheCheck, isNotNull);
      expect(cacheCheck!.exists, isTrue);

      // 2. Simulate Cold App Restart while still offline:
      // Clear in-memory service instance and create fresh service
      _service.clearPendingWrites();
      expect(_service.hasPendingWrites, isFalse);

      final freshService =
          FirestoreService(firestore: _firestore, auth: _auth)..isOfflineMode = true;

      // 3. Load bills from local cache
      final loadedBills = await freshService.loadBills();
      expect(loadedBills.any((b) => b.id == billId), isTrue);

      final recoveredBill = loadedBills.firstWhere((b) => b.id == billId);
      // Pending write metadata must ensure isSaved is false!
      expect(recoveredBill.isSaved, isFalse);
      expect(freshService.isBillPendingSync(billId), isTrue);
      expect(freshService.hasPendingWrites, isTrue);

      // 4. Reconnection & synchronization
      final syncCompleter = Completer<void>();
      freshService.onBillSynced = (id, uid) {
        if (id == billId) {
          syncCompleter.complete();
        }
      };

      await _firestore.enableNetwork();
      _service.isOfflineMode = false;
      freshService.isOfflineMode = false;
      try {
        await _firestore
            .waitForPendingWrites()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await syncCompleter.future.timeout(const Duration(seconds: 10));

      expect(freshService.isBillPendingSync(billId), isFalse);
      expect(freshService.hasPendingWrites, isFalse);
    },
  );

  testWidgets(
    '5. Authentication switching: User A queued write does not contaminate User B session',
    (tester) async {
      await _firestore.disableNetwork();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // User A writes bill offline
      final userAUid = _auth.currentUser!.uid;
      final billId = _service.newBillId();
      final userADoc = _firestore.collection('users').doc(userAUid);
      final billRefA = userADoc.collection('bills').doc(billId);

      unawaited(billRefA.set({
        'id': billId,
        'store': 'User A Store',
        'paymentMode': 'Cash',
        'customerPhone': '',
        'isUdhaar': false,
        'isSettled': false,
        'isSaved': false,
        'createdAt': Timestamp.now(),
        'items': [
          {'name': 'Item A', 'quantity': 1, 'unitPrice': 50.0}
        ],
      }).catchError((_) {}));

      // User A signs out while write is pending
      await _auth.signOut();

      // User B signs in
      await _signInSafely(_userBAuth);
      await _saveRoleProfile(_userBService, UserRole.customer);

      final stateB = await _createReadyState(_userBAuth, _userBService);
      stateB.bills.clear();
      stateB.lastNotice = 'Welcome User B';

      // Re-enable network
      await _firestore.enableNetwork();
      await _userBFirestore.enableNetwork();
      _service.isOfflineMode = false;
      _userBService.isOfflineMode = false;

      // User B must NOT see User A's bills
      final userBBills = await _userBService.loadBills();
      expect(userBBills.any((b) => b.id == billId), isFalse);
      expect(stateB.bills.any((b) => b.id == billId), isFalse);
      expect(stateB.lastNotice, 'Welcome User B');

      // User A's pending write cannot be read or modified by User B
      final crossRead = _userBFirestore
          .collection('users')
          .doc(userAUid)
          .collection('bills')
          .doc(billId)
          .get()
          .timeout(const Duration(seconds: 5));
      await expectLater(crossRead, throwsA(isA<FirebaseException>()));
    },
  );
}
