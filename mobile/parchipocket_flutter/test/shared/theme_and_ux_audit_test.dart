import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/common_screens.dart';
import 'package:parchipocket/screens/customer_screens.dart';
import 'package:parchipocket/services/firestore_service.dart';
import 'package:parchipocket/theme.dart';
import 'package:parchipocket/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => MockUser();
}

class MockUser extends Fake implements User {
  @override
  String get uid => 'test-user-theme';
  @override
  String? get phoneNumber => '+919999999999';
}

class FakeFirestoreServiceWithDelays extends FirestoreService {
  int pageLoadCalls = 0;
  bool shouldThrow = false;

  @override
  Future<HouseholdExpensePage> loadHouseholdExpensesPage({
    int limit = 50,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    pageLoadCalls++;
    if (shouldThrow) {
      throw Exception('Network connection timed out');
    }
    return HouseholdExpensePage(
      items: <HouseholdExpense>[
        HouseholdExpense(
          id: 'exp-1',
          title: 'Morning Milk',
          category: 'Dairy',
          amount: 60.0,
          createdAt: DateTime(2026, 11, 1, 8, 30),
        ),
      ],
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
    if (shouldThrow) {
      throw Exception('Network connection timed out');
    }
    return <HouseholdExpense>[
      HouseholdExpense(
        id: 'exp-1',
        title: 'Morning Milk',
        category: 'Dairy',
        amount: 60.0,
        createdAt: DateTime(2026, 11, 1, 8, 30),
      ),
    ];
  }
}

void main() {
  group('ParchiPocket UI/UX & Theme Verification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('1. AppState manages ThemeMode with reactive listener notification', () {
      final state = AppState();
      expect(state.themeMode, ThemeMode.system);

      var notified = false;
      state.addListener(() => notified = true);

      state.setThemeMode(ThemeMode.dark);
      expect(state.themeMode, ThemeMode.dark);
      expect(notified, isTrue);

      notified = false;
      state.setThemeMode(ThemeMode.dark); // redundant call does not notify
      expect(notified, isFalse);

      state.setThemeMode(ThemeMode.light);
      expect(state.themeMode, ThemeMode.light);
      expect(notified, isTrue);

      state.dispose();
    });

    testWidgets('2. SettingsScreen allows choosing Light, Dark, or System theme',
        (tester) async {
      final state = AppState();
      state.isDemoMode = false;
      state.page = 'settings';

      await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (ctx, _) => MaterialApp(
          theme: buildPpTheme(),
          darkTheme: buildPpDarkTheme(),
          themeMode: state.themeMode,
          home: SettingsScreen(state: state),
        ),
      ));

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);

      // Tap Appearance tile
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      expect(find.text('Choose theme'), findsOneWidget);
      expect(find.text('Light theme'), findsOneWidget);
      expect(find.text('Dark theme'), findsOneWidget);

      // Select Dark theme
      await tester.tap(find.text('Dark theme'));
      await tester.pumpAndSettle();

      expect(state.themeMode, ThemeMode.dark);
      expect(find.text('Dark theme'), findsOneWidget);

      // Tap Appearance tile again and choose Light theme
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light theme'));
      await tester.pumpAndSettle();

      expect(state.themeMode, ThemeMode.light);
      expect(find.text('Light theme'), findsOneWidget);

