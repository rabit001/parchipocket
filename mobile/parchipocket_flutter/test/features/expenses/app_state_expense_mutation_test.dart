import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'user_test_123';
}

class MockFirebaseAuth extends Fake implements FirebaseAuth {
  User? user = MockUser();

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    user = null;
  }
}

class MockHouseholdFirestoreService extends FirestoreService {
  int updateCalls = 0;
  int voidCalls = 0;
  HouseholdExpense? lastUpdatedExpense;
  String? lastVoidedId;
  String? lastVoidReason;
  bool shouldThrow = false;
  Exception? exceptionToThrow;
  Completer<void>? pendingCompleter;

  @override
  Future<void> updateHouseholdExpense(HouseholdExpense expense) async {
    updateCalls++;
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    if (shouldThrow) {
      throw exceptionToThrow ?? Exception('Firestore update failed');
    }
    lastUpdatedExpense = expense;
  }

  @override
  Future<void> voidHouseholdExpense(String expenseId, {String? reason}) async {
    voidCalls++;
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    if (shouldThrow) {
      throw exceptionToThrow ?? Exception('Firestore void failed');
    }
    lastVoidedId = expenseId;
    lastVoidReason = reason;
  }
}

void main() {
  group('AppState HouseholdExpense Mutations & Calculations', () {
    late AppState state;
    late MockFirebaseAuth auth;
    late MockHouseholdFirestoreService service;

    setUp(() {
      auth = MockFirebaseAuth();
      service = MockHouseholdFirestoreService();
      state = AppState()
        ..isDemoMode = false
        ..auth = auth
        ..firestoreService = service;
      state.householdExpenses.clear();
    });

    tearDown(() {
      state.dispose();
    });

    test('1. Successful cloud expense correction replaces item and updates timestamp', () async {
      final initial = HouseholdExpense(
        id: 'exp_cloud_1',
        title: 'Fresh Milk',
        category: 'Groceries',
        amount: 40.0,
        createdAt: DateTime.utc(2026, 10, 20, 10, 0),
        source: 'manual',
      );
      state.householdExpenses.add(initial);

      final updated = initial.copyWith(
        title: 'Fresh Milk 1L',
        amount: 45.0,
      );

      final success = await state.updateHouseholdExpense(updated);

      expect(success, isTrue);
      expect(service.updateCalls, 1);
      expect(service.lastUpdatedExpense?.title, 'Fresh Milk 1L');
      expect(service.lastUpdatedExpense?.amount, 45.0);

      expect(state.householdExpenses.length, 1);
      final inMemory = state.householdExpenses.first;
      expect(inMemory.title, 'Fresh Milk 1L');
      expect(inMemory.amount, 45.0);
      expect(inMemory.updatedAt, isNotNull);
      expect(inMemory.history.length, 1);
      expect(inMemory.history.first.title, 'Fresh Milk');
    });

    test('2. Successful demo expense correction does not call FirestoreService', () async {
      state.isDemoMode = true;
      final initial = HouseholdExpense(
        id: 'demo_exp_1',
        title: 'Apples 1kg',
        category: 'Groceries',
        amount: 120.0,
        createdAt: DateTime.utc(2026, 10, 22, 11, 0),
        source: 'manual',
      );
      state.householdExpenses.add(initial);

      final updated = initial.copyWith(
        title: 'Green Apples 1kg',
        amount: 140.0,
      );

      final success = await state.updateHouseholdExpense(updated);

      expect(success, isTrue);
      expect(service.updateCalls, 0);
      expect(state.householdExpenses.first.title, 'Green Apples 1kg');
      expect(state.householdExpenses.first.amount, 140.0);
      expect(state.householdExpenses.first.history.length, 1);
    });

    test('3. Correction snapshot generation preserves previous states sequentially', () async {
      state.isDemoMode = true;
      final initialDate = DateTime.utc(2026, 10, 15, 9, 0);
      final initial = HouseholdExpense(
        id: 'demo_audit_1',
        title: 'Cooking Oil',
        category: 'Groceries',
        amount: 160.0,
        createdAt: initialDate,
        source: 'manual',
      );
      state.householdExpenses.add(initial);

      // First correction
      await state.updateHouseholdExpense(initial.copyWith(
        title: 'Olive Oil',
        amount: 350.0,
      ));

      final firstCorrection = state.householdExpenses.first;
      expect(firstCorrection.history.length, 1);
      expect(firstCorrection.history[0].title, 'Cooking Oil');
      expect(firstCorrection.history[0].amount, 160.0);
      expect(firstCorrection.history[0].modifiedAt, isNull);
      final firstUpdatedAt = firstCorrection.updatedAt;
      expect(firstUpdatedAt, isNotNull);

      // Second correction
      await state.updateHouseholdExpense(firstCorrection.copyWith(
        title: 'Extra Virgin Olive Oil',
        amount: 420.0,
      ));

      final secondCorrection = state.householdExpenses.first;
      expect(secondCorrection.history.length, 2);
      expect(secondCorrection.history[0].title, 'Cooking Oil');
      expect(secondCorrection.history[1].title, 'Olive Oil');
      expect(secondCorrection.history[1].amount, 350.0);
      expect(secondCorrection.history[1].modifiedAt, firstUpdatedAt);
    });

    test('4. Missing expense rejected with StateError', () async {
      final missing = HouseholdExpense(
        id: 'ghost_id',
        title: 'Phantom',
        category: 'Groceries',
        amount: 50.0,
        createdAt: DateTime.now(),
      );

      expect(
        () => state.updateHouseholdExpense(missing),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Household expense not found'))),
      );
    });

    test('5. Voided expense cannot be edited', () async {
      final voided = HouseholdExpense(
        id: 'exp_void_test',
        title: 'Old Expense',
        category: 'Utilities',
        amount: 500.0,
        createdAt: DateTime.now(),
        isVoided: true,
      );
      state.householdExpenses.add(voided);

      expect(
        () => state.updateHouseholdExpense(voided.copyWith(title: 'Attempted Change')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Cannot modify a voided household expense'))),
      );
    });

    test('6. Successful cloud void marks expense voided and preserves original details', () async {
      final initial = HouseholdExpense(
        id: 'exp_cloud_void',
        title: 'Electricity Bill',
        category: 'Utilities',
        amount: 850.0,
        createdAt: DateTime.utc(2026, 10, 18, 14, 0),
        source: 'manual',
      );
      state.householdExpenses.add(initial);

      final success = await state.voidHouseholdExpense('exp_cloud_void', reason: 'Paid by landlord');

      expect(success, isTrue);
      expect(service.voidCalls, 1);
      expect(service.lastVoidedId, 'exp_cloud_void');
      expect(service.lastVoidReason, 'Paid by landlord');

      final inMemory = state.householdExpenses.first;
      expect(inMemory.isVoided, isTrue);
      expect(inMemory.voidReason, 'Paid by landlord');
      expect(inMemory.voidedAt, isNotNull);
      expect(inMemory.title, 'Electricity Bill');
      expect(inMemory.amount, 850.0);
    });

    test('7. Successful demo void marks item voided locally without calling service', () async {
      state.isDemoMode = true;
      final initial = HouseholdExpense(
        id: 'demo_void_1',
        title: 'Snacks',
        category: 'Groceries',
        amount: 45.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(initial);

      final success = await state.voidHouseholdExpense('demo_void_1', reason: 'Wrong category');

      expect(success, isTrue);
      expect(service.voidCalls, 0);
      expect(state.householdExpenses.first.isVoided, isTrue);
      expect(state.householdExpenses.first.voidReason, 'Wrong category');
    });

    test('8. Repeated void rejected with StateError', () async {
      state.isDemoMode = true;
      final initial = HouseholdExpense(
        id: 'demo_double_void',
        title: 'Snacks',
        category: 'Groceries',
        amount: 45.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(initial);

      await state.voidHouseholdExpense('demo_double_void');

      expect(
        () => state.voidHouseholdExpense('demo_double_void'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Expense is already voided'))),
      );
    });

    test('9. Voided items excluded from all totals', () {
      final now = DateTime.now();
      state.householdExpenses.addAll(<HouseholdExpense>[
        HouseholdExpense(
          id: '1',
          title: 'Active 1',
          category: 'Groceries',
          amount: 100.0,
          createdAt: now,
          isVoided: false,
        ),
        HouseholdExpense(
          id: '2',
          title: 'Voided 2',
          category: 'Groceries',
          amount: 200.0,
          createdAt: now,
          isVoided: true,
        ),
        HouseholdExpense(
          id: '3',
          title: 'Active 3',
          category: 'Transport',
          amount: 300.0,
          createdAt: now,
          isVoided: false,
        ),
      ]);

      expect(state.activeHouseholdExpenses.length, 2);
      expect(state.totalHouseholdSpend, 400.0);
      expect(state.spentToday, 400.0);
      expect(state.spentThisMonth, 400.0);
    });

    test('10. Backdated expense affects its correct month based on effectiveDate', () {
      final now = DateTime.now();
      final octDate = DateTime(now.year, 10, 15);
      final septDate = DateTime(now.year, 9, 20);

      state.householdExpenses.addAll(<HouseholdExpense>[
        HouseholdExpense(
          id: '1',
          title: 'Oct Entry',
          category: 'Groceries',
          amount: 150.0,
          createdAt: now,
          expenseDate: octDate,
        ),
        HouseholdExpense(
          id: '2',
          title: 'Sept Backdated Entry',
          category: 'Groceries',
          amount: 250.0,
          createdAt: now,
          expenseDate: septDate,
        ),
      ]);

      expect(state.householdSpendForMonth(now.year, 10), 150.0);
      expect(state.householdSpendForMonth(now.year, 9), 250.0);
      expect(state.totalHouseholdSpend, 400.0);
    });

    test('11. Yesterday expense excluded from today total', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      state.householdExpenses.addAll(<HouseholdExpense>[
        HouseholdExpense(
          id: 'today_item',
          title: 'Today purchase',
          category: 'Food',
          amount: 80.0,
          createdAt: now,
        ),
        HouseholdExpense(
          id: 'yesterday_item',
          title: 'Yesterday purchase',
          category: 'Food',
          amount: 120.0,
          createdAt: yesterday,
        ),
      ]);

      expect(state.spentToday, 80.0);
      expect(state.spentOnDay(yesterday), 120.0);
      expect(state.totalHouseholdSpend, 200.0);
    });

    test('12. Correct total recalculation immediately after amount change and voiding', () async {
      state.isDemoMode = true;
      final now = DateTime.now();
      final item1 = HouseholdExpense(
        id: 'item_1',
        title: 'Tomatoes',
        category: 'Groceries',
        amount: 50.0,
        createdAt: now,
      );
      final item2 = HouseholdExpense(
        id: 'item_2',
        title: 'Onions',
        category: 'Groceries',
        amount: 30.0,
        createdAt: now,
      );
      state.householdExpenses.addAll([item1, item2]);

      expect(state.totalHouseholdSpend, 80.0);
      expect(state.spentToday, 80.0);

      // Edit item 1 amount to 70
      await state.updateHouseholdExpense(item1.copyWith(amount: 70.0));
      expect(state.totalHouseholdSpend, 100.0);
      expect(state.spentToday, 100.0);

      // Void item 2
      await state.voidHouseholdExpense('item_2');
      expect(state.totalHouseholdSpend, 70.0);
      expect(state.spentToday, 70.0);
    });

    test('13. Session reset/logout during pending cloud operation protects state', () async {
      service.pendingCompleter = Completer<void>();
      final item = HouseholdExpense(
        id: 'pending_exp',
        title: 'Gas Cylinder',
        category: 'Utilities',
        amount: 900.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(item);

      // Launch async cloud update
      final updateFuture = state.updateHouseholdExpense(item.copyWith(title: 'Gas Cylinder Refill'));
      expect(state.isHouseholdExpenseOperationPending('pending_exp'), isTrue);

      // User signs out on auth provider while write is in flight
      auth.user = null;

      // Complete the pending backend write
      service.pendingCompleter!.complete();
      final result = await updateFuture;

      expect(result, isFalse);
      expect(state.isHouseholdExpenseOperationPending('pending_exp'), isFalse);
      // Ensure in-memory title was NOT updated because session changed
      expect(state.householdExpenses.first.title, 'Gas Cylinder');
    });

    test('14. Pagination state remains consistent after edit and void', () async {
      state.isDemoMode = true;
      final item1 = HouseholdExpense(
        id: 'p_1',
        title: 'Item 1',
        category: 'Groceries',
        amount: 10.0,
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final item2 = HouseholdExpense(
        id: 'p_2',
        title: 'Item 2',
        category: 'Groceries',
        amount: 20.0,
        createdAt: DateTime.utc(2026, 10, 19),
      );
      state.householdExpenses.addAll([item1, item2]);
      state.hasMoreHouseholdExpenses = true;

      // Edit item 2
      await state.updateHouseholdExpense(item2.copyWith(title: 'Item 2 Edited'));
      expect(state.householdExpenses.length, 2);
      expect(state.householdExpenses[1].title, 'Item 2 Edited');
      expect(state.hasMoreHouseholdExpenses, isTrue);

      // Void item 1
      await state.voidHouseholdExpense('p_1');
      expect(state.householdExpenses.length, 2);
      expect(state.householdExpenses[0].id, 'p_1');
      expect(state.householdExpenses[0].isVoided, isTrue);
      expect(state.hasMoreHouseholdExpenses, isTrue);
    });
  });
}
