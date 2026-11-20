import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';

void main() {
  group('P0-02: Udhaar Settlement Accounting and Reporting', () {
    test('1. Unsettled Udhaar is included in gross sales immediately upon creation', () {
      final state = AppState();
      final initialGross = state.grossSales;

      final udhaarBill = DemoBill(
        id: 'PP-TEST-UDHAAR-1',
        store: state.shopName,
        items: [BillLine(name: 'Rice', quantity: 2, unitPrice: 150)], // 300
        createdAt: DateTime(2026, 11, 1),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      state.bills.insert(0, udhaarBill);

      expect(state.grossSales, initialGross + 300);
      expect(state.recordedSales, state.grossSales);
      state.dispose();
    });

    test('2. Unsettled Udhaar is included in outstanding receivables', () {
      final state = AppState();
      final initialOutstanding = state.outstandingTotal;

      final udhaarBill = DemoBill(
        id: 'PP-TEST-UDHAAR-2',
        store: state.shopName,
        items: [BillLine(name: 'Flour', quantity: 1, unitPrice: 250)],
        createdAt: DateTime(2026, 11, 2),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      state.bills.insert(0, udhaarBill);

      expect(state.outstandingTotal, initialOutstanding + 250);
      expect(state.udhaarBills.contains(udhaarBill), isTrue);
      expect(state.paidBills.contains(udhaarBill), isFalse);
      state.dispose();
    });

    test('3. Settling Udhaar removes it from outstanding receivables and updates collected payments', () async {
      final state = AppState();
      final udhaarBill = DemoBill(
        id: 'PP-TEST-UDHAAR-3',
        store: state.shopName,
        items: [BillLine(name: 'Oil', quantity: 1, unitPrice: 400)],
        createdAt: DateTime(2026, 11, 3),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );
      state.bills.insert(0, udhaarBill);

      final prevOutstanding = state.outstandingTotal;
      final prevCollected = state.collectedPayments;
      final prevGross = state.grossSales;

      final success = await state.markSettled(udhaarBill);

      expect(success, isTrue);
      expect(udhaarBill.isSettled, isTrue);
      expect(udhaarBill.settledAt, isNotNull);

      // Removed from outstanding
      expect(state.udhaarBills.contains(udhaarBill), isFalse);
      expect(state.outstandingTotal, prevOutstanding - 400);

      // Added to collected payments and paid bills
      expect(state.collectedPayments, prevCollected + 400);
      expect(state.paidBills.contains(udhaarBill), isTrue);
      expect(state.settledUdhaarBills.contains(udhaarBill), isTrue);

      // Gross sales is NOT duplicated upon settlement
      expect(state.grossSales, prevGross);
      expect(state.recordedSales, prevGross);

      // Fundamental accounting identity holds
      expect(state.grossSales, state.collectedPayments + state.outstandingTotal);
      state.dispose();
    });

    test('4. Fundamental accounting balance equation holds in all states', () async {
      final state = AppState();

      // Clear bills for a clean, deterministic ledger
      state.bills.clear();

      // Bill A: Cash 500
      state.bills.add(DemoBill(
        id: 'A',
        store: state.shopName,
        items: [BillLine(name: 'A', quantity: 1, unitPrice: 500)],
        createdAt: DateTime(2026, 11, 1),
        paymentMode: 'Cash',
        isUdhaar: false,
        isSettled: false,
      ));

      // Bill B: Unsettled Udhaar 300
      final billB = DemoBill(
        id: 'B',
        store: state.shopName,
        items: [BillLine(name: 'B', quantity: 1, unitPrice: 300)],
        createdAt: DateTime(2026, 11, 2),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );
      state.bills.add(billB);

      // State 1: 500 Cash + 300 Unsettled Udhaar
      expect(state.grossSales, 800);
      expect(state.collectedPayments, 500);
      expect(state.outstandingTotal, 300);
      expect(state.grossSales, state.collectedPayments + state.outstandingTotal);
      expect(state.shopBills.length, 2);
      expect(state.paidBills.length, 1);
      expect(state.udhaarBills.length, 1);

      // Settle Bill B
      await state.markSettled(billB);

      // State 2: 500 Cash + 300 Settled Udhaar
      expect(state.grossSales, 800); // No double-count!
      expect(state.collectedPayments, 800); // 500 + 300
      expect(state.outstandingTotal, 0);
      expect(state.grossSales, state.collectedPayments + state.outstandingTotal);
      expect(state.shopBills.length, 2);
      expect(state.paidBills.length, 2);
      expect(state.udhaarBills.length, 0);

      state.dispose();
    });

    test('5. Sale date and settlement date remain strictly distinct', () async {
      final state = AppState();
      state.bills.clear();

      final creationDate = DateTime(2026, 10, 10, 14, 0);
      final settlementDate = DateTime(2026, 10, 15, 11, 30);

      final bill = DemoBill(
        id: 'PP-DISTINCT-DATE',
        store: state.shopName,
        items: [BillLine(name: 'Fertilizer', quantity: 1, unitPrice: 750)],
        createdAt: creationDate,
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );
      state.bills.add(bill);

      // Prior to settlement:
      // Oct 10: Gross sale = 750, Collected = 0
      expect(state.todayGrossSales(now: creationDate), 750);
      expect(state.todayCollectedPayments(now: creationDate), 0);

      // Oct 15: Gross sale = 0, Collected = 0
      expect(state.todayGrossSales(now: settlementDate), 0);
      expect(state.todayCollectedPayments(now: settlementDate), 0);

      // Perform settlement on Oct 15
      bill.isSettled = true;
      bill.settledAt = settlementDate;

      // After settlement:
      // Oct 10: Gross sale is STILL 750 (did not shift to settlement date!)
      expect(state.todayGrossSales(now: creationDate), 750);
      expect(state.todayCollectedPayments(now: creationDate), 0);

      // Oct 15: Gross sale is STILL 0 (settlement did not create duplicate sale!)
      expect(state.todayGrossSales(now: settlementDate), 0);
      // Oct 15: Collected payments IS 750 (cash collected on Oct 15)
      expect(state.todayCollectedPayments(now: settlementDate), 750);

      state.dispose();
    });

    test('6. Today and monthly sales calculations handle both cash and Udhaar', () {
      final state = AppState();
      state.bills.clear();

      final today = DateTime(2026, 11, 19, 10, 0);
      final yesterday = DateTime(2026, 11, 18, 15, 0);
      final lastMonth = DateTime(2026, 10, 20, 12, 0);

      // Bill 1: Today Cash 200
      state.bills.add(DemoBill(
        id: '1', store: state.shopName,
        items: [BillLine(name: 'Item 1', quantity: 1, unitPrice: 200)],
        createdAt: today, paymentMode: 'Cash', isUdhaar: false,
      ));

      // Bill 2: Today Udhaar 350 (unsettled)
      state.bills.add(DemoBill(
        id: '2', store: state.shopName,
        items: [BillLine(name: 'Item 2', quantity: 1, unitPrice: 350)],
        createdAt: today, paymentMode: 'Udhaar', isUdhaar: true, isSettled: false,
      ));

      // Bill 3: Yesterday Udhaar 500, settled today
      state.bills.add(DemoBill(
        id: '3', store: state.shopName,
        items: [BillLine(name: 'Item 3', quantity: 1, unitPrice: 500)],
        createdAt: yesterday, paymentMode: 'Udhaar', isUdhaar: true, isSettled: true, settledAt: today,
      ));

      // Bill 4: Last month Cash 1000
      state.bills.add(DemoBill(
        id: '4', store: state.shopName,
        items: [BillLine(name: 'Item 4', quantity: 1, unitPrice: 1000)],
        createdAt: lastMonth, paymentMode: 'Cash', isUdhaar: false,
      ));

      // Today's Gross Sales: Bill 1 (200) + Bill 2 (350) = 550
      expect(state.todayGrossSales(now: today), 550);

      // Today's Collected Payments: Bill 1 (200 cash) + Bill 3 (500 settled today) = 700
      expect(state.todayCollectedPayments(now: today), 700);

      // Monthly Gross Sales for November: Bill 1 (200) + Bill 2 (350) + Bill 3 (500) = 1050
      expect(state.monthlyGrossSales(now: today), 1050);

      // Monthly Collected Payments for November: Bill 1 (200) + Bill 3 (500) = 700
      expect(state.monthlyCollectedPayments(now: today), 700);

      // Monthly Gross Sales for October: Bill 4 (1000)
      expect(state.monthlyGrossSales(now: lastMonth), 1000);
      expect(state.monthlyCollectedPayments(now: lastMonth), 1000);

      state.dispose();
    });

    test('7. Multiple Udhaar bills settled on different dates maintain distinct daily totals', () {
      final state = AppState();
      state.bills.clear();

      final nov10 = DateTime(2026, 11, 10);
      final nov15 = DateTime(2026, 11, 15);
      final nov20 = DateTime(2026, 11, 20);

      final billA = DemoBill(
        id: 'A', store: state.shopName,
        items: [BillLine(name: 'A', quantity: 1, unitPrice: 100)],
        createdAt: nov10, paymentMode: 'Udhaar', isUdhaar: true, isSettled: true, settledAt: nov15,
      );
      final billB = DemoBill(
        id: 'B', store: state.shopName,
        items: [BillLine(name: 'B', quantity: 1, unitPrice: 200)],
        createdAt: nov10, paymentMode: 'Udhaar', isUdhaar: true, isSettled: true, settledAt: nov20,
      );

      state.bills.addAll([billA, billB]);

      // Creation date (Nov 10): Gross Sales = 300, Collections = 0
      expect(state.todayGrossSales(now: nov10), 300);
      expect(state.todayCollectedPayments(now: nov10), 0);

      // Settlement of Bill A (Nov 15): Gross Sales = 0, Collections = 100
      expect(state.todayGrossSales(now: nov15), 0);
      expect(state.todayCollectedPayments(now: nov15), 100);

      // Settlement of Bill B (Nov 20): Gross Sales = 0, Collections = 200
      expect(state.todayGrossSales(now: nov20), 0);
      expect(state.todayCollectedPayments(now: nov20), 200);

      state.dispose();
    });

    test('8. Duplicate settlement requests are idempotent and protect against balance corruption', () async {
      final state = AppState();
      final initialOutstanding = state.outstandingTotal;
      final bill = DemoBill(
        id: 'PP-DUP-TEST',
        store: state.shopName,
        items: [BillLine(name: 'Sugar', quantity: 1, unitPrice: 120)],
        createdAt: DateTime(2026, 11, 1),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );
      state.bills.insert(0, bill);

      expect(state.outstandingTotal, initialOutstanding + 120);
      expect(await state.markSettled(bill), isTrue);
      final settledTimestamp = bill.settledAt;
      final collectedAfterFirst = state.collectedPayments;

      // Second settlement attempt
      expect(await state.markSettled(bill), isTrue);

      // Balances and timestamps are completely preserved
      expect(bill.settledAt, settledTimestamp);
      expect(state.collectedPayments, collectedAfterFirst);
      expect(state.outstandingTotal, initialOutstanding);

      state.dispose();
    });

    test('9. Legacy settled bills without settledAt are handled gracefully', () {
      final state = AppState();
      state.bills.clear();

      final legacyBill = DemoBill(
        id: 'PP-LEGACY-SETTLED',
        store: state.shopName,
        items: [BillLine(name: 'Legacy item', quantity: 1, unitPrice: 600)],
        createdAt: DateTime(2026, 10, 1),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: true,
        settledAt: null, // Legacy record with no settlement timestamp
      );
      state.bills.add(legacyBill);

      // Cumulative accounting accounts for the legacy settled bill
      expect(state.grossSales, 600);
      expect(state.collectedPayments, 600);
      expect(state.outstandingTotal, 0);
      expect(state.paidBills.contains(legacyBill), isTrue);
      expect(state.settledUdhaarBills.contains(legacyBill), isTrue);

      // Does not falsely contaminate today's cash collections
      final today = DateTime(2026, 11, 19);
      expect(state.todayCollectedPayments(now: today), 0);

      state.dispose();
    });

    test('10. Shop owner and street vendor role data isolation is strictly maintained', () {
      final state = AppState();
      state.bills.clear();

      state.shopName = 'My Test Shop';
      state.vendorName = 'My Quick Cart';
      state.role = UserRole.shopOwner;

      // Shop bill (Cash 400)
      state.bills.add(DemoBill(
        id: 'S1', store: 'My Test Shop',
        items: [BillLine(name: 'Item S', quantity: 1, unitPrice: 400)],
        createdAt: DateTime(2026, 11, 1), paymentMode: 'Cash',
      ));

      // Other shop bill (should be ignored by store filter)
      state.bills.add(DemoBill(
        id: 'O1', store: 'Unrelated Competitor Store',
        items: [BillLine(name: 'Item O', quantity: 1, unitPrice: 999)],
        createdAt: DateTime(2026, 11, 1), paymentMode: 'Cash',
      ));

      // Vendor bill (Udhaar 300 settled)
      state.bills.add(DemoBill(
        id: 'V1', store: 'My Quick Cart',
        items: [BillLine(name: 'Item V', quantity: 1, unitPrice: 300)],
        createdAt: DateTime(2026, 11, 2), paymentMode: 'Udhaar', isUdhaar: true, isSettled: true,
      ));

      // As Shop Owner: shopBills includes both 'My Test Shop' and 'My Quick Cart'
      expect(state.shopBills.any((b) => b.store == 'Unrelated Competitor Store'), isFalse);
      expect(state.grossSales, 700); // 400 + 300
      expect(state.collectedPayments, 700);

      state.dispose();
    });
  });
}
