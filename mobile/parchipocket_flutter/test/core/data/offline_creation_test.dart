import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

class _MockUser extends Fake implements User {
  _MockUser({this.customUid = 'offline-test-user-123'});
  final String customUid;

  @override
  String get uid => customUid;
}

class _MockAuth extends Fake implements FirebaseAuth {
  _MockAuth({User? initialUser}) : user = initialUser ?? _MockUser();
  User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream.value(user);

  @override
  Future<void> signOut() async {
    user = null;
  }
}

class _MockOfflineFirestoreService extends FirestoreService {
  int _billCounter = 0;
  int _expenseCounter = 0;
  int _householdCounter = 0;

  int createBillCalls = 0;
  int addExpenseCalls = 0;
  int addHouseholdCalls = 0;
  int loadBillsCalls = 0;
  int loadExpensesCalls = 0;

  bool simulateOffline = false;
  bool failFirstWrite = false;
  bool throwCollisionOnExpense = false;
  bool throwCollisionOnHouseholdExpense = false;
  bool shouldThrowNetworkErrorOnLoad = false;
  List<DemoBill> cachedBills = [];
  List<DemoExpense> cachedExpenses = [];

  Completer<void>? pendingBillCompleter;
  Completer<void>? pendingExpenseCompleter;
  Completer<void>? pendingHouseholdCompleter;

  String callerUid = 'offline-test-user-123';

  @override
  String newBillId() => 'offline-bill-${++_billCounter}';

  @override
  String newExpenseId() => 'offline-expense-${++_expenseCounter}';

  @override
  String newHouseholdExpenseId() => 'offline-household-${++_householdCounter}';

  @override
  Future<void> createBill(DemoBill bill) async {
    createBillCalls++;
    if (failFirstWrite) {
      failFirstWrite = false;
      throw const SocketException('Connection failed');
    }
    if (simulateOffline) {
      lastOperationWasOffline = true;
      cachedBills.insert(0, bill);
      rawPendingBillWrites.add(bill.id);

      // Track pending write and attach background completion handlers
      final completer = pendingBillCompleter ?? Completer<void>();
      pendingBillCompleter = completer;

      // Simulate FirestoreService pending write set
      final writeFuture = completer.future;
      final writeUid = callerUid;
      writeFuture.then((_) {
        rawPendingBillWrites.remove(bill.id);
        onBillSynced?.call(bill.id, writeUid);
      }).catchError((err, st) {
        rawPendingBillWrites.remove(bill.id);
        onBillRejected?.call(bill.id, writeUid, err);
      });
      // Returns immediately without awaiting writeFuture!
      return;
    } else {
      lastOperationWasOffline = false;
      cachedBills.insert(0, bill);
    }
  }

  @override
  Future<void> addExpense(DemoExpense expense) async {
    addExpenseCalls++;
    if (throwCollisionOnExpense) {
      throw const ExpenseIdCollisionException('collided-expense-id');
    }
    if (failFirstWrite) {
      failFirstWrite = false;
      throw const SocketException('Connection failed');
    }
    if (simulateOffline) {
      lastOperationWasOffline = true;
      cachedExpenses.insert(0, expense);
      rawPendingExpenseWrites.add(expense.id);

      final completer = pendingExpenseCompleter ?? Completer<void>();
      pendingExpenseCompleter = completer;
      final writeFuture = completer.future;
      final writeUid = callerUid;
      writeFuture.then((_) {
        rawPendingExpenseWrites.remove(expense.id);
        onExpenseSynced?.call(expense.id, writeUid);
      }).catchError((err, st) {
        rawPendingExpenseWrites.remove(expense.id);
        onExpenseRejected?.call(expense.id, writeUid, err);
      });
      return;
    } else {
      lastOperationWasOffline = false;
      cachedExpenses.insert(0, expense);
    }
  }

  @override
  Future<void> addHouseholdExpense(HouseholdExpense expense) async {
    addHouseholdCalls++;
    if (throwCollisionOnHouseholdExpense) {
      throw const ExpenseIdCollisionException('collided-household-id');
    }
    if (failFirstWrite) {
      failFirstWrite = false;
      throw const SocketException('Connection failed');
    }
    if (simulateOffline) {
      lastOperationWasOffline = true;
      rawPendingHouseholdWrites.add(expense.id);

      final completer = pendingHouseholdCompleter ?? Completer<void>();
      pendingHouseholdCompleter = completer;
      final writeFuture = completer.future;
      final writeUid = callerUid;
      writeFuture.then((_) {
        rawPendingHouseholdWrites.remove(expense.id);
        onHouseholdExpenseSynced?.call(expense.id, writeUid);
      }).catchError((err, st) {
        rawPendingHouseholdWrites.remove(expense.id);
        onHouseholdExpenseRejected?.call(expense.id, writeUid, err);
      });
      return;
    } else {
      lastOperationWasOffline = false;
    }
  }

