import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/features/customer/presentation/customer_screens.dart';
import 'package:parchipocket/services/firestore_service.dart';

class _TestUser extends Fake implements User {
  @override
  String get uid => 'network-test-user';
}

class _TestAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _TestUser();
}

class _RetryableExpenseFirestoreService extends FirestoreService {
  int writes = 0;
  bool failNextWrite = true;
  Completer<void>? writeGate;
  final List<HouseholdExpense> attempted = <HouseholdExpense>[];

  @override
  String newHouseholdExpenseId() => 'network-retry-expense';

  @override
  Future<void> addHouseholdExpense(HouseholdExpense expense) async {
    writes++;
    attempted.add(expense);
    await writeGate?.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw const SocketException('Firestore connection unavailable');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Household expense network failure and recovery', () {
    late AppState state;
    late _RetryableExpenseFirestoreService firestore;

    setUp(() {
      firestore = _RetryableExpenseFirestoreService();
      state = AppState()
        ..isDemoMode = false
        ..auth = _TestAuth()
        ..firestoreService = firestore;
      state.householdExpenses.clear();
    });

    tearDown(() => state.dispose());

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'manual',
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> enterPurchase(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Item name'),
        'Fresh tomatoes',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '125',
      );
    }

    testWidgets('failed write preserves entered data and retry recovers',
        (tester) async {
      await open(tester);
      await enterPurchase(tester);
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(firestore.writes, 1);
      expect(state.householdExpenses, isEmpty);
      expect(state.isCloudLoading, isFalse);
      expect(state.cloudError, contains('Firestore connection unavailable'));
      expect(find.textContaining('Firestore connection unavailable'),
          findsOneWidget);
      expect(find.text('Fresh tomatoes'), findsOneWidget);
      expect(find.text('125'), findsOneWidget);

      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(firestore.writes, 2);
      expect(firestore.attempted[0].id, firestore.attempted[1].id);
      expect(state.householdExpenses, hasLength(1));
      expect(state.householdExpenses.single.title, 'Fresh tomatoes');
      expect(state.householdExpenses.single.amount, 125);
      expect(state.cloudError, isNull);
      expect(state.isCloudLoading, isFalse);
    });

    testWidgets('pending write shows loading and blocks duplicate submission',
        (tester) async {
      firestore
        ..failNextWrite = false
        ..writeGate = Completer<void>();
      await open(tester);
      await enterPurchase(tester);
      await tester.tap(find.text('Save purchase'));
      await tester.pump();

      expect(state.isCloudLoading, isTrue);
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.text('Saving…'), warnIfMissed: false);
      await tester.pump();
      expect(firestore.writes, 1);

      firestore.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(state.householdExpenses, hasLength(1));
      expect(state.isCloudLoading, isFalse);
    });
  });
}
