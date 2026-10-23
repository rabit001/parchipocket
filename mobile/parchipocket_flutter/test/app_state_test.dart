import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';

void main() {
  group('AppState local demo workflows & serialization', () {
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

    test('validates and formats phone numbers to E.164', () {
      final state = AppState();
      expect(state.formatPhoneNumber('9876543210'), '+919876543210');
      expect(state.formatPhoneNumber('+919876543210'), '+919876543210');
      expect(state.formatPhoneNumber('+91 98765 43210'), '+919876543210');
      expect(state.formatPhoneNumber('09876543210'), '+919876543210');
      expect(state.formatPhoneNumber('+16505553434'), '+16505553434');
      expect(state.formatPhoneNumber('12345'), isNull);
      expect(state.formatPhoneNumber(''), isNull);
      state.dispose();
    });

    test('DemoBill item serialization & calculation check', () {
      final bill = DemoBill(
        id: 'PP-TEST',
        store: 'Test Store',
        items: <BillLine>[BillLine(name: 'Item 1', quantity: 3, unitPrice: 20)],
        createdAt: DateTime(2026, 1, 1),
        paymentMode: 'Cash',
        customerPhone: '+919876543210',
        isUdhaar: false,
        isSettled: false,
        isSaved: true,
      );

      expect(bill.id, 'PP-TEST');
      expect(bill.total, 60.0);
      expect(bill.items.first.total, 60.0);
    });
  });
}