  @override
  Future<List<DemoBill>> loadBills() async {
    loadBillsCalls++;
    lastOperationWasOffline = simulateOffline;
    if (shouldThrowNetworkErrorOnLoad) {
      throw const SocketException('Connection failed');
    }
    return List.from(cachedBills);
  }

  @override
  Future<List<DemoExpense>> loadExpenses() async {
    loadExpensesCalls++;
    lastOperationWasOffline = simulateOffline;
    if (shouldThrowNetworkErrorOnLoad) {
      throw const SocketException('Connection failed');
    }
    return List.from(cachedExpenses);
  }

  @override
  Future<HouseholdExpensePage> loadHouseholdExpensesPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 50,
  }) async {
    lastOperationWasOffline = simulateOffline;
    if (shouldThrowNetworkErrorOnLoad) {
      throw const SocketException('Connection failed');
    }
    return const HouseholdExpensePage(
      items: [],
      lastDocument: null,
      hasMore: false,
    );
  }

  @override
  Future<List<HouseholdExpense>> loadHouseholdExpensesForMonth(
    int year,
    int month, {
    int batchSize = 500,
    int? limit,
  }) async {
    lastOperationWasOffline = simulateOffline;
    if (shouldThrowNetworkErrorOnLoad) {
      throw const SocketException('Connection failed');
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Bill and Expense Creation Resilience - 13 Verification Areas', () {
    late AppState state;
    late _MockOfflineFirestoreService mockFirestore;

    setUp(() {
      mockFirestore = _MockOfflineFirestoreService();
      state = AppState()
        ..isDemoMode = false
        ..auth = _MockAuth()
        ..firestoreService = mockFirestore;
      state.bills.clear();
      state.expenses.clear();
      state.householdExpenses.clear();
    });

    tearDown(() => state.dispose());

    test('1. Offline set() Future lifecycle: createBill returns immediately without waiting for background acknowledgement',
        () async {
      mockFirestore.simulateOffline = true;

      final stopwatch = Stopwatch()..start();
      final bill = await state.createBill(
        items: [BillLine(name: 'Chai', quantity: 1, unitPrice: 15)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      stopwatch.stop();

      // UI receives response promptly without awaiting remote ack
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(mockFirestore.pendingBillCompleter, isNotNull);
      expect(mockFirestore.pendingBillCompleter!.isCompleted, isFalse);
      expect(bill.isSaved, isFalse);
    });

    test('2. Immediate local cache visibility: bill is immediately visible in state.bills',
        () async {
      mockFirestore.simulateOffline = true;

      final bill = await state.createBill(
        items: [BillLine(name: 'Samosa', quantity: 2, unitPrice: 20)],
        paymentMode: 'Cash',
        vendorMode: false,
      );

      expect(state.bills.length, 1);
      expect(state.bills.first.id, bill.id);
      expect(state.selectedBill?.id, bill.id);
    });

    test('3. Pending-write metadata: AppState correctly tracks offline pending status',
        () async {
      mockFirestore.simulateOffline = true;

      final bill = await state.createBill(
        items: [BillLine(name: 'Biscuits', quantity: 1, unitPrice: 30)],
        paymentMode: 'UPI',
        vendorMode: false,
      );

      expect(mockFirestore.lastOperationWasOffline, isTrue);
      expect(state.isOffline, isTrue);
      expect(state.lastNotice, 'Bill saved offline. Pending synchronization when online.');
      expect(bill.isSaved, isFalse);
    });

    test('4. Receipt navigation during offline operation: receipt page opens immediately and loading clears',
        () async {
      mockFirestore.simulateOffline = true;

      await state.createBill(
        items: [BillLine(name: 'Cold Drink', quantity: 1, unitPrice: 40)],
        paymentMode: 'Cash',
        vendorMode: false,
      );

      expect(state.page, 'receipt');
      expect(state.isCloudLoading, isFalse);
      expect(state.cloudError, isNull);
    });

    test('5. Reconnection and synchronization: background ack marks bill isSaved=true and clears offline notice',
        () async {
      mockFirestore.simulateOffline = true;

      final bill = await state.createBill(
        items: [BillLine(name: 'Sugar', quantity: 1, unitPrice: 50)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      expect(bill.isSaved, isFalse);
      expect(state.isOffline, isTrue);

      // Simulate background reconnection ack
      mockFirestore.pendingBillCompleter!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(bill.isSaved, isTrue);
      expect(state.lastNotice, 'Bill synchronized with cloud.');
      expect(state.isOffline, isFalse);
    });

    test('6. Eventual backend rejection: server rule failure reports error without deleting local bill',
        () async {
      mockFirestore.simulateOffline = true;

      final bill = await state.createBill(
        items: [BillLine(name: 'Atta', quantity: 1, unitPrice: 350)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      expect(state.bills.length, 1);

      // Simulate server rejection (e.g., Security Rules violation on reconnection)
      mockFirestore.pendingBillCompleter!.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'Unauthorized bill'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(state.cloudError, contains('permission-denied'));
      expect(state.lastNotice, 'Offline bill sync failed.');
      // Local bill is NOT dropped or corrupted
      expect(state.bills.length, 1);
      expect(state.bills.first.id, bill.id);
      expect(bill.isSaved, isFalse);
    });

    test('7. Duplicate offline retry: identical retry reuses bill ID and prevents duplicate entry',
        () async {
      mockFirestore.simulateOffline = true;
      mockFirestore.failFirstWrite = true;

      final items = [BillLine(name: 'Poha', quantity: 1, unitPrice: 25)];

      await expectLater(
        state.createBill(items: items, paymentMode: 'Cash', vendorMode: false),
        throwsA(isA<SocketException>()),
      );

      final retryBill = await state.createBill(items: items, paymentMode: 'Cash', vendorMode: false);
      expect(state.bills.length, 1);
      expect(state.bills.first.id, retryBill.id);
    });

    test('8. Network recovery during submission: online success marks isSaved=true immediately',
        () async {
      mockFirestore.simulateOffline = false;

      final bill = await state.createBill(
        items: [BillLine(name: 'Kachori', quantity: 2, unitPrice: 20)],
        paymentMode: 'Cash',
        vendorMode: false,
      );

      expect(bill.isSaved, isTrue);
      expect(state.isOffline, isFalse);
      expect(state.lastNotice, 'Bill created successfully.');
      expect(state.page, 'receipt');
    });

    test('9. User sign-out with pending writes: background resolution after signout does not mutate state',
        () async {
      mockFirestore.simulateOffline = true;

      await state.createBill(
        items: [BillLine(name: 'Milk', quantity: 1, unitPrice: 30)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      expect(state.bills.length, 1);

      // User signs out while write is still pending
      await state.signOut();
      expect(state.isDemoMode, isTrue);

      // Write resolves in background after sign-out
      mockFirestore.pendingBillCompleter!.complete();
      await Future<void>.delayed(Duration.zero);

      // Stale write completion must not touch demo mode state
      expect(state.isDemoMode, isTrue);
      expect(state.lastNotice, isNot(contains('synchronized')));
    });

    test('10. Account switching with queued writes: User A queued write does not contaminate User B session',
        () async {
      mockFirestore.simulateOffline = true;

      await state.createBill(
        items: [BillLine(name: 'User A Item', quantity: 1, unitPrice: 100)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      final completerA = mockFirestore.pendingBillCompleter!;

      // User A signs out
      await state.signOut();

      // User B logs in
      final userBAuth = _MockAuth(initialUser: _MockUser(customUid: 'user-b-456'));
      state.auth = userBAuth;
      state.isDemoMode = false;
      state.bills.clear();
      state.lastNotice = 'Welcome User B';

      // User A's background write completes now
      completerA.complete();
      await Future<void>.delayed(Duration.zero);

      // User B's state remains intact without User A's sync message or data contamination
      expect(state.bills, isEmpty);
      expect(state.lastNotice, 'Welcome User B');
    });

    test('11. Bill creation: vendor mode navigation and receipt presentation works offline',
        () async {
      mockFirestore.simulateOffline = true;

      final vendorBill = await state.createBill(
        items: [BillLine(name: 'Cutting Chai', quantity: 1, unitPrice: 10)],
        paymentMode: 'Cash',
        vendorMode: true,
      );

      expect(vendorBill.id, isNotEmpty);
      expect(state.page, 'vendorReceipt');
      expect(state.bills.length, 1);
      expect(state.isOffline, isTrue);
    });

    test('12. Business expense creation: addExpense returns immediately offline and syncs upon reconnection',
        () async {
      mockFirestore.simulateOffline = true;

      final result = await state.addExpense(
        title: 'Packaging Bags',
        category: 'Packaging',
        amount: 350,
      );

      expect(result, isTrue);
      expect(mockFirestore.addExpenseCalls, 1);
      expect(state.expenses.length, 1);
      expect(state.page, 'expenseSaved');
      expect(state.isOffline, isTrue);
      expect(state.lastNotice, 'Expense saved offline. Pending synchronization when online.');

      // Server reconnection
      mockFirestore.pendingExpenseCompleter!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(state.lastNotice, 'Expense synchronized with cloud.');
      expect(state.isOffline, isFalse);
    });

    test('13. Household expense creation: addHouseholdExpense returns immediately offline and syncs upon reconnection',
        () async {
      mockFirestore.simulateOffline = true;

      final result = await state.addHouseholdExpense(
        title: 'Weekly Vegetables',
        category: 'Groceries',
        amount: 450,
      );

      expect(result, isTrue);
      expect(mockFirestore.addHouseholdCalls, 1);
      expect(state.householdExpenses.length, 1);
      expect(state.page, 'householdExpenses');
      expect(state.isOffline, isTrue);
      expect(state.lastNotice, 'Household expense saved offline. Pending synchronization when online.');

      // Server reconnection
      mockFirestore.pendingHouseholdCompleter!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(state.lastNotice, 'Household expense synchronized with cloud.');
      expect(state.isOffline, isFalse);
    });
  });
}
