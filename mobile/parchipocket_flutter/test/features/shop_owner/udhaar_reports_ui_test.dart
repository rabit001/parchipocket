import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/shop_screens.dart';

void main() {
  group('Udhaar Reports & History UI Tests', () {
    testWidgets('SalesReportsScreen displays gross sales, collections, and outstanding receivables',
        (tester) async {
      final state = AppState();
      state.bills.clear();

      final cashBill = DemoBill(
        id: 'PP-CASH-1',
        store: state.shopName,
        items: [BillLine(name: 'Item A', quantity: 1, unitPrice: 500)],
        createdAt: DateTime.now(),
        paymentMode: 'Cash',
        isUdhaar: false,
      );

      final udhaarBill = DemoBill(
        id: 'PP-UDHAAR-1',
        store: state.shopName,
        items: [BillLine(name: 'Item B', quantity: 1, unitPrice: 300)],
        createdAt: DateTime.now(),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      state.bills.addAll([cashBill, udhaarBill]);

      await tester.pumpWidget(MaterialApp(home: SalesReportsScreen(state: state)));
      await tester.pumpAndSettle();

      // Recorded sales = ₹800 (gross)
      expect(find.text('RECORDED SALES'), findsOneWidget);
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('2 recorded bills'), findsOneWidget);

      // Payments collected = ₹500
      expect(find.text('PAYMENTS COLLECTED'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);

      // Udhaar outstanding = ₹300
      expect(find.text('UDHAAR OUTSTANDING'), findsOneWidget);
      expect(find.text('₹300'), findsOneWidget);

      // Paid bills count = 1, Pending bills count = 1
      expect(find.text('PAID BILLS'), findsOneWidget);
      expect(find.text('PENDING BILLS'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // Paid: 1, Pending: 1

      // Settle the udhaar bill
      await state.markSettled(udhaarBill);
      await tester.pumpWidget(MaterialApp(home: SalesReportsScreen(state: state)));
      await tester.pumpAndSettle();

      // Payments collected now 800, outstanding now 0
      expect(find.text('₹800'), findsNWidgets(2)); // Recorded sales & Payments collected
      expect(find.text('₹0'), findsOneWidget); // Outstanding total
      expect(find.text('2'), findsOneWidget); // 2 paid bills
      expect(find.text('0'), findsOneWidget); // 0 pending bills

      state.dispose();
    });

    testWidgets('ExportReportPreviewScreen displays accounting breakdown correctly',
        (tester) async {
      final state = AppState();
      state.bills.clear();

      final cashBill = DemoBill(
        id: 'PP-CASH-2',
        store: state.shopName,
        items: [BillLine(name: 'Item A', quantity: 1, unitPrice: 1000)],
        createdAt: DateTime.now(),
        paymentMode: 'Cash',
        isUdhaar: false,
      );

      final udhaarBill = DemoBill(
        id: 'PP-UDHAAR-2',
        store: state.shopName,
        items: [BillLine(name: 'Item B', quantity: 1, unitPrice: 400)],
        createdAt: DateTime.now(),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      state.bills.addAll([cashBill, udhaarBill]);

      await tester.pumpWidget(MaterialApp(home: ExportReportPreviewScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.text('Recorded sales'), findsOneWidget);
      expect(find.text('₹1400'), findsOneWidget);
      expect(find.text('Payments collected'), findsOneWidget);
      expect(find.text('₹1000'), findsOneWidget);
      expect(find.text('Udhaar outstanding'), findsOneWidget);
      expect(find.text('₹400'), findsOneWidget);
      expect(find.text('Bills recorded'), findsOneWidget);
      expect(find.text('2 (1 paid, 1 pending)'), findsOneWidget);

      state.dispose();
    });

    testWidgets('BillHistoryScreen filters Paid and Udhaar bills without collision',
        (tester) async {
      final state = AppState();
      state.bills.clear();

      final cashBill = DemoBill(
        id: 'PP-CASH-3',
        store: state.shopName,
        items: [BillLine(name: 'Item A', quantity: 1, unitPrice: 200)],
        createdAt: DateTime(2026, 11, 10, 10, 0),
        paymentMode: 'Cash',
        isUdhaar: false,
      );

      final pendingUdhaar = DemoBill(
        id: 'PP-UDHAAR-PENDING',
        store: state.shopName,
        items: [BillLine(name: 'Item B', quantity: 1, unitPrice: 350)],
        createdAt: DateTime(2026, 11, 10, 11, 0),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      final settledUdhaar = DemoBill(
        id: 'PP-UDHAAR-SETTLED',
        store: state.shopName,
        items: [BillLine(name: 'Item C', quantity: 1, unitPrice: 500)],
        createdAt: DateTime(2026, 11, 10, 12, 0),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: true,
        settledAt: DateTime(2026, 11, 11, 9, 0),
      );

      state.bills.addAll([cashBill, pendingUdhaar, settledUdhaar]);

      await tester.pumpWidget(MaterialApp(home: BillHistoryScreen(state: state)));
      await tester.pumpAndSettle();

      // In 'All' tab, all 3 bills appear
      expect(find.text('PP-CASH-3'), findsOneWidget);
      expect(find.text('PP-UDHAAR-PENDING'), findsOneWidget);
      expect(find.text('PP-UDHAAR-SETTLED'), findsOneWidget);
      expect(find.textContaining('Udhaar (Pending)'), findsOneWidget);
      expect(find.textContaining('Udhaar (Settled)'), findsOneWidget);

      // Switch to 'Paid' tab
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();

      expect(find.text('PP-CASH-3'), findsOneWidget);
      expect(find.text('PP-UDHAAR-SETTLED'), findsOneWidget);
      expect(find.text('PP-UDHAAR-PENDING'), findsNothing);

      // Switch to 'Udhaar' tab
      await tester.tap(find.text('Udhaar'));
      await tester.pumpAndSettle();

      expect(find.text('PP-UDHAAR-PENDING'), findsOneWidget);
      expect(find.text('PP-CASH-3'), findsNothing);
      expect(find.text('PP-UDHAAR-SETTLED'), findsNothing);

      state.dispose();
    });
  });
}
