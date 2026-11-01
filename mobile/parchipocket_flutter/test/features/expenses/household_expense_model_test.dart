import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';

void main() {
  group('HouseholdExpense model & serialization', () {
    test('deserializes legacy Firestore document with default values', () {
      final createdDate = DateTime.utc(2026, 10, 15, 14, 30);
      final legacyMap = <String, dynamic>{
        'id': 'exp_legacy_001',
        'title': 'Dahi 500g',
        'category': 'Groceries',
        'amount': 45.0,
        'createdAt': Timestamp.fromDate(createdDate),
        'source': 'manual',
      };

      final expense = HouseholdExpense.fromMap(legacyMap);

      expect(expense.id, 'exp_legacy_001');
      expect(expense.title, 'Dahi 500g');
      expect(expense.category, 'Groceries');
      expect(expense.amount, 45.0);
      expect(expense.createdAt.toUtc(), createdDate);
      expect(expense.source, 'manual');
      expect(expense.expenseDate, isNull);
      expect(expense.isVoided, isFalse);
      expect(expense.voidedAt, isNull);
      expect(expense.voidReason, isNull);
      expect(expense.updatedAt, isNull);
      expect(expense.history, isEmpty);
      expect(expense.effectiveDate.toUtc(), createdDate);
    });

    test('deserializes modern document with all correction and void fields', () {
      final createdDate = DateTime.utc(2026, 10, 10, 9, 0);
      final customExpenseDate = DateTime.utc(2026, 10, 8, 18, 0);
      final updateDate = DateTime.utc(2026, 10, 11, 10, 0);
      final voidDate = DateTime.utc(2026, 10, 12, 12, 0);

      final modernMap = <String, dynamic>{
        'id': 'exp_mod_002',
        'title': 'Atta 10kg',
        'category': 'Groceries',
        'amount': 420.0,
        'createdAt': Timestamp.fromDate(createdDate),
        'source': 'voice',
        'expenseDate': Timestamp.fromDate(customExpenseDate),
        'isVoided': true,
        'voidedAt': Timestamp.fromDate(voidDate),
        'voidReason': 'Accidental duplicate entry',
        'updatedAt': Timestamp.fromDate(updateDate),
        'history': <Map<String, dynamic>>[
          {
            'title': 'Atta 5kg',
            'category': 'Groceries',
            'amount': 210.0,
            'expenseDate': Timestamp.fromDate(DateTime.utc(2026, 10, 8, 17, 0)),
          },
          {
            'title': 'Atta 10kg',
            'category': 'Groceries',
            'amount': 400.0,
            'expenseDate': Timestamp.fromDate(customExpenseDate),
            'modifiedAt': Timestamp.fromDate(updateDate),
          },
        ],
      };

      final expense = HouseholdExpense.fromMap(modernMap);

      expect(expense.id, 'exp_mod_002');
      expect(expense.title, 'Atta 10kg');
      expect(expense.category, 'Groceries');
      expect(expense.amount, 420.0);
      expect(expense.createdAt.toUtc(), createdDate);
      expect(expense.source, 'voice');
      expect(expense.expenseDate!.toUtc(), customExpenseDate);
      expect(expense.effectiveDate.toUtc(), customExpenseDate);
      expect(expense.isVoided, isTrue);
      expect(expense.voidedAt!.toUtc(), voidDate);
      expect(expense.voidReason, 'Accidental duplicate entry');
      expect(expense.updatedAt!.toUtc(), updateDate);
      expect(expense.history.length, 2);

      final snapshot1 = expense.history[0];
      expect(snapshot1.title, 'Atta 5kg');
      expect(snapshot1.amount, 210.0);
      expect(snapshot1.modifiedAt, isNull);

      final snapshot2 = expense.history[1];
      expect(snapshot2.title, 'Atta 10kg');
      expect(snapshot2.amount, 400.0);
      expect(snapshot2.modifiedAt!.toUtc(), updateDate);
    });

    test('parses ISO8601 string dates when timestamps are strings', () {
      final map = <String, dynamic>{
        'id': 'exp_str_003',
        'title': 'Milk',
        'category': 'Groceries',
        'amount': 30,
        'createdAt': '2026-10-20T10:00:00.000Z',
        'expenseDate': '2026-10-19T08:00:00.000Z',
      };

      final expense = HouseholdExpense.fromMap(map);
      expect(expense.createdAt.toUtc(), DateTime.utc(2026, 10, 20, 10));
      expect(expense.expenseDate!.toUtc(), DateTime.utc(2026, 10, 19, 8));
      expect(expense.amount, 30.0);
    });

    test('effectiveDate fallback prefers expenseDate over createdAt', () {
      final createdAt = DateTime.utc(2026, 10, 20);
      final expenseDate = DateTime.utc(2026, 10, 15);

      final withCustom = HouseholdExpense(
        title: 'Vegetables',
        category: 'Groceries',
        amount: 80,
        createdAt: createdAt,
        expenseDate: expenseDate,
      );
      expect(withCustom.effectiveDate, expenseDate);

      final withoutCustom = HouseholdExpense(
        title: 'Vegetables',
        category: 'Groceries',
        amount: 80,
        createdAt: createdAt,
      );
      expect(withoutCustom.effectiveDate, createdAt);
    });

    test('copyWith updates specified fields and retains others', () {
      final original = HouseholdExpense(
        id: 'orig_id',
        title: 'Bread',
        category: 'Groceries',
        amount: 35,
        createdAt: DateTime.utc(2026, 10, 25),
        source: 'manual',
      );

      final updated = original.copyWith(
        title: 'Brown Bread',
        amount: 45,
        isVoided: true,
        voidReason: 'Returned to store',
      );

      expect(updated.id, 'orig_id');
      expect(updated.title, 'Brown Bread');
      expect(updated.category, 'Groceries');
      expect(updated.amount, 45);
      expect(updated.isVoided, isTrue);
      expect(updated.voidReason, 'Returned to store');
      expect(updated.createdAt, original.createdAt);
      expect(updated.source, 'manual');
    });
  });

  group('ExpenseCorrectionSnapshot model & serialization', () {
    test('toMap converts fields and timestamps correctly', () {
      final expenseDate = DateTime.utc(2026, 10, 18, 12);
      final modifiedDate = DateTime.utc(2026, 10, 19, 14);

      final snapshot = ExpenseCorrectionSnapshot(
        title: 'Eggs 6pk',
        category: 'Groceries',
        amount: 48.0,
        expenseDate: expenseDate,
        modifiedAt: modifiedDate,
      );

      final map = snapshot.toMap();
      expect(map['title'], 'Eggs 6pk');
      expect(map['category'], 'Groceries');
      expect(map['amount'], 48.0);
      expect(map['expenseDate'], isA<Timestamp>());
      expect((map['expenseDate'] as Timestamp).toDate().toUtc(), expenseDate);
      expect(map['modifiedAt'], isA<Timestamp>());
      expect((map['modifiedAt'] as Timestamp).toDate().toUtc(), modifiedDate);
    });

    test('toMap omits optional timestamps when null', () {
      const snapshot = ExpenseCorrectionSnapshot(
        title: 'Bus fare',
        category: 'Transport',
        amount: 25.0,
      );

      final map = snapshot.toMap();
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('category'), isTrue);
      expect(map.containsKey('amount'), isTrue);
      expect(map.containsKey('expenseDate'), isFalse);
      expect(map.containsKey('modifiedAt'), isFalse);
    });

    test('supports value equality and hash code', () {
      final date = DateTime.utc(2026, 10, 10);
      final modDate = DateTime.utc(2026, 10, 11);

      final snapA = ExpenseCorrectionSnapshot(
        title: 'Tea',
        category: 'Food',
        amount: 15.0,
        expenseDate: date,
        modifiedAt: modDate,
      );

      final snapB = ExpenseCorrectionSnapshot(
        title: 'Tea',
        category: 'Food',
        amount: 15.0,
        expenseDate: date,
        modifiedAt: modDate,
      );

      final snapC = ExpenseCorrectionSnapshot(
        title: 'Tea',
        category: 'Food',
        amount: 20.0,
        expenseDate: date,
        modifiedAt: modDate,
      );

      expect(snapA, equals(snapB));
      expect(snapA.hashCode, equals(snapB.hashCode));
      expect(snapA, isNot(equals(snapC)));
    });
  });
}
