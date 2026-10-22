import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';

void main() {
  group('AppState local demo workflows', () {
    test('creates a bill and calculates its total', () {
      final state = AppState();
      final bill = state.createBill(
        items: <BillLine>[
          BillLine(name: 'Tea', quantity: 2, unitPrice: 10),
          BillLine(name: 'Samosa', quantity: 1, unitPrice: 30),
        ],
        paymentMode: 'Cash',
        vendorMode: true,
      );

      expect(bill.total, 50);
      expect(state.selectedBill?.id, bill.id);
      expect(state.page, 'vendorReceipt');
      state.dispose();
    });

    test('saving a receipt adds it to the customer bill list', () {
      final state = AppState();
      final bill = state.createBill(
        items: <BillLine>[BillLine(name: 'Milk', quantity: 1, unitPrice: 50)],
        paymentMode: 'UPI',
        vendorMode: false,
      );

      expect(state.customerBills.any((item) => item.id == bill.id), isFalse);
      state.saveSelectedBill();
      expect(state.customerBills.any((item) => item.id == bill.id), isTrue);
      state.dispose();
    });

    test('expense is recorded separately from sales', () {
      final state = AppState();
      final previousExpenseTotal = state.expensesTotal;
      state.addExpense(title: 'Market transport', category: 'Transport', amount: 80);

      expect(state.expensesTotal, previousExpenseTotal + 80);
      expect(state.page, 'expenseSaved');
      state.dispose();
    });

    test('settled udhaar no longer counts as outstanding', () {
      final state = AppState();
      final bill = state.udhaarBills.first;
      final previousOutstanding = state.outstandingTotal;
      state.markSettled(bill);

      expect(state.udhaarBills.contains(bill), isFalse);
      expect(state.outstandingTotal, previousOutstanding - bill.total);
      state.dispose();
    });
  });
}
