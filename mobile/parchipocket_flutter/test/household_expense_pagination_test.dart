// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

class MockDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  MockDocumentSnapshot(this._id);

  final String _id;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => <String, dynamic>{'id': _id};
}

class PaginatedMockFirestoreService extends FirestoreService {
  PaginatedMockFirestoreService({required this.allExpenses});

  final List<HouseholdExpense> allExpenses;
  int pageReadCount = 0;

  @override
  Future<Map<String, dynamic>?> loadUserProfile() async => <String, dynamic>{
        'role': 'customer',
        'name': 'Test User',
      };

  @override
  Future<List<DemoBill>> loadBills() async => <DemoBill>[];

  @override
  Future<List<DemoExpense>> loadExpenses() async => <DemoExpense>[];

  @override
  Future<Set<String>> loadSavedShops() async => <String>{};

  @override
  Future<List<ClaimedReceipt>> loadClaimedReceipts() async => <ClaimedReceipt>[];

  @override
  Future<HouseholdExpensePage> loadHouseholdExpensesPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 50,
  }) async {
    pageReadCount++;
    if (allExpenses.isEmpty) {
      return const HouseholdExpensePage(
        items: <HouseholdExpense>[],
        hasMore: false,
      );
    }

    var startIndex = 0;
    if (startAfter != null) {
      final found = allExpenses.indexWhere((e) => e.id == startAfter.id);
      if (found != -1) {
        startIndex = found + 1;
      }
    }

    if (startIndex >= allExpenses.length) {
      return const HouseholdExpensePage(
        items: <HouseholdExpense>[],
        hasMore: false,
      );
    }

    final endIndex = (startIndex + limit < allExpenses.length)
        ? startIndex + limit
        : allExpenses.length;
    final pageItems = allExpenses.sublist(startIndex, endIndex);
    final hasMore = endIndex < allExpenses.length;
    final lastDoc =
        pageItems.isNotEmpty ? MockDocumentSnapshot(pageItems.last.id) : null;

    return HouseholdExpensePage(
      items: pageItems,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }
}

class PaginationMockUser extends Fake implements User {
  @override
  String get uid => 'test-user-pagination';
}

class PaginationTestAuth extends Fake implements FirebaseAuth {
  PaginationTestAuth() {
    controller = StreamController<User?>.broadcast();
  }

  late final StreamController<User?> controller;
  User? _currentUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => controller.stream;

  void emitUser(User? user) {
    _currentUser = user;
    controller.add(user);
  }

  Future<void> close() => controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Household Expense Query Pagination & Dashboard Calculations', () {
    test('Empty results handle cleanly without errors', () async {
      final auth = PaginationTestAuth();
      final service = PaginatedMockFirestoreService(allExpenses: <HouseholdExpense>[]);
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emitUser(PaginationMockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.householdExpenses, isEmpty);
      expect(state.hasMoreHouseholdExpenses, isFalse);
      expect(state.isLoadingMoreHouseholdExpenses, isFalse);

      await auth.close();
      state.dispose();
    });

    test('Loading the first page loads 50 records and sets hasMore', () async {
      final now = DateTime.now();
      final items = List<HouseholdExpense>.generate(
        75,
        (i) => HouseholdExpense(
          id: 'exp-$i',
          title: 'Item $i',
          category: 'Groceries',
          amount: 100.0,
          createdAt: DateTime(now.year, now.month - 1, 1).subtract(Duration(days: i)),
        ),
      );

      final auth = PaginationTestAuth();
      final service = PaginatedMockFirestoreService(allExpenses: items);
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emitUser(PaginationMockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.householdExpenses.length, 50);
      expect(state.hasMoreHouseholdExpenses, isTrue);
      expect(state.householdExpenses.first.id, 'exp-0');
      expect(state.householdExpenses.last.id, 'exp-49');

      await auth.close();
      state.dispose();
    });

    test('Loading subsequent pages appends older records without duplicates', () async {
      final now = DateTime.now();
      final items = List<HouseholdExpense>.generate(
        80,
        (i) => HouseholdExpense(
          id: 'exp-$i',
          title: 'Item $i',
          category: 'Vegetables',
          amount: 50.0,
          createdAt: DateTime(now.year, now.month - 1, 1).subtract(Duration(days: i)),
        ),
      );

      final auth = PaginationTestAuth();
      final service = PaginatedMockFirestoreService(allExpenses: items);
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emitUser(PaginationMockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.householdExpenses.length, 50);
      expect(state.hasMoreHouseholdExpenses, isTrue);

      final loadedMore = await state.loadMoreHouseholdExpenses(pageSize: 50);
      expect(loadedMore, isTrue);
      expect(state.householdExpenses.length, 80);
      expect(state.hasMoreHouseholdExpenses, isFalse);

      final idSet = state.householdExpenses.map((e) => e.id).toSet();
      expect(idSet.length, 80);

      await auth.close();
      state.dispose();
    });

    test('Strict descending date order is preserved across pages', () async {
      final now = DateTime.now();
      final items = List<HouseholdExpense>.generate(
        70,
        (i) => HouseholdExpense(
          id: 'exp-$i',
          title: 'Item $i',
          category: 'Dairy',
          amount: 40.0,
          createdAt: DateTime(now.year, now.month - 1, 15).subtract(Duration(hours: i * 3)),
        ),
      );

      final auth = PaginationTestAuth();
      final service = PaginatedMockFirestoreService(allExpenses: items);
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emitUser(PaginationMockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await state.loadMoreHouseholdExpenses(pageSize: 50);
      expect(state.householdExpenses.length, 70);

      for (var i = 0; i < state.householdExpenses.length - 1; i++) {
        final current = state.householdExpenses[i].createdAt;
        final next = state.householdExpenses[i + 1].createdAt;
        expect(
          current.isAfter(next) || current.isAtSameMomentAs(next),
          isTrue,
          reason: 'Item at $i must be newer than or equal to item at ${i + 1}',
        );
      }

      await auth.close();
      state.dispose();
    });

    test('Dashboard totals remain 100% accurate across multiple pages in current month', () async {
      final now = DateTime.now();
      final currentMonthExpenses = List<HouseholdExpense>.generate(
        75,
        (i) => HouseholdExpense(
          id: 'curr-$i',
          title: 'Current month item $i',
          category: 'Groceries',
          amount: 100.0,
          createdAt: DateTime(now.year, now.month, 1, 12, 0).add(Duration(minutes: i * 5)),
        ),
      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final prevMonthExpenses = List<HouseholdExpense>.generate(
        20,
        (i) => HouseholdExpense(
          id: 'prev-$i',
          title: 'Prev month item $i',
          category: 'Transport',
          amount: 50.0,
          createdAt: DateTime(now.year, now.month - 1, 10, 10, 0).add(Duration(minutes: i * 5)),
        ),
      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final allExpenses = <HouseholdExpense>[...currentMonthExpenses, ...prevMonthExpenses];

      final auth = PaginationTestAuth();
      final service = PaginatedMockFirestoreService(allExpenses: allExpenses);
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emitUser(PaginationMockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final loadedCurrentMonth = state.householdExpenses
          .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
          .toList();
      expect(loadedCurrentMonth.length, 75);

      final totalCurrentMonth =
          loadedCurrentMonth.fold<double>(0, (acc, e) => acc + e.amount);
      expect(totalCurrentMonth, 7500.0);

      await auth.close();
      state.dispose();
    });
  });
}
