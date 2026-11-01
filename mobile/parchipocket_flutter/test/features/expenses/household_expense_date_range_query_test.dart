// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

class FakeDateRangeDocSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  FakeDateRangeDocSnapshot(this._id, this._data);
  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
}

class FakeDateRangeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  FakeDateRangeQuerySnapshot(this._docs);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
}

class FakeExpensesCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeExpensesCollectionReference(this.documents);
  final List<Map<String, dynamic>> documents;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakeExpenseQuery(
      allDocs: documents,
    ).where(
      field,
      isLessThan: isLessThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return FakeExpenseQuery(allDocs: documents).orderBy(field, descending: descending);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'generated_id_${DateTime.now().microsecondsSinceEpoch}';
    return FakeExpenseDocRef(id);
  }
}

class FakeExpenseDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeExpenseDocRef(this._id);
  final String _id;

  @override
  String get id => _id;
}

class FakeExpenseQuery extends Fake implements Query<Map<String, dynamic>> {
  FakeExpenseQuery({
    required this.allDocs,
    this.filterField,
    this.minBound,
    this.maxBound,
    this.orderField,
    this.descending = false,
    this.queryLimit,
    this.startAfterDoc,
  });

  final List<Map<String, dynamic>> allDocs;
  final String? filterField;
  final Timestamp? minBound;
  final Timestamp? maxBound;
  final String? orderField;
  final bool descending;
  final int? queryLimit;
  final DocumentSnapshot<Object?>? startAfterDoc;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakeExpenseQuery(
      allDocs: allDocs,
      filterField: field.toString(),
      minBound: isGreaterThanOrEqualTo as Timestamp? ?? minBound,
      maxBound: isLessThan as Timestamp? ?? maxBound,
      orderField: orderField,
      descending: descending,
      queryLimit: queryLimit,
      startAfterDoc: startAfterDoc,
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return FakeExpenseQuery(
      allDocs: allDocs,
      filterField: filterField,
      minBound: minBound,
      maxBound: maxBound,
      orderField: field.toString(),
      descending: descending,
      queryLimit: queryLimit,
      startAfterDoc: startAfterDoc,
    );
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    return FakeExpenseQuery(
      allDocs: allDocs,
      filterField: filterField,
      minBound: minBound,
      maxBound: maxBound,
      orderField: orderField,
      descending: descending,
      queryLimit: limit,
      startAfterDoc: startAfterDoc,
    );
  }

  @override
  Query<Map<String, dynamic>> startAfterDocument(
      DocumentSnapshot<Object?> documentSnapshot) {
    return FakeExpenseQuery(
      allDocs: allDocs,
      filterField: filterField,
      minBound: minBound,
      maxBound: maxBound,
      orderField: orderField,
      descending: descending,
      queryLimit: queryLimit,
      startAfterDoc: documentSnapshot,
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    var result = allDocs.where((doc) {
      if (filterField == null) return true;
      final val = doc[filterField];
      // In Firestore, documents without the filtered field are excluded from range queries
      if (val is! Timestamp) return false;
      if (minBound != null && val.compareTo(minBound!) < 0) return false;
      if (maxBound != null && val.compareTo(maxBound!) >= 0) return false;
      return true;
    }).toList();

    final sortField = orderField ?? filterField;
    if (sortField != null) {
      result.sort((a, b) {
        final valA = a[sortField] as Timestamp?;
        final valB = b[sortField] as Timestamp?;
        if (valA == null && valB == null) return 0;
        if (valA == null) return descending ? 1 : -1;
        if (valB == null) return descending ? -1 : 1;
        final cmp = descending ? valB.compareTo(valA) : valA.compareTo(valB);
        if (cmp != 0) return cmp;
        final idA = a['id'] as String? ?? '';
        final idB = b['id'] as String? ?? '';
        return idA.compareTo(idB);
      });
    }

    if (startAfterDoc != null) {
      final idx = result.indexWhere((d) => d['id'] == startAfterDoc!.id);
      if (idx != -1) {
        result = result.sublist(idx + 1);
      }
    }

    if (queryLimit != null && result.length > queryLimit!) {
      result = result.sublist(0, queryLimit!);
    }

    final snapshots = result
        .map((d) => FakeDateRangeDocSnapshot(d['id'] as String, d))
        .toList();
    return FakeDateRangeQuerySnapshot(snapshots);
  }
}

class FakeUserDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeUserDocRef(this.documents);
  final List<Map<String, dynamic>> documents;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'householdExpenses') {
      return FakeExpensesCollectionReference(documents);
    }
    throw UnimplementedError('collection $collectionPath');
  }
}

class FakeUsersCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeUsersCollection(this.userDoc);
  final FakeUserDocRef userDoc;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => userDoc;
}

class FakeFirestore extends Fake implements FirebaseFirestore {
  FakeFirestore(this.userDoc);
  final FakeUserDocRef userDoc;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'users') {
      return FakeUsersCollection(userDoc);
    }
    throw UnimplementedError('collection $collectionPath');
  }
}

class FakeAuthUser extends Fake implements User {
  @override
  String get uid => 'customer-test-uid';
}

class FakeTestAuth extends Fake implements FirebaseAuth {
  FakeTestAuth(this._user);
  final User? _user;

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Household Expense Date-Range Query & Monthly Calculation Tests', () {
    late List<Map<String, dynamic>> store;
    late FakeFirestore firestore;
    late FakeTestAuth auth;
    late FirestoreService service;

    setUp(() {
      store = <Map<String, dynamic>>[];
      final userDoc = FakeUserDocRef(store);
      firestore = FakeFirestore(userDoc);
      auth = FakeTestAuth(FakeAuthUser());
      service = FirestoreService(firestore: firestore, auth: auth);
    });

    // Test 1: Expense created in August and backdated/forward-dated to October (captured in October).
    test('1. Expense created in August and dated in October is captured in October', () async {
      final augCreated = DateTime(2026, 8, 15, 12, 0);
      final octDate = DateTime(2026, 10, 5, 14, 0);

      store.add(<String, dynamic>{
        'id': 'exp-aug-created-oct-dated',
        'title': 'Festival Sweets',
        'category': 'Snacks',
        'amount': 450.0,
        'createdAt': Timestamp.fromDate(augCreated),
        'expenseDate': Timestamp.fromDate(octDate),
        'source': 'manual',
      });

      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults.length, 1);
      expect(octResults.first.id, 'exp-aug-created-oct-dated');
      expect(octResults.first.effectiveDate, octDate);

      // Verify excluded from August
      final augResults = await service.loadHouseholdExpensesForMonth(2026, 8);
      expect(augResults, isEmpty);
    });

    // Test 2: Legacy August record without expenseDate (captured in August, excluded from October).
    test('2. Legacy August record without expenseDate is captured in August and excluded from October', () async {
      final augCreated = DateTime(2026, 8, 20, 10, 0);

      store.add(<String, dynamic>{
        'id': 'legacy-aug-exp',
        'title': 'School Books',
        'category': 'Education',
        'amount': 800.0,
        'createdAt': Timestamp.fromDate(augCreated),
        // No expenseDate (legacy Phase 1 document)
        'source': 'manual',
      });

      // August query captures it via createdAt
      final augResults = await service.loadHouseholdExpensesForMonth(2026, 8);
      expect(augResults.length, 1);
      expect(augResults.first.id, 'legacy-aug-exp');
      expect(augResults.first.effectiveDate, augCreated);

      // October query excludes it
      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults, isEmpty);
    });

    // Test 3: Current-month expense without expenseDate (captured in October via createdAt).
    test('3. Current-month expense without expenseDate is captured in October via createdAt', () async {
      final octCreated = DateTime(2026, 10, 10, 9, 30);

      store.add(<String, dynamic>{
        'id': 'oct-no-expensedate',
        'title': 'Milk Daily',
        'category': 'Dairy',
        'amount': 60.0,
        'createdAt': Timestamp.fromDate(octCreated),
        'source': 'manual',
      });

      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults.length, 1);
      expect(octResults.first.id, 'oct-no-expensedate');
      expect(octResults.first.effectiveDate, octCreated);
    });

    // Test 4: Expense created this month but assigned to previous month (excluded from October, captured in previous month).
    test('4. Expense created in October but assigned to September is excluded from October and captured in September', () async {
      final octCreated = DateTime(2026, 10, 2, 11, 0);
      final sepDate = DateTime(2026, 9, 28, 16, 0);

      store.add(<String, dynamic>{
        'id': 'created-oct-dated-sep',
        'title': 'Old Electricity Bill',
        'category': 'Utilities',
        'amount': 1200.0,
        'createdAt': Timestamp.fromDate(octCreated),
        'expenseDate': Timestamp.fromDate(sepDate),
        'source': 'manual',
      });

      // Excluded from October even though createdAt is in October
      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults, isEmpty);

      // Captured in September
      final sepResults = await service.loadHouseholdExpensesForMonth(2026, 9);
      expect(sepResults.length, 1);
      expect(sepResults.first.id, 'created-oct-dated-sep');
      expect(sepResults.first.effectiveDate, sepDate);
    });

    // Test 5: Voided expenses excluded from results.
    test('5. Voided expenses are strictly excluded from date-range results', () async {
      final octDate = DateTime(2026, 10, 12, 10, 0);

      store.add(<String, dynamic>{
        'id': 'active-oct-exp',
        'title': 'Groceries',
        'category': 'Groceries',
        'amount': 500.0,
        'createdAt': Timestamp.fromDate(octDate),
        'expenseDate': Timestamp.fromDate(octDate),
        'isVoided': false,
        'source': 'manual',
      });

      store.add(<String, dynamic>{
        'id': 'voided-oct-exp',
        'title': 'Mistake Entry',
        'category': 'Groceries',
        'amount': 9999.0,
        'createdAt': Timestamp.fromDate(octDate),
        'expenseDate': Timestamp.fromDate(octDate),
        'isVoided': true,
        'voidedAt': Timestamp.fromDate(DateTime(2026, 10, 12, 11, 0)),
        'voidReason': 'Accidental duplicate',
        'source': 'manual',
      });

      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults.length, 1);
      expect(octResults.first.id, 'active-oct-exp');
      expect(octResults.any((e) => e.id == 'voided-oct-exp'), isFalse);
    });

    // Test 6: Duplicate records returned by both queries merged to single instance.
    test('6. Duplicate records returned by both expenseDate and createdAt queries are merged to a single instance', () async {
      final octDate = DateTime(2026, 10, 15, 12, 0);

      // Both expenseDate and createdAt are in October, so both queries will return this document
      store.add(<String, dynamic>{
        'id': 'dual-match-doc',
        'title': 'Dinner Out',
        'category': 'Food',
        'amount': 750.0,
        'createdAt': Timestamp.fromDate(octDate),
        'expenseDate': Timestamp.fromDate(octDate),
        'source': 'manual',
      });

      final octResults = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(octResults.length, 1);
      expect(octResults.first.id, 'dual-match-doc');
      expect(octResults.first.amount, 750.0);
    });

    // Test 7: Monthly totals after editing and voiding.
    test('7. Monthly totals update correctly after editing amounts, dates, and voiding', () {
      final state = AppState();
      state.householdExpenses.clear();

      final octDate1 = DateTime(2026, 10, 5);
      final octDate2 = DateTime(2026, 10, 10);

      final exp1 = HouseholdExpense(
        id: 'exp-1',
        title: 'Vegetables',
        category: 'Food',
        amount: 200.0,
        createdAt: octDate1,
        expenseDate: octDate1,
      );

      final exp2 = HouseholdExpense(
        id: 'exp-2',
        title: 'Electricity',
        category: 'Bills',
        amount: 800.0,
        createdAt: octDate2,
        expenseDate: octDate2,
      );

      state.householdExpenses.addAll([exp1, exp2]);

      // Total for October: 200 + 800 = 1000
      expect(state.householdSpendForMonth(2026, 10), 1000.0);

      // Edit exp1: increase amount to 350
      state.updateHouseholdExpense(exp1.copyWith(amount: 350.0));
      expect(state.householdSpendForMonth(2026, 10), 1150.0);

      // Edit exp2: move to September (backdate)
      final sepDate = DateTime(2026, 9, 20);
      state.updateHouseholdExpense(exp2.copyWith(expenseDate: sepDate));
      expect(state.householdSpendForMonth(2026, 10), 350.0);
      expect(state.householdSpendForMonth(2026, 9), 800.0);

      // Void exp1: October total drops to 0
      state.voidHouseholdExpense('exp-1', reason: 'Refunded');
      expect(state.householdSpendForMonth(2026, 10), 0.0);
      // September total remains 800
      expect(state.householdSpendForMonth(2026, 9), 800.0);
    });

    // Test 8: Pagination (loadHouseholdExpensesPage) remains unchanged and ordered by createdAt DESC.
    test('8. Daily Log pagination remains unchanged and ordered strictly by createdAt DESC', () async {
      final now = DateTime(2026, 10, 20, 12, 0);

      for (var i = 0; i < 75; i++) {
        final created = now.subtract(Duration(hours: i));
        // Alternate custom expenseDate to prove pagination ignores expenseDate ordering
        final customDate = (i % 2 == 0)
            ? now.subtract(Duration(days: 30 + i))
            : now.add(Duration(days: i));

        store.add(<String, dynamic>{
          'id': 'page-item-$i',
          'title': 'Item $i',
          'category': 'General',
          'amount': 10.0 + i,
          'createdAt': Timestamp.fromDate(created),
          'expenseDate': Timestamp.fromDate(customDate),
          'source': 'manual',
        });
      }

      // First page of 50
      final firstPage = await service.loadHouseholdExpensesPage(limit: 50);
      expect(firstPage.items.length, 50);
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.items.first.id, 'page-item-0');
      expect(firstPage.items.last.id, 'page-item-49');

      // Verify strict descending createdAt order
      for (var i = 0; i < firstPage.items.length - 1; i++) {
        final current = firstPage.items[i].createdAt;
        final next = firstPage.items[i + 1].createdAt;
        expect(current.isAfter(next), isTrue);
      }

      // Second page of remaining 25
      final secondPage = await service.loadHouseholdExpensesPage(
        startAfter: firstPage.lastDocument,
        limit: 50,
      );
      expect(secondPage.items.length, 25);
      expect(secondPage.hasMore, isFalse);
      expect(secondPage.items.first.id, 'page-item-50');
      expect(secondPage.items.last.id, 'page-item-74');
    });

    // Test 9: More than 1000 matching records fetched across multiple pages without truncation.
    test('9. More than 1000 matching records are retrieved across multiple pages without truncation', () async {
      final baseDate = DateTime(2026, 10, 1, 10, 0);

      // Add 1250 expenses in October
      for (var i = 0; i < 1250; i++) {
        final expenseDate = baseDate.add(Duration(minutes: i));
        store.add(<String, dynamic>{
          'id': 'exp-bulk-$i',
          'title': 'Bulk Item $i',
          'category': 'Bulk',
          'amount': 10.0,
          'createdAt': Timestamp.fromDate(expenseDate),
          'expenseDate': Timestamp.fromDate(expenseDate),
          'source': 'manual',
        });
      }

      // Default batchSize is 500. 1250 records will take 3 pages (500 + 500 + 250).
      final results = await service.loadHouseholdExpensesForMonth(2026, 10);
      expect(results.length, 1250);

      final totalSpend = results.fold<double>(0.0, (acc, e) => acc + e.amount);
      expect(totalSpend, 12500.0);
    });

    // Test 10: Multi-page retrieval with duplicate IDs across both queries, legacy records, backdated records, and voided records.
    test('10. Multi-page retrieval handles dual matches, legacy records, backdated records, and voided records accurately', () async {
      final octBase = DateTime(2026, 10, 1, 10, 0);
      final augDate = DateTime(2026, 8, 15, 10, 0);
      final sepDate = DateTime(2026, 9, 15, 10, 0);

      // 400 modern expenses with both expenseDate and createdAt in October (captured by both queries -> deduplicated)
      for (var i = 0; i < 400; i++) {
        final date = octBase.add(Duration(minutes: i));
        store.add(<String, dynamic>{
          'id': 'dual-$i',
          'title': 'Dual Match $i',
          'category': 'Groceries',
          'amount': 20.0,
          'createdAt': Timestamp.fromDate(date),
          'expenseDate': Timestamp.fromDate(date),
          'source': 'manual',
        });
      }

      // 400 legacy expenses with createdAt in October and NO expenseDate (captured by createdAt query)
      for (var i = 0; i < 400; i++) {
        final date = octBase.add(Duration(minutes: 500 + i));
        store.add(<String, dynamic>{
          'id': 'legacy-$i',
          'title': 'Legacy $i',
          'category': 'Utilities',
          'amount': 30.0,
          'createdAt': Timestamp.fromDate(date),
          'source': 'manual',
        });
      }

      // 300 backdated expenses: createdAt in August/September, but expenseDate in October (captured by expenseDate query)
      for (var i = 0; i < 300; i++) {
        final expDate = octBase.add(Duration(minutes: 1000 + i));
        store.add(<String, dynamic>{
          'id': 'backdated-$i',
          'title': 'Backdated $i',
          'category': 'Shopping',
          'amount': 40.0,
          'createdAt': Timestamp.fromDate(augDate.add(Duration(minutes: i))),
          'expenseDate': Timestamp.fromDate(expDate),
          'source': 'manual',
        });
      }

      // 200 expenses created in October but dated in September (should be EXCLUDED from October)
      for (var i = 0; i < 200; i++) {
        final crDate = octBase.add(Duration(minutes: 1500 + i));
        store.add(<String, dynamic>{
          'id': 'sep-dated-$i',
          'title': 'September Dated $i',
          'category': 'Misc',
          'amount': 50.0,
          'createdAt': Timestamp.fromDate(crDate),
          'expenseDate': Timestamp.fromDate(sepDate.add(Duration(minutes: i))),
          'source': 'manual',
        });
      }

      // 150 voided expenses in October (should be EXCLUDED)
      for (var i = 0; i < 150; i++) {
        final date = octBase.add(Duration(minutes: 2000 + i));
        store.add(<String, dynamic>{
          'id': 'voided-$i',
          'title': 'Voided $i',
          'category': 'Cancelled',
          'amount': 100.0,
          'createdAt': Timestamp.fromDate(date),
          'expenseDate': Timestamp.fromDate(date),
          'isVoided': true,
          'voidedAt': Timestamp.fromDate(date.add(const Duration(minutes: 5))),
          'voidReason': 'Duplicate entry $i',
          'source': 'manual',
        });
      }

      // Total valid October expenses: 400 (dual) + 400 (legacy) + 300 (backdated) = 1100 (> 1000)
      final results = await service.loadHouseholdExpensesForMonth(
        2026,
        10,
        batchSize: 250,
      );

      expect(results.length, 1100);

      // Verify all IDs are unique (deduplication verified across multiple pages)
      final ids = results.map((e) => e.id).toSet();
      expect(ids.length, 1100);

      // Verify no September-dated expenses included
      expect(results.any((e) => e.id.startsWith('sep-dated-')), isFalse);

      // Verify no voided expenses included
      expect(results.any((e) => e.isVoided), isFalse);
      expect(results.any((e) => e.id.startsWith('voided-')), isFalse);

      // Expected total: (400 * 20.0) + (400 * 30.0) + (300 * 40.0) = 8000 + 12000 + 12000 = 32000.0
      final total = results.fold<double>(0.0, (acc, e) => acc + e.amount);
      expect(total, 32000.0);
    });

    // Test 11: Empty subsequent pages when total records is an exact multiple of batchSize.
    test('11. Empty subsequent pages are handled cleanly when document count is an exact multiple of batch size', () async {
      final octBase = DateTime(2026, 10, 1, 10, 0);

      // Exactly 1000 records. With batchSize = 500, page 1 returns 500, page 2 returns 500, page 3 returns 0 (empty).
      for (var i = 0; i < 1000; i++) {
        final date = octBase.add(Duration(minutes: i));
        store.add(<String, dynamic>{
          'id': 'exact-multiple-$i',
          'title': 'Item $i',
          'category': 'Groceries',
          'amount': 15.0,
          'createdAt': Timestamp.fromDate(date),
          'expenseDate': Timestamp.fromDate(date),
          'source': 'manual',
        });
      }

      final results = await service.loadHouseholdExpensesForMonth(
        2026,
        10,
        batchSize: 500,
      );

      expect(results.length, 1000);
      expect(results.map((e) => e.id).toSet().length, 1000);
    });

    // Test 12: No repeated or skipped documents across multiple pages.
    test('12. No repeated or skipped documents occur during multi-page pagination', () async {
      final octBase = DateTime(2026, 10, 1, 8, 0);
      const totalCount = 1500;

      for (var i = 0; i < totalCount; i++) {
        final date = octBase.add(Duration(minutes: i));
        store.add(<String, dynamic>{
          'id': 'seq-doc-$i',
          'title': 'Sequential Document $i',
          'category': 'Paging',
          'amount': 5.0,
          'createdAt': Timestamp.fromDate(date),
          'expenseDate': Timestamp.fromDate(date),
          'source': 'manual',
        });
      }

      // Batch size 300 -> 5 full pages (300 * 5 = 1500), then page 6 empty
      final results = await service.loadHouseholdExpensesForMonth(
        2026,
        10,
        batchSize: 300,
      );

      expect(results.length, totalCount);

      final returnedIds = results.map((e) => e.id).toSet();
      expect(returnedIds.length, totalCount);

      // Verify every single ID is present without a single skip
      for (var i = 0; i < totalCount; i++) {
        expect(returnedIds.contains('seq-doc-$i'), isTrue,
            reason: 'Document seq-doc-$i must be present');
      }
    });

    // Test 13: Correct monthly totals across multiple pages in AppState.
    test('13. AppState monthly calculation computes accurate totals across >1000 records', () {
      final state = AppState();
      state.householdExpenses.clear();

      final octBase = DateTime(2026, 10, 1);
      for (var i = 0; i < 1200; i++) {
        final date = octBase.add(Duration(minutes: i));
        state.householdExpenses.add(HouseholdExpense(
          id: 'appstate-exp-$i',
          title: 'AppState Item $i',
          category: 'General',
          amount: 25.0,
          createdAt: date,
          expenseDate: date,
        ));
      }

      // 1200 * 25.0 = 30000.0
      expect(state.householdSpendForMonth(2026, 10), 30000.0);
    });
  });
}
