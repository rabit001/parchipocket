import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/auth_screens.dart';
import 'package:parchipocket/screens/customer_screens.dart';
import 'package:parchipocket/services/firestore_service.dart';
import 'package:parchipocket/theme.dart';

const _projectId = 'demo-parchipocket-phase4';
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8088;
const _authPort = 9099;

late FirebaseApp _firebaseApp;
late FirebaseAuth _auth;
late FirebaseFirestore _firestore;
late FirestoreService _service;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 1. Strict isolation check: enforce demo project and local host
    if (!_projectId.startsWith('demo-') || _emulatorHost != '10.0.2.2') {
      throw StateError(
        'Refusing execution: Integration tests must use an isolated demo Firebase project.',
      );
    }

    _firebaseApp = await Firebase.initializeApp(
      name: 'parchipocket-pagination-integration-test',
      options: const FirebaseOptions(
        apiKey: 'fake-emulator-api-key',
        appId: '1:123456789012:android:0123456789abcdef',
        messagingSenderId: '123456789012',
        projectId: _projectId,
      ),
    );

    // Verify project ID explicitly before proceeding
    if (!_firebaseApp.options.projectId.startsWith('demo-')) {
      throw StateError(
        'Safety failure: Initialized project ${_firebaseApp.options.projectId} is not an isolated demo project.',
      );
    }

    _auth = FirebaseAuth.instanceFor(app: _firebaseApp);
    await _auth.useAuthEmulator(_emulatorHost, _authPort);

    _firestore = FirebaseFirestore.instanceFor(app: _firebaseApp);
    _firestore.settings = const Settings(persistenceEnabled: false);
    _firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);

    _service = FirestoreService(firestore: _firestore, auth: _auth);
  });

  tearDownAll(() async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  });

  testWidgets(
    'Daily Log UI pagination loads 50 records, taps "Load older purchases", loads remaining 8, and calculates correct totals',
    (tester) async {
      // 1. Authenticate with ephemeral anonymous user
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      expect(user, isNotNull);
      final uid = user!.uid;
      expect(uid, isNotEmpty);
      debugPrint('=== STEP 1: Authenticated with demo emulator UID: $uid');

      // 2. Seed profile and 58 household expenses
      await _seedTestData(_firestore, _service, uid);
      debugPrint('=== STEP 2: Seeded profile and 58 records (3 current month, 55 previous month)');

      // 3. Initialize AppState connected to the isolated demo emulator
      final state = AppState(auth: _auth)..firestoreService = _service;

      // 4. Pump the test application UI
      await tester.pumpWidget(
        MaterialApp(
          title: 'ParchiPocket Test',
          debugShowCheckedModeBanner: false,
          theme: buildPpTheme(),
          home: AnimatedBuilder(
            animation: state,
            builder: (context, _) => switch (state.page) {
              'authLoading' => AuthSessionLoadingScreen(state: state),
              'customerHome' => CustomerHomeScreen(state: state),
              'householdExpenses' => HouseholdExpensesScreen(state: state),
              _ => Scaffold(body: Center(child: Text('Page: ${state.page}'))),
            },
          ),
        ),
      );

      // 5. Wait for auth and initial cloud data to load
      var waitCycles = 0;
      while (state.page == 'authLoading' && waitCycles < 100) {
        await tester.pump(const Duration(milliseconds: 100));
        waitCycles++;
      }
      await tester.pumpAndSettle();
      expect(state.page, 'customerHome');
      debugPrint('=== STEP 3: Loaded customerHome page');

      // 6. Verify CustomerHomeScreen current-month totals (Requirement 10)
      // 3 current-month expenses: 100 + 200 + 300 = ₹600.
      expect(find.text('₹600'), findsAtLeast(1));
      expect(find.text('Across your household · 3 purchases'), findsOneWidget);
      debugPrint('=== STEP 4: Verified dashboard totals: ₹600 across 3 current-month purchases');

      // 7. Navigate to Daily Log (HouseholdExpensesScreen)
      state.go('householdExpenses');
      await tester.pumpAndSettle();
      expect(state.page, 'householdExpenses');
      debugPrint('=== STEP 5: Navigated to Daily Log (HouseholdExpensesScreen)');

      // 8. Verify initial 50 records in Daily Log (Requirement 2)
      expect(state.householdExpenses.length, 50);
      expect(find.text('50 purchase entries'), findsOneWidget);
      expect(state.hasMoreHouseholdExpenses, isTrue);
      debugPrint('=== STEP 6: Verified initial page: exactly 50 records displayed');

      // 9. Verify "Load older purchases" button is visible (Requirement 3)
      final loadOlderFinder = find.widgetWithText(TextButton, 'Load older purchases');
      await tester.scrollUntilVisible(
        loadOlderFinder,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(loadOlderFinder, findsOneWidget);
      debugPrint('=== STEP 7: Verified "Load older purchases" button is visible and scrolled into view');

      // 10. Tap "Load older purchases" (Requirement 4)
      await tester.tap(loadOlderFinder);
      await tester.pumpAndSettle();
      debugPrint('=== STEP 8: Tapped "Load older purchases"');

      // 11. Verify all 58 records loaded (Requirements 5 & 6)
      expect(state.householdExpenses.length, 58);
      // Scroll back up to top to check metric card with 58 purchase entries
      await tester.scrollUntilVisible(
        find.text('58 purchase entries'),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('58 purchase entries'), findsOneWidget);
      // Total recorded spending: 600 (curr) + 55 * 50 (prev) = 3350 -> ₹3350
      expect(find.text('₹3350'), findsOneWidget);
      debugPrint('=== STEP 9: Verified all 58 records loaded and recorded spend is ₹3350');

      // 12. Verify no duplicate IDs (Requirement 7)
      final allIds = state.householdExpenses.map((e) => e.id).toList();
      expect(allIds.toSet().length, 58);
      debugPrint('=== STEP 10: Verified 0 duplicate IDs among all 58 records');

      // 13. Verify descending chronological order (Requirement 8)
      for (var i = 0; i < state.householdExpenses.length - 1; i++) {
        final current = state.householdExpenses[i];
        final next = state.householdExpenses[i + 1];
        expect(
          current.createdAt.isAfter(next.createdAt) ||
              current.createdAt.isAtSameMomentAs(next.createdAt),
          isTrue,
          reason: 'Order violation: item $i (${current.createdAt}) is before item ${i + 1} (${next.createdAt})',
        );
      }
      debugPrint('=== STEP 11: Verified descending chronological order across all 58 records');

      // 14. Verify pagination button disappeared (Requirement 9)
      // Scroll to the oldest item at the bottom of the list
      await tester.scrollUntilVisible(
        find.text('Past Expense 01'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Load older purchases'), findsNothing);
      expect(state.hasMoreHouseholdExpenses, isFalse);
      debugPrint('=== STEP 12: Verified pagination button disappeared (hasMoreHouseholdExpenses is false)');

      // 15. Sign out the ephemeral user
      await _auth.signOut();
      debugPrint('=== STEP 13: Signed out demo emulator user $uid');

      state.dispose();
    },
  );

  testWidgets(
    'Daily Log UI expense editing and voiding flows update ledger and audit history correctly',
    (tester) async {
      // 1. Authenticate with ephemeral anonymous user
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      expect(user, isNotNull);
      final uid = user!.uid;
      expect(uid, isNotEmpty);
      debugPrint('=== STEP 1: Authenticated with demo emulator UID: $uid');

      // 2. Seed profile and 2 household expenses
      await _seedEditVoidTestData(_firestore, _service, uid);
      debugPrint('=== STEP 2: Seeded profile and 2 records');

      // 3. Initialize AppState connected to the isolated demo emulator
      final state = AppState(auth: _auth)..firestoreService = _service;

      // 4. Pump the test application UI
      await tester.pumpWidget(
        MaterialApp(
          title: 'ParchiPocket Test',
          debugShowCheckedModeBanner: false,
          theme: buildPpTheme(),
          home: AnimatedBuilder(
            animation: state,
            builder: (context, _) => switch (state.page) {
              'authLoading' => AuthSessionLoadingScreen(state: state),
              'customerHome' => CustomerHomeScreen(state: state),
              'householdExpenses' => HouseholdExpensesScreen(state: state),
              _ => Scaffold(body: Center(child: Text('Page: ${state.page}'))),
            },
          ),
        ),
      );

      // 5. Wait for auth and initial cloud data to load
      var waitCycles = 0;
      while (state.page == 'authLoading' && waitCycles < 100) {
        await tester.pump(const Duration(milliseconds: 100));
        waitCycles++;
      }
      await tester.pumpAndSettle();
      expect(state.page, 'customerHome');
      debugPrint('=== STEP 3: Loaded customerHome page');

      // Initial monthly total: 150 + 220 = ₹370 across 2 purchases
      expect(find.text('₹370'), findsAtLeast(1));
      expect(find.text('Across your household · 2 purchases'), findsOneWidget);

      // 6. Navigate to Daily Log (HouseholdExpensesScreen)
      state.go('householdExpenses');
      await tester.pumpAndSettle();
      expect(state.page, 'householdExpenses');
      expect(find.text('2 purchase entries'), findsOneWidget);
      expect(find.text('₹370'), findsOneWidget);
      debugPrint('=== STEP 4: Navigated to Daily Log with 2 records totaling ₹370');

      // 7. Edit an expense through the actual Daily Log UI:
      // Tap on 'Fresh Mangoes'
      await tester.tap(find.text('Fresh Mangoes'));
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdExpenseDetailDialog), findsOneWidget);

      // Tap Edit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(EditHouseholdExpenseDialog), findsOneWidget);

      // Change title to 'Organic Alphonso Mangoes' and amount to '250'
      await tester.enterText(
          find.widgetWithText(TextField, 'Fresh Mangoes'), 'Organic Alphonso Mangoes');
      await tester.enterText(
          find.widgetWithText(TextField, '150'), '250');
      await tester.pumpAndSettle();

      // Tap Save changes
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      debugPrint('=== STEP 5: Saved edited expense (amount 150 -> 250)');

      // 8. Verify changed amount and correction history in Daily Log UI
      expect(find.text('Organic Alphonso Mangoes'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      // Daily log metric card total should now be 250 + 220 = ₹470
      expect(find.text('₹470'), findsOneWidget);

      // Open detail dialog to verify correction history
      await tester.tap(find.text('Organic Alphonso Mangoes'));
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdExpenseDetailDialog), findsOneWidget);
      expect(find.text('Correction History (1)'), findsOneWidget);
      expect(find.text('Version 1: Fresh Mangoes'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      debugPrint('=== STEP 6: Verified updated amount and correction history in UI');

      // 9. Void an expense through the actual UI:
      // The second entry may be below the ListView's lazy build viewport.
      final laundryExpenseFinder = find.text('Laundry Detergent');
      await tester.scrollUntilVisible(
        laundryExpenseFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(laundryExpenseFinder);
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdExpenseDetailDialog), findsOneWidget);

      // Tap Void
      await tester.tap(find.widgetWithText(TextButton, 'Void'));
      await tester.pumpAndSettle();
      expect(find.byType(VoidExpenseConfirmationDialog), findsOneWidget);

      // Enter optional void reason
      await tester.enterText(
          find.widgetWithText(TextField, 'Reason for voiding (optional)'),
          'Duplicate purchase');
      await tester.pumpAndSettle();

      // Confirm void
      await tester.tap(find.widgetWithText(ElevatedButton, 'Void Expense'));
      await tester.pumpAndSettle();
      debugPrint('=== STEP 7: Voided expense through UI with reason');

      // 10. Verify voided expense disappears from active entries and totals
      expect(find.text('Laundry Detergent'), findsNothing);
      expect(find.text('1 purchase entries'), findsOneWidget);
      // Total in Daily Log is now only ₹250
      expect(find.text('₹250'), findsNWidgets(2)); // metric card + tile

      // Customer home totals updated too
      state.go('customerHome');
      await tester.pumpAndSettle();
      expect(find.text('Across your household · 1 purchases'), findsOneWidget);
      debugPrint('=== STEP 8: Verified voided expense removed from active entries and totals updated');

      // 11. Navigate back to Daily Log and test "Show voided entries" toggle
      state.go('householdExpenses');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show voided entries'));
      await tester.pumpAndSettle();

      // Voided expense is now visible with voided indicator
      expect(find.text('Laundry Detergent'), findsOneWidget);
      expect(find.text('Showing voided'), findsOneWidget);
      expect(find.text('1 purchase entries · 1 voided'), findsOneWidget);

      // Open detail dialog of the voided expense. It can be below the viewport.
      final voidedLaundryExpenseFinder = find.text('Laundry Detergent');
      await tester.scrollUntilVisible(
        voidedLaundryExpenseFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(voidedLaundryExpenseFinder);
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdExpenseDetailDialog), findsOneWidget);
      expect(find.text('VOIDED'), findsOneWidget);
      expect(find.text('Reason: Duplicate purchase'), findsOneWidget);

      // Confirm voided expense cannot be edited or voided again
      expect(find.widgetWithText(ElevatedButton, 'Edit'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Void'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      debugPrint('=== STEP 9: Verified voided expense toggle and immutable void state in UI');

      // 12. Sign out and cleanup
      await _auth.signOut();
      state.dispose();
      debugPrint('=== STEP 10: Cleaned up and signed out user $uid');
    },
  );
}

Future<void> _seedTestData(
  FirebaseFirestore firestore,
  FirestoreService service,
  String uid,
) async {
  // Save customer profile
  await service.saveUserProfile(
    role: UserRole.customer,
    name: 'Emulator Customer',
    email: '',
    city: 'Mumbai',
    shopName: '',
    shopCategory: '',
    shopAddress: '',
    vendorName: '',
    vendorCategory: '',
  );

  final now = DateTime.now();

  // 3 records in current calendar month
  final currentMonthRecords = <Map<String, dynamic>>[
    {
      'id': 'exp-curr-01',
      'title': 'Current Groceries A',
      'category': 'Groceries',
      'amount': 100.0,
      'createdAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day, 12, 0)),
      'source': 'manual',
    },
    {
      'id': 'exp-curr-02',
      'title': 'Current Groceries B',
      'category': 'Groceries',
      'amount': 200.0,
      'createdAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day, 11, 0)),
      'source': 'manual',
    },
    {
      'id': 'exp-curr-03',
      'title': 'Current Groceries C',
      'category': 'Groceries',
      'amount': 300.0,
      'createdAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day, 10, 0)),
      'source': 'manual',
    },
  ];

  // 55 records in immediately preceding calendar month
  final startOfCurrentMonth = DateTime(now.year, now.month, 1);
  final endOfPrevMonth = startOfCurrentMonth.subtract(const Duration(minutes: 1));

  final prevMonthRecords = <Map<String, dynamic>>[];
  for (var i = 1; i <= 55; i++) {
    final recordDate = endOfPrevMonth.subtract(Duration(hours: i));
    final idNum = i.toString().padLeft(2, '0');
    prevMonthRecords.add({
      'id': 'exp-prev-$idNum',
      'title': 'Past Expense $idNum',
      'category': 'Other',
      'amount': 50.0,
      'createdAt': Timestamp.fromDate(recordDate),
      'source': 'manual',
    });
  }

  final allRecords = [...currentMonthRecords, ...prevMonthRecords];

  final batch = firestore.batch();
  final collection = firestore.collection('users').doc(uid).collection('householdExpenses');
  for (final data in allRecords) {
    batch.set(collection.doc(data['id'] as String), data);
  }
  await batch.commit();
}

Future<void> _seedEditVoidTestData(
  FirebaseFirestore firestore,
  FirestoreService service,
  String uid,
) async {
  await service.saveUserProfile(
    role: UserRole.customer,
    name: 'Emulator Customer',
    email: '',
    city: 'Mumbai',
    shopName: '',
    shopCategory: '',
    shopAddress: '',
    vendorName: '',
    vendorCategory: '',
  );

  final now = DateTime.now();
  final collection = firestore.collection('users').doc(uid).collection('householdExpenses');

  await collection.doc('exp-edit-01').set({
    'id': 'exp-edit-01',
    'title': 'Fresh Mangoes',
    'category': 'Groceries',
    'amount': 150.0,
    'createdAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day, 10, 0)),
    'source': 'manual',
  });

  await collection.doc('exp-void-02').set({
    'id': 'exp-void-02',
    'title': 'Laundry Detergent',
    'category': 'Household',
    'amount': 220.0,
    'createdAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day, 9, 0)),
    'source': 'manual',
  });
}