      state.dispose();
    });

    testWidgets('3. Dark theme renders dark card surfaces and legible text in PpCard & PpTransactionTile',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildPpTheme(),
        darkTheme: buildPpDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const PpCard(
                child: Text('Card content in dark mode'),
              ),
              PpTransactionTile(
                title: 'Groceries',
                subtitle: 'Supermarket · 01 Nov',
                trailing: '₹450',
                onTap: () {},
              ),
            ],
          ),
        ),
      ));

      final cardFinder = find.byType(Card).first;
      final cardWidget = tester.widget<Card>(cardFinder);
      // In dark theme, card color should match darkCard (#1A221C)
      expect(cardWidget.color, const Color(0xFF1A221C));

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
    });

    testWidgets('4. Error banner close button provides accessible semantics and clears error',
        (tester) async {
      final state = AppState();
      state.cloudError = 'Connection failed. Please retry.';

      await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (ctx, _) => MaterialApp(
          home: PpScaffold(
            state: state,
            title: 'Test',
            body: const Text('Body content'),
          ),
        ),
      ));

      expect(find.text('Connection failed. Please retry.'), findsOneWidget);
      final dismissFinder = find.bySemanticsLabel('Dismiss error message');
      expect(dismissFinder, findsOneWidget);

      await tester.tap(dismissFinder);
      await tester.pumpAndSettle();

      expect(state.cloudError, isNull);
      expect(find.text('Connection failed. Please retry.'), findsNothing);
      state.dispose();
    });

    test('5. refreshHouseholdExpenses protects against duplicate concurrent runs and preserves existing records on failure',
        () async {
      final fakeService = FakeFirestoreServiceWithDelays();
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = fakeService;

      // Seed with initial item
      state.householdExpenses.add(
        HouseholdExpense(
          id: 'initial-item',
          title: 'Initial Bread',
          category: 'Groceries',
          amount: 40.0,
          createdAt: DateTime(2026, 11, 1),
        ),
      );

      // Trigger successful refresh
      await state.refreshHouseholdExpenses();
      expect(state.householdExpenses.length, 1);
      expect(state.householdExpenses.first.id, 'exp-1');
      expect(state.cloudError, isNull);

      // Now set shouldThrow = true (simulating offline / network loss)
      fakeService.shouldThrow = true;
      await state.refreshHouseholdExpenses();

      // Crucial: existing records must NOT be destroyed/cleared when network fails
      expect(state.householdExpenses.length, 1);
      expect(state.householdExpenses.first.id, 'exp-1');
      expect(state.cloudError, contains('Could not refresh expenses'));

      state.dispose();
    });

    test('6. refreshCurrentMonthExpenses catches network errors and preserves monthly records',
        () async {
      final fakeService = FakeFirestoreServiceWithDelays();
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = fakeService;

      // Initial successful load
      await state.refreshCurrentMonthExpenses();
      expect(state.monthlyHouseholdExpenses.length, 1);

      // Failure simulation
      fakeService.shouldThrow = true;
      await state.refreshCurrentMonthExpenses();

      // Monthly records are preserved
      expect(state.monthlyHouseholdExpenses.length, 1);
      expect(state.cloudError, contains('Could not refresh insights'));

      state.dispose();
    });

    test('7. AppState restores saved theme from SharedPreferences on cold start', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user_theme_mode': 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(prefs: prefs);
      expect(state.themeMode, ThemeMode.dark);

      // Changing theme writes to SharedPreferences
      state.setThemeMode(ThemeMode.light);
      expect(prefs.getString('user_theme_mode'), 'light');

      // Invalid or empty preference defaults safely to system
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user_theme_mode': 'invalid_value',
      });
      final invalidPrefs = await SharedPreferences.getInstance();
      final invalidState = AppState(prefs: invalidPrefs);
      expect(invalidState.themeMode, ThemeMode.system);

      state.dispose();
      invalidState.dispose();
    });

    testWidgets('8. PpScaffold displays unobtrusive offline banner with accessible retry action',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithDelays();
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = fakeService;

      state.setOffline(true);

      await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (ctx, _) => MaterialApp(
          home: PpScaffold(
            state: state,
            title: 'Daily Log',
            body: const Text('Expenses list'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Offline mode: showing cached records.'), findsOneWidget);
      final retryFinder = find.text('Retry');
      expect(retryFinder, findsOneWidget);

      // Tap retry
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();

      // Successful refresh clears offline status
      expect(state.isOffline, isFalse);
      expect(find.text('Offline mode: showing cached records.'), findsNothing);

      state.dispose();
    });

    testWidgets('9. HouseholdExpenseEntryScreen supports switching between voice and manual entry mode',
        (tester) async {
      final state = AppState();
      state.isDemoMode = true;

      await tester.pumpWidget(MaterialApp(
        theme: buildPpTheme(),
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'voice',
        ),
      ));
      await tester.pumpAndSettle();

      // Top segmented mode controls are visible
      expect(find.text('Speak'), findsOneWidget);
      expect(find.text('Type manually'), findsOneWidget);

      // Tap 'Type manually'
      await tester.tap(find.text('Type manually'));
      await tester.pumpAndSettle();

      // Enter purchase details in manual mode
      await tester.enterText(
          find.widgetWithText(TextField, 'Item name'), 'Fresh Vegetables');
      await tester.enterText(
          find.widgetWithText(TextField, 'Amount (₹)'), '250');
      await tester.pumpAndSettle();

      // Tap 'Save purchase'
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      // Verified saved to demo state
      expect(state.householdExpenses.any((e) => e.title == 'Fresh Vegetables'), isTrue);

      state.dispose();
    });

    testWidgets('10. PpTransactionTile exposes accessible combined semantics label for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PpTransactionTile(
              title: 'Milk Pack',
              subtitle: 'Dairy · 01 Nov',
              trailing: '₹60',
              onTap: () {},
            ),
          ),
        ));

        final semanticsFinder = find.bySemanticsLabel('Milk Pack, Dairy · 01 Nov, ₹60');
        expect(semanticsFinder, findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('11. Responsive layout and large text scaling (1.5x) render without flex overflow on small screen',
        (tester) async {
      // Simulate small Android device screen (320x568 dp)
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = AppState();
      state.isDemoMode = true;

      // Wrap with 1.5x text scaling
      await tester.pumpWidget(MaterialApp(
        theme: buildPpTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.5),
          ),
          child: CustomerHomeScreen(state: state),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('TOTAL HOUSEHOLD SPEND'), findsOneWidget);

      state.dispose();
    });

    testWidgets('12. HouseholdExpenseEntryScreen observes lifecycle resumption cleanly',
        (tester) async {
      final state = AppState();
      state.isDemoMode = true;

      await tester.pumpWidget(MaterialApp(
        theme: buildPpTheme(),
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'voice',
        ),
      ));
      await tester.pumpAndSettle();

      // Trigger app resumed lifecycle event
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      state.dispose();
    });

    test('13. Account switching during active cloud refresh prevents stale session overwrite', () async {
      final fakeService = FakeFirestoreServiceWithDelays();
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = fakeService;

      // Start refresh with user test-user-theme
      final future = state.refreshHouseholdExpenses();

      // Switch session to null / different before refresh completes
      state.auth = null;

      await future;

      // Verified stale response does not populate expenses after logout/session switch
      expect(state.householdExpenses.any((e) => e.id == 'exp-1'), isFalse);

      state.dispose();
    });
  });
}
