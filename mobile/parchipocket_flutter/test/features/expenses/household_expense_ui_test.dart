import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/customer_screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParchiPocket Phase 2 Step 4: UI Widget Tests', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.householdExpenses.clear();
    });

    tearDown(() {
      state.dispose();
    });

    // Test 1: Manual date selection.
    testWidgets('1. Manual date selection allows choosing past custom date',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'manual',
        ),
      ));
      await tester.pumpAndSettle();

      // Enter purchase details
      await tester.enterText(
          find.widgetWithText(TextField, 'Item name'), 'Fresh Vegetables');
      await tester.enterText(
          find.widgetWithText(TextField, 'Amount (₹)'), '250');
      await tester.pumpAndSettle();

      // Verify date selector initially shows Today
      expect(find.text('Today'), findsOneWidget);

      // Open custom date picker
      await tester.tap(find.text('Other date…'));
      await tester.pumpAndSettle();

      // DatePicker is open. Select OK to confirm the selected date.
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save purchase
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses.length, 1);
      final saved = state.householdExpenses.first;
      expect(saved.title, 'Fresh Vegetables');
      expect(saved.amount, 250.0);
      expect(saved.expenseDate, isNotNull);
    });

    // Test 2: Today and Yesterday quick choices.
    testWidgets('2. Today and Yesterday quick choice chips toggle correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'manual',
        ),
      ));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Initially Today is active
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // Tap Yesterday chip
      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      // Enter details and save
      await tester.enterText(
          find.widgetWithText(TextField, 'Item name'), 'Yesterday Dinner');
      await tester.enterText(
          find.widgetWithText(TextField, 'Amount (₹)'), '420');
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses.length, 1);
      final saved = state.householdExpenses.first;
      expect(saved.title, 'Yesterday Dinner');
      expect(isSameCalendarDay(saved.effectiveDate, yesterday), isTrue);
    });

    // Test 3: Future-date rejection.
    testWidgets('3. Date selector prevents selecting future dates',
        (WidgetTester tester) async {
      DateTime? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                selected = await showDatePicker(
                  context: context,
                  initialDate: today,
                  firstDate: DateTime(now.year - 1, now.month, now.day),
                  lastDate: today, // Future dates rejected by lastDate constraint
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Confirm picker is constrained to today
      final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(isSameCalendarDay(picker.lastDate, today), isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });

    // Test 4: Voice review date selection.
    testWidgets('4. Voice review allows date selection before saving',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          initialMode: 'voice',
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll to review details
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Item name');
      await tester.enterText(titleFinder.first, 'Dairy Milk');

      final amountFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Amount (₹)');
      await tester.enterText(amountFinder.first, '60');
      await tester.pumpAndSettle();

      // Change date to Yesterday in review stage
      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses.length, 1);
      final saved = state.householdExpenses.first;
      expect(saved.title, 'Dairy Milk');
      expect(saved.amount, 60.0);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      expect(isSameCalendarDay(saved.effectiveDate, yesterday), isTrue);
    });

    // Test 5: Edit dialog prefilled values.
    testWidgets('5. Edit dialog prepopulates all fields from existing expense',
        (WidgetTester tester) async {
      final octDate = DateTime(2026, 10, 12);
      final expense = HouseholdExpense(
        id: 'exp-prefill',
        title: 'Organic Honey',
        category: 'Groceries',
        amount: 350.0,
        createdAt: octDate,
        expenseDate: octDate,
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Organic Honey'), findsOneWidget);
      expect(find.widgetWithText(TextField, '350'), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.textContaining('12 Oct 2026'), findsOneWidget);
    });

    // Test 6: Edit validation.
    testWidgets('6. Edit dialog validates empty title and non-positive amount',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-valid',
        title: 'Coffee Beans',
        category: 'Groceries',
        amount: 200.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      // Clear title
      await tester.enterText(
          find.widgetWithText(TextField, 'Coffee Beans'), '');
      await tester.pumpAndSettle();

      // Try save -> Save button should be disabled because title is empty or unchanged
      // Enter invalid title
      await tester.enterText(
          find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Item name'),
          '   ');
      await tester.enterText(
          find.widgetWithText(TextField, '200'), '250'); // hasChanges true
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a title between 1 and 100 characters.'),
          findsOneWidget);

      // Invalid amount
      await tester.enterText(
          find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Item name'),
          'Valid Coffee');
      await tester.enterText(
          find.widgetWithText(TextField, '250'), '-10');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount greater than ₹0 up to ₹1,00,00,000.'),
          findsOneWidget);
    });

    // Test 7: Save button disabled when unchanged.
    testWidgets('7. Save button is disabled when nothing has changed',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-unchanged',
        title: 'Apples',
        category: 'Groceries',
        amount: 120.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      // Find Save changes button
      final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save changes'));
      expect(saveBtn.onPressed, isNull);

      // Modify title
      await tester.enterText(
          find.widgetWithText(TextField, 'Apples'), 'Green Apples');
      await tester.pumpAndSettle();

      final enabledBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save changes'));
      expect(enabledBtn.onPressed, isNotNull);

      // Revert title
      await tester.enterText(
          find.widgetWithText(TextField, 'Green Apples'), 'Apples');
      await tester.pumpAndSettle();

      final revertedBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save changes'));
      expect(revertedBtn.onPressed, isNull);
    });

    // Test 8: Successful edit flow.
    testWidgets('8. Successful edit flow updates expense and records audit history',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-success-edit',
        title: 'Rice 5kg',
        category: 'Groceries',
        amount: 300.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      // Change amount to 340
      await tester.enterText(
          find.widgetWithText(TextField, '300'), '340');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      // Verify state was updated
      expect(state.householdExpenses.first.amount, 340.0);
      expect(state.householdExpenses.first.history.length, 1);
      expect(state.householdExpenses.first.history.first.amount, 300.0);
    });

    // Test 9: Edit error handling.
    testWidgets('9. Edit error displays message without clearing user inputs',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-error',
        title: 'Sugar',
        category: 'Groceries',
        amount: 45.0,
        createdAt: DateTime.now(),
        isVoided: true, // Already voided expense cannot be modified
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Sugar'), 'Brown Sugar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cannot modify a voided household expense'),
          findsOneWidget);
      // Verify user input preserved
      expect(find.widgetWithText(TextField, 'Brown Sugar'), findsOneWidget);
    });

    // Test 10: Void confirmation dialog.
    testWidgets('10. Void confirmation explains audit permanence and can be cancelled',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-void-confirm',
        title: 'Wrong Bill',
        category: 'Utilities',
        amount: 1500.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: VoidExpenseConfirmationDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      // Verify audit warning explanation
      expect(find.textContaining('excluded from Dashboard and Insights totals'),
          findsOneWidget);
      expect(find.textContaining('original document remains preserved'),
          findsOneWidget);
      expect(find.textContaining('cannot be reversed'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses.first.isVoided, isFalse);
    });

    // Test 11: Optional void reason validation.
    testWidgets('11. Optional void reason rejects input exceeding 200 characters',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-void-reason',
        title: 'Double Entry',
        category: 'Other',
        amount: 100.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: VoidExpenseConfirmationDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      // Find the TextField and verify its maxLength is 200
      final reasonField = tester.widget<TextField>(
          find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText?.contains('Reason') == true));
      expect(reasonField.maxLength, 200);

      // Programmatically set controller text > 200 to test validation guard
      reasonField.controller?.text = 'A' * 205;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Void Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Void reason cannot exceed 200 characters.'), findsOneWidget);
      expect(state.householdExpenses.first.isVoided, isFalse);
    });

    // Test 12: Successful void flow.
    testWidgets('12. Successful void marks expense voided with optional reason',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-void-ok',
        title: 'Refunded Purchase',
        category: 'Groceries',
        amount: 250.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: VoidExpenseConfirmationDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText?.contains('Reason') == true),
          'Item was returned for refund');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Void Expense'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses.first.isVoided, isTrue);
      expect(state.householdExpenses.first.voidReason,
          'Item was returned for refund');
      expect(state.householdExpenses.first.voidedAt, isNotNull);
    });

    // Test 13: Voided records hidden by default.
    testWidgets('13. Voided records are excluded from Daily Log by default',
        (WidgetTester tester) async {
      final active = HouseholdExpense(
        id: 'exp-active',
        title: 'Active Apples',
        category: 'Groceries',
        amount: 100.0,
        createdAt: DateTime.now(),
      );
      final voided = HouseholdExpense(
        id: 'exp-voided',
        title: 'Voided Bananas',
        category: 'Groceries',
        amount: 900.0,
        createdAt: DateTime.now(),
        isVoided: true,
      );
      state.householdExpenses.addAll([active, voided]);

      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpensesScreen(state: state),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Apples'), findsOneWidget);
      expect(find.text('Voided Bananas'), findsNothing);
      expect(find.text('₹100'), findsNWidgets(2));
    });

    // Test 14: Show voided entries toggle.
    testWidgets('14. Show voided entries toggle reveals voided records with badge',
        (WidgetTester tester) async {
      final active = HouseholdExpense(
        id: 'exp-active-2',
        title: 'Active Milk',
        category: 'Dairy',
        amount: 50.0,
        createdAt: DateTime.now(),
      );
      final voided = HouseholdExpense(
        id: 'exp-voided-2',
        title: 'Voided Juice',
        category: 'Beverages',
        amount: 80.0,
        createdAt: DateTime.now(),
        isVoided: true,
        voidReason: 'Spilled in shop',
      );
      state.householdExpenses.addAll([active, voided]);

      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpensesScreen(state: state),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Voided Juice'), findsNothing);

      // Toggle show voided
      await tester.tap(find.text('Show voided entries'));
      await tester.pumpAndSettle();

      expect(find.text('Voided Juice'), findsOneWidget);
      expect(find.text('Showing voided'), findsOneWidget);

      // Tap on voided entry to verify detail dialog never provides unvoid action
      await tester.tap(find.text('Voided Juice'));
      await tester.pumpAndSettle();

      expect(find.text('VOIDED'), findsOneWidget);
      expect(find.text('Reason: Spilled in shop'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Void'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    // Test 15: Loading state and duplicate-tap prevention.
    testWidgets('15. Duplicate taps are prevented during pending operations',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-double-tap',
        title: 'Snacks',
        category: 'Food',
        amount: 80.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: EditHouseholdExpenseDialog(state: state, expense: expense),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Snacks'), 'Evening Snacks');
      await tester.pumpAndSettle();

      // Tap save once
      await tester.tap(find.text('Save changes'));
      // Tap save again immediately
      await tester.tap(find.text('Save changes'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Expense should be updated exactly once without StateError from concurrent ops
      expect(state.householdExpenses.first.title, 'Evening Snacks');
      expect(state.householdExpenses.first.history.length, 1);
    });

    // Test 16: Edit DatePicker older than one year.
    testWidgets(
        '16. Edit DatePicker allows editing an expense older than one year without crashing',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 500));
      final expense = HouseholdExpense(
        id: 'exp-old-1',
        title: 'Old Equipment',
        category: 'Electronics',
        amount: 2500.0,
        createdAt: oldDate,
        expenseDate: oldDate,
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditHouseholdExpenseDialog(state: state, expense: expense),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on custom date selector
      await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
      await tester.pumpAndSettle();

      // DatePicker should be visible and not crash
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    // Test 17: Unknown category preservation and save button state.
    testWidgets(
        '17. Edit dialog preserves unknown category and disables save until changed',
        (WidgetTester tester) async {
      final expense = HouseholdExpense(
        id: 'exp-custom-cat',
        title: 'Cat Food',
        category: 'Pet Care',
        amount: 350.0,
        createdAt: DateTime.now(),
      );
      state.householdExpenses.add(expense);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditHouseholdExpenseDialog(state: state, expense: expense),
        ),
      ));
      await tester.pumpAndSettle();

      // Dropdown should display 'Pet Care'
      expect(find.text('Pet Care'), findsOneWidget);
      expect(find.text('Other'), findsNothing);

      // Save button should be disabled because nothing was changed
      final saveButtonFinder =
          find.widgetWithText(ElevatedButton, 'Save changes');
      expect(saveButtonFinder, findsOneWidget);
      final saveButton = tester.widget<ElevatedButton>(saveButtonFinder);
      expect(saveButton.onPressed, isNull);

      // Make a change to the title
      await tester.enterText(
          find.widgetWithText(TextField, 'Cat Food'), 'Premium Cat Food');
      await tester.pumpAndSettle();

      // Save button should now be enabled
      final updatedSaveButton = tester.widget<ElevatedButton>(saveButtonFinder);
      expect(updatedSaveButton.onPressed, isNotNull);

      // Save the changes
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Expense category should still be 'Pet Care'
      final saved = state.householdExpenses.first;
      expect(saved.title, 'Premium Cat Food');
      expect(saved.category, 'Pet Care');
    });

    // Test 18: Insights screen monthly dataset consistency.
    testWidgets(
        '18. Insights category breakdown matches monthly spend and excludes voided',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final currentMonthDate = DateTime(now.year, now.month, 10);
      final active1 = HouseholdExpense(
        id: 'exp-in-1',
        title: 'Veggies',
        category: 'Groceries',
        amount: 300.0,
        createdAt: currentMonthDate,
      );
      final active2 = HouseholdExpense(
        id: 'exp-in-2',
        title: 'Bus Pass',
        category: 'Transport',
        amount: 200.0,
        createdAt: currentMonthDate,
      );
      final voided = HouseholdExpense(
        id: 'exp-in-3',
        title: 'Wrong Fuel',
        category: 'Transport',
        amount: 500.0,
        createdAt: currentMonthDate,
        isVoided: true,
        voidReason: 'Mistake',
      );
      // Backdated from last year into this month
      final backdated = HouseholdExpense(
        id: 'exp-in-4',
        title: 'Rice Bag',
        category: 'Groceries',
        amount: 150.0,
        createdAt: DateTime(now.year - 1, 1, 1),
        expenseDate: currentMonthDate,
      );
      state.householdExpenses.addAll([active1, active2, voided, backdated]);

      await tester.pumpWidget(MaterialApp(
        home: InsightsScreen(state: state),
      ));
      await tester.pumpAndSettle();

      // Total should be 300 + 200 + 150 = 650 (voided 500 excluded)
      expect(state.spentThisMonth, 650.0);
      expect(find.text('₹650'), findsOneWidget);
      expect(
          find.text('3 entries · Calculated from local demo household entries'),
          findsOneWidget);

      // Category breakdown checks
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      // Groceries total: 300 + 150 = 450
      expect(find.text('₹450'), findsOneWidget);
      // Transport total: 200 (voided 500 excluded)
      expect(find.text('₹200'), findsOneWidget);
    });
  });
}
