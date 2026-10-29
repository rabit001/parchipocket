import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/auth_screens.dart';
import 'package:parchipocket/screens/shop_screens.dart';
import 'package:parchipocket/services/firestore_service.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'user123';
}

class MockFirebaseAuth extends Fake implements FirebaseAuth {
  User? user = MockUser();
  bool failSignOut = false;
  int signOutCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw Exception('Simulated sign-out failure');
    user = null;
  }
}

class ControlledFirebaseAuth extends MockFirebaseAuth {
  ControlledFirebaseAuth() {
    user = null;
  }

  final StreamController<User?> events =
    StreamController<User?>.broadcast(sync: true);

  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) {
      throw Exception('Simulated sign-out failure');
    }
    user = null;
    events.add(null);
  }

  void emit(User? value) {
    user = value;
    events.add(value);
  }
}

class CountingFirestoreService extends FirestoreService {
  int profileReads = 0;
  int billReads = 0;
  int expenseReads = 0;
  int savedShopReads = 0;
  int claimedReceiptReads = 0;
  int writes = 0;
  Map<String, Object?>? savedProfile;
  Completer<Map<String, dynamic>?>? profileCompleter;

  @override
  Future<Map<String, dynamic>?> loadUserProfile() {
    profileReads++;
    return profileCompleter?.future ??
        Future<Map<String, dynamic>?>.value(<String, dynamic>{
          'role': 'customer',
          'name': 'Test Customer',
        });
  }

  @override
  Future<List<DemoBill>> loadBills() async {
    billReads++;
    return <DemoBill>[];
  }

  @override
  Future<List<DemoExpense>> loadExpenses() async {
    expenseReads++;
    return <DemoExpense>[];
  }

  @override
  String newHouseholdExpenseId() => 'test-household-expense';

  @override
  Future<void> addHouseholdExpense(HouseholdExpense expense) async {
    writes++;
  }

  @override
  Future<List<HouseholdExpense>> loadHouseholdExpenses() async =>
      <HouseholdExpense>[];

  @override
  Future<Set<String>> loadSavedShops() async {
    savedShopReads++;
    return <String>{};
  }

  @override
  Future<List<ClaimedReceipt>> loadClaimedReceipts() async {
    claimedReceiptReads++;
    return <ClaimedReceipt>[];
  }

  @override
  String newBillId() => 'test-cloud-bill';

  @override
  String newExpenseId() => 'test-cloud-expense';

  @override
  Future<void> createBill(DemoBill bill) async {
    writes++;
  }

  @override
  Future<void> addExpense(DemoExpense expense) async {
    writes++;
  }

  @override
  Future<void> saveBill(DemoBill bill) async {
    writes++;
  }

  @override
  Future<void> saveShop(String shopName) async {
    writes++;
  }

  @override
  Future<void> removeSavedShop(String shopName) async {
    writes++;
  }

  @override
  Future<void> saveUserProfile({
    required UserRole role,
    required String name,
    required String email,
    required String city,
    required String shopName,
    required String shopCategory,
    required String shopAddress,
    required String vendorName,
    required String vendorCategory,
  }) async {
    writes++;
    savedProfile = <String, Object?>{
      'role': role,
      'name': name,
      'email': email,
      'city': city,
      'shopName': shopName,
      'shopCategory': shopCategory,
      'shopAddress': shopAddress,
      'vendorName': vendorName,
      'vendorCategory': vendorCategory,
    };
  }
}

class ProfileFirestoreService extends FirestoreService {
  ProfileFirestoreService({
    this.profile,
    this.profileError,
    this.claimedReceiptError,
    this.loadedBills = const <DemoBill>[],
    this.loadedExpenses = const <DemoExpense>[],
    this.loadedSavedShops = const <String>{},
  });

  final Map<String, dynamic>? profile;
  final Object? profileError;
  final Object? claimedReceiptError;
  final List<DemoBill> loadedBills;
  final List<DemoExpense> loadedExpenses;
  final Set<String> loadedSavedShops;

  @override
  Future<Map<String, dynamic>?> loadUserProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<List<DemoBill>> loadBills() async => loadedBills;

  @override
  Future<List<DemoExpense>> loadExpenses() async => loadedExpenses;

  @override
  Future<List<HouseholdExpense>> loadHouseholdExpenses() async =>
      <HouseholdExpense>[];

  @override
  Future<Set<String>> loadSavedShops() async => loadedSavedShops;

  @override
  Future<List<ClaimedReceipt>> loadClaimedReceipts() async {
    if (claimedReceiptError != null) throw claimedReceiptError!;
    return <ClaimedReceipt>[];
  }
}

class BlockingBillFirestoreService extends FirestoreService {
  final Completer<void> billWrite = Completer<void>();
  int saveBillCalls = 0;

  @override
  String newBillId() => 'blocking-test-bill';

  @override
  Future<void> createBill(DemoBill bill) {
    saveBillCalls++;
    return billWrite.future;
  }
}

class BlockingExpenseFirestoreService extends FirestoreService {
  final Completer<void> expenseWrite = Completer<void>();

  @override
  String newExpenseId() => 'blocking-expense';

  @override
  Future<void> addExpense(DemoExpense expense) => expenseWrite.future;
}
class InMemoryBillFirestoreService extends FirestoreService {
  int _nextId = 0;
  String? firstId;
  bool failNextCreate = false;
  bool commitThenFailNextCreate = false;
  final Map<String, DemoBill> existingBills = <String, DemoBill>{};
  final List<String> attemptedIds = <String>[];

  @override
  String newBillId() {
    final forcedId = firstId;
    if (forcedId != null) {
      firstId = null;
      return forcedId;
    }
    return 'generated-bill-${_nextId++}';
  }

  @override
  Future<void> createBill(DemoBill bill) async {
    attemptedIds.add(bill.id);
    final existing = existingBills[bill.id];
    if (existing != null) {
      final sameIdentity = existing.store == bill.store &&
          existing.paymentMode == bill.paymentMode &&
          existing.customerPhone == bill.customerPhone &&
          existing.createdAt == bill.createdAt &&
          existing.items.length == bill.items.length &&
          List<bool>.generate(existing.items.length, (index) {
            final left = existing.items[index];
            final right = bill.items[index];
            return left.name == right.name &&
                left.quantity == right.quantity &&
                left.unitPrice == right.unitPrice;
          }).every((matches) => matches);
      if (sameIdentity) return;
      throw BillIdCollisionException(bill.id);
    }
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('Simulated Firestore write failure');
    }
    existingBills[bill.id] = bill;
    if (commitThenFailNextCreate) {
      commitThenFailNextCreate = false;
      throw Exception('Simulated lost Firestore acknowledgement');
    }
  }
}

class RetryExpenseFirestoreService extends FirestoreService {
  int _nextId = 0;
  bool failNextWrite = true;
  final List<String> attemptedIds = <String>[];

  @override
  String newExpenseId() => 'retry-expense-${_nextId++}';

  @override
  Future<void> addExpense(DemoExpense expense) async {
    attemptedIds.add(expense.id);
    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('Simulated lost expense acknowledgement');
    }
  }
}

class FailingFirestoreService extends FirestoreService {
  @override
  String newBillId() => 'failed-test-bill';

  @override
  String newExpenseId() => 'failed-test-expense';

  @override
  Future<void> createBill(DemoBill bill) async {
    throw Exception('Simulated Firestore write failure');
  }

  @override
  Future<void> saveBill(DemoBill bill) async {
    throw Exception('Simulated Firestore write failure');
  }

  @override
  Future<void> addExpense(DemoExpense expense) async {
    throw Exception('Simulated Firestore write failure');
  }

  @override
  Future<void> saveShop(String shopName) async {
    throw Exception('Simulated Firestore write failure');
  }

  @override
  Future<void> removeSavedShop(String shopName) async {
    throw Exception('Simulated Firestore write failure');
  }

  @override
  Future<void> saveUserProfile({
    required UserRole role,
    required String name,
    required String email,
    required String city,
    required String shopName,
    required String shopCategory,
    required String shopAddress,
    required String vendorName,
    required String vendorCategory,
  }) async {
    throw Exception('Simulated Firestore write failure');
  }
}

void main() {
  group('Explicit demo session isolation', () {
    test('entering demo clears stale cloud state and ignores auth callbacks',
        () async {
      final auth = ControlledFirebaseAuth();
      final service = CountingFirestoreService();
      final state = AppState(auth: auth)..firestoreService = service;
      state.cloudError = 'old permission error';
      state.isCloudLoading = true;
      state.profileStatus = CloudProfileStatus.failed;

      await state.enterDemoMode();
      auth.emit(MockUser());
      await Future<void>.delayed(Duration.zero);

      expect(state.isDemoMode, isTrue);
      expect(state.page, 'customerSetup');
      expect(state.cloudError, isNull);
      expect(state.isCloudLoading, isFalse);
      expect(service.profileReads, 0);
      expect(service.claimedReceiptReads, 0);
      await auth.events.close();
      state.dispose();
    });

    test('demo workflows stay local and do not write to Firestore', () async {
      final service = CountingFirestoreService();
      final state = AppState()..firestoreService = service;

      await state.createBill(
        items: <BillLine>[BillLine(name: 'Tea', quantity: 1, unitPrice: 20)],
        paymentMode: 'Cash',
        vendorMode: false,
      );
      await state.addExpense(title: 'Travel', category: 'Transport', amount: 5);
      expect(
        await state.updateProfile(
          name: 'Demo Customer',
          email: 'demo@example.test',
          location: 'Ujjain',
        ),
        isTrue,
      );
      expect(
        await state.updateShop(
            ownerName: 'Demo Owner',
            name: 'Demo Shop',
            category: 'Kirana',
            address: 'Ujjain'),
        isTrue,
      );
      expect(service.writes, 0);
      expect(state.isDemoMode, isTrue);
      state.dispose();
    });

    test('late expense failure from a previous session cannot contaminate demo mode',
        () async {
      final auth = MockFirebaseAuth();
      final service = BlockingExpenseFirestoreService();
      final state = AppState()
        ..auth = auth
        ..firestoreService = service
        ..isDemoMode = false;

      final pendingWrite = state.addExpense(
        title: 'Previous account expense',
        category: 'Transport',
        amount: 25,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.isCloudLoading, isTrue);

      await state.enterDemoMode();
      service.expenseWrite.completeError(
        Exception('Late permission-denied response'),
      );

      expect(await pendingWrite, isFalse);
      expect(state.isDemoMode, isTrue);
      expect(state.cloudError, isNull);
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });
    test('stale profile failure cannot set cloud error after entering demo',
        () async {
      final auth = ControlledFirebaseAuth();
      final service = CountingFirestoreService()
        ..profileCompleter = Completer<Map<String, dynamic>?>();
      final state = AppState(auth: auth)..firestoreService = service;
      final user = MockUser();
      auth.emit(user);
      await Future<void>.delayed(Duration.zero);
      expect(service.profileReads, 1);

      await state.enterDemoMode();
      service.profileCompleter!
          .completeError(Exception('late permission denied'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.isDemoMode, isTrue);
      expect(state.page, 'customerSetup');
      expect(state.cloudError, isNull);
      expect(service.billReads, 0);
      expect(service.claimedReceiptReads, 0);
      await auth.events.close();
      state.dispose();
    });

    test('cloud collections are applied atomically if a later read fails',
        () async {
      final auth = ControlledFirebaseAuth();
      final service = ProfileFirestoreService(
        profile: <String, dynamic>{
          'role': 'customer',
          'name': 'Cloud Customer',
        },
        loadedBills: <DemoBill>[
          DemoBill(
            id: 'cloud-bill',
            store: 'Cloud Store',
            items: <BillLine>[
              BillLine(name: 'Bread', quantity: 1, unitPrice: 20),
            ],
            createdAt: DateTime(2026, 10, 26),
            paymentMode: 'Cash',
          ),
        ],
        loadedExpenses: <DemoExpense>[
          DemoExpense(
            id: 'cloud-expense',
            title: 'Transport',
            category: 'Travel',
            amount: 10,
            createdAt: DateTime(2026, 10, 26),
          ),
        ],
        loadedSavedShops: <String>{'Cloud Store'},
        claimedReceiptError: Exception('permission-denied'),
      );
      final state = AppState(auth: auth)..firestoreService = service;

      auth.emit(MockUser());
      await pumpEventQueue();

      expect(state.customerName, 'Cloud Customer');
      expect(state.profileStatus, CloudProfileStatus.loaded);
      expect(state.cloudError, contains('permission-denied'));
      expect(state.bills, isEmpty);
      expect(state.claimedReceipts, isEmpty);
      expect(state.expenses, isEmpty);
      expect(state.savedShops, isEmpty);

      await auth.events.close();
      state.dispose();
    });

    test('expense retry after a lost acknowledgement reuses the same ID',
        () async {
      final auth = MockFirebaseAuth();
      final service = RetryExpenseFirestoreService();
      final state = AppState()
        ..auth = auth
        ..isDemoMode = false
        ..firestoreService = service;
      state.expenses.clear();

      final first = await state.addExpense(
        title: 'Transport',
        category: 'Travel',
        amount: 42,
      );
      expect(first, isFalse);
      expect(service.attemptedIds, hasLength(1));

      final retry = await state.addExpense(
        title: 'Transport',
        category: 'Travel',
        amount: 42,
      );
      expect(retry, isTrue);
      expect(service.attemptedIds, hasLength(2));
      expect(service.attemptedIds[1], service.attemptedIds[0]);
      expect(state.expenses, hasLength(1));
      expect(state.expenses.single.id, service.attemptedIds.first);
      state.dispose();
    });

    test('explicit sign-in exits demo and loads profile for normal navigation',
        () async {
      final auth = ControlledFirebaseAuth();
      final service = CountingFirestoreService();
      final state = AppState(auth: auth)..firestoreService = service;
      await state.enterDemoMode();
      expect(await state.beginAuthentication(), isTrue);
      expect(state.isDemoMode, isFalse);

      auth.emit(MockUser());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.profileReads, 1);
      expect(service.billReads, 1);
      expect(service.claimedReceiptReads, 1);
      expect(state.profileStatus, CloudProfileStatus.loaded);
      expect(state.page, 'customerHome');
      expect(state.isDemoMode, isFalse);
      await auth.events.close();
      state.dispose();
    });
  });

  group('AppState local demo workflows & serialization', () {
  test('createBill rejects non-finite prices', () async {
    final state = AppState();
    final initialBillCount = state.bills.length;

    await expectLater(
      state.createBill(
        items: <BillLine>[
          BillLine(
            name: 'Milk',
            quantity: 1,
            unitPrice: double.infinity,
          ),
        ],
        paymentMode: 'Cash',
        vendorMode: false,
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(state.bills, hasLength(initialBillCount));
    expect(state.selectedBill, isNull);
    state.dispose();
  });

  test('addExpense rejects invalid amounts', () async {
    final state = AppState();
    final initialExpenseCount = state.expenses.length;

    for (final amount in <double>[
      0,
      -1,
      double.nan,
      double.infinity,
    ]) {
      expect(
        await state.addExpense(
          title: 'Invalid expense',
          category: 'Other',
          amount: amount,
        ),
        isFalse,
      );
    }

    expect(state.expenses, hasLength(initialExpenseCount));
    state.dispose();
  });
  test('createBill rejects invalid quantity, empty name and overflow', () async {
    final invalidItems = <List<BillLine>>[
      <BillLine>[
        BillLine(name: 'Milk', quantity: 0, unitPrice: 10),
      ],
      <BillLine>[
        BillLine(name: '   ', quantity: 1, unitPrice: 10),
      ],
      <BillLine>[
        BillLine(name: 'Milk', quantity: 2, unitPrice: double.maxFinite),
      ],
    ];

    for (final items in invalidItems) {
      final state = AppState();
      final initialBillCount = state.bills.length;

      await expectLater(
          state.createBill(
          items: items,
          paymentMode: 'Cash',
          vendorMode: false,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(state.bills, hasLength(initialBillCount));
      expect(state.selectedBill, isNull);
      state.dispose();
    }
  });
    test('creates a bill and calculates its total', () async {
      final state = AppState();
      final bill = await state.createBill(
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

    test('saving a receipt adds it to the customer bill list', () async {
      final state = AppState();
      final bill = await state.createBill(
        items: <BillLine>[BillLine(name: 'Milk', quantity: 1, unitPrice: 50)],
        paymentMode: 'UPI',
        vendorMode: false,
      );

      expect(state.customerBills.any((item) => item.id == bill.id), isFalse);
      await state.saveSelectedBill();
      expect(state.customerBills.any((item) => item.id == bill.id), isTrue);
      state.dispose();
    });

    test('expense is recorded separately from sales', () async {
      final state = AppState();
      final previousExpenseTotal = state.expensesTotal;
      await state.addExpense(
          title: 'Market transport', category: 'Transport', amount: 80);

      expect(state.expensesTotal, previousExpenseTotal + 80);
      expect(state.page, 'expenseSaved');
      state.dispose();
    });

    test('settled udhaar no longer counts as outstanding', () async {
      final state = AppState();
      final bill = state.udhaarBills.first;
      final previousOutstanding = state.outstandingTotal;
      await state.markSettled(bill);

      expect(state.udhaarBills.contains(bill), isFalse);
      expect(state.outstandingTotal, previousOutstanding - bill.total);
      state.dispose();
    });
    test('markSettled rejects a normal sales bill', () async {
      final state = AppState();

      final bill = DemoBill(
        id: 'PP-NON-UDHAAR-TEST',
        store: state.shopName,
        items: <BillLine>[
          BillLine(name: 'Milk', quantity: 1, unitPrice: 10),
        ],
        createdAt: DateTime(2026, 10, 28),
        paymentMode: 'Cash',
        isUdhaar: false,
        isSettled: false,
      );

      state.bills.insert(0, bill);

      expect(await state.markSettled(bill), isFalse);
      expect(bill.isSettled, isFalse);
      expect(state.udhaarBills.contains(bill), isFalse);

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
    test('rejects malformed phone number input', () {
      final state = AppState();

      expect(state.formatPhoneNumber('abc9876543210'), isNull);
      expect(state.formatPhoneNumber('98765@43210'), isNull);
      expect(state.formatPhoneNumber('+91+9876543210'), isNull);
      expect(state.formatPhoneNumber('123456'), isNull);
      expect(state.formatPhoneNumber('1234567890123456'), isNull);

      state.dispose();
    });

    test('createBill rejects an invalid customer phone number', () async {
      final state = AppState();
      final initialBillCount = state.bills.length;

      await expectLater(
        state.createBill(
          items: <BillLine>[
            BillLine(name: 'Milk', quantity: 1, unitPrice: 10),
          ],
          paymentMode: 'Cash',
          customerPhone: 'abc9876543210',
          vendorMode: false,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(state.bills, hasLength(initialBillCount));
      expect(state.selectedBill, isNull);

      state.dispose();
    });

    test('createBill normalizes a valid customer phone number', () async {
      final state = AppState();

      final bill = await state.createBill(
        items: <BillLine>[
          BillLine(name: 'Milk', quantity: 1, unitPrice: 10),
        ],
        paymentMode: 'Cash',
        customerPhone: '987 654 3210',
        vendorMode: false,
      );

      expect(bill.customerPhone, '+919876543210');

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

    test('enforces OTP cooldown timer behavior', () {
      final state = AppState();
      expect(state.otpCooldownSecondsRemaining, 0);
      state.lastOtpSentAt = DateTime.now();
      expect(state.otpCooldownSecondsRemaining, greaterThan(50));
      state.dispose();
    });

    test('enforces max 10 items limit on bill creation', () {
      final state = AppState();
      final elevenItems = List.generate(
        11,
        (index) => BillLine(name: 'Item $index', quantity: 1, unitPrice: 10),
      );
      expect(
        () => state.createBill(
          items: elevenItems,
          paymentMode: 'Cash',
          vendorMode: false,
        ),
        throwsA(anything),
      );
      state.dispose();
    });
  });

  group('AppState cloud failure handling & role consistency', () {
    testWidgets('shop registration saves the entered owner name to the profile',
        (tester) async {
      final service = CountingFirestoreService();
      final state = AppState()
        ..isDemoMode = false
        ..profileStatus = CloudProfileStatus.missing
        ..role = UserRole.shopOwner
        ..customerName = ''
        ..auth = MockFirebaseAuth()
        ..firestoreService = service
        ..page = 'shopSetup';

      await tester.pumpWidget(MaterialApp(home: ShopSetupScreen(state: state)));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Asha Verma');
      await tester.enterText(fields.at(1), 'Asha General Store');
      await tester.enterText(fields.at(2), '12 Main Road, Ujjain');
      await tester.ensureVisible(find.text('Create Shop Profile'));
      await tester.tap(find.text('Create Shop Profile'));
      await tester.pumpAndSettle();

      expect(service.writes, 1);
      expect(service.savedProfile?['role'], UserRole.shopOwner);
      expect(service.savedProfile?['name'], 'Asha Verma');
      expect(service.savedProfile?['shopName'], 'Asha General Store');
      expect(service.savedProfile?['shopAddress'], '12 Main Road, Ujjain');
      expect(state.customerName, 'Asha Verma');
      expect(state.page, 'customerHome');
      state.dispose();
    });

    testWidgets('missing owner name is explained and preserves shop details',
        (tester) async {
      final service = CountingFirestoreService();
      final state = AppState()
        ..isDemoMode = false
        ..profileStatus = CloudProfileStatus.missing
        ..role = UserRole.shopOwner
        ..customerName = ''
        ..auth = MockFirebaseAuth()
        ..firestoreService = service
        ..page = 'shopSetup';

      await tester.pumpWidget(MaterialApp(home: ShopSetupScreen(state: state)));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'Asha General Store');
      await tester.enterText(fields.at(2), '12 Main Road, Ujjain');
      await tester.ensureVisible(find.text('Create Shop Profile'));
      await tester.tap(find.text('Create Shop Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the owner/contact full name to continue.'),
          findsOneWidget);
      expect(tester.widget<TextField>(fields.at(1)).controller!.text,
          'Asha General Store');
      expect(tester.widget<TextField>(fields.at(2)).controller!.text,
          '12 Main Road, Ujjain');
      expect(service.writes, 0);
      expect(state.page, 'shopSetup');
      state.dispose();
    });

    test('vendor profile also saves the required owner name', () async {
      final service = CountingFirestoreService();
      final state = AppState()
        ..isDemoMode = false
        ..role = UserRole.streetVendor
        ..customerName = ''
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;

      final saved = await state.updateVendor(
        ownerName: '  Ramesh Patel  ',
        name: 'Patel Tea Stall',
        category: 'Tea / Snacks',
      );

      expect(saved, isTrue);
      expect(service.savedProfile?['role'], UserRole.streetVendor);
      expect(service.savedProfile?['name'], 'Ramesh Patel');
      expect(state.customerName, 'Ramesh Patel');
      state.dispose();
    });

    test('saveSelectedBill handles write failure and preserves state',
        () async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      state.selectedBill = DemoBill(
        id: 'PP-101',
        store: 'Test Store',
        items: [BillLine(name: 'Test', quantity: 1, unitPrice: 10)],
        createdAt: DateTime.now(),
        paymentMode: 'Cash',
        isSaved: false,
      );

      final result = await state.saveSelectedBill();
      expect(result, isFalse);
      expect(state.selectedBill!.isSaved, isFalse);
      expect(state.cloudError, contains('Simulated Firestore write failure'));
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('markSettled handles write failure and preserves state', () async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      final bill = DemoBill(
        id: 'PP-102',
        store: 'Test Store',
        items: [BillLine(name: 'Test', quantity: 1, unitPrice: 10)],
        createdAt: DateTime.now(),
        paymentMode: 'Udhaar',
        isUdhaar: true,
        isSettled: false,
      );

      final result = await state.markSettled(bill);
      expect(result, isFalse);
      expect(bill.isSettled, isFalse);
      expect(state.cloudError, contains('Simulated Firestore write failure'));
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('addExpense handles write failure and preserves local list', () async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      final initialExpenseCount = state.expenses.length;

      final result = await state.addExpense(
          title: 'Fail Expense', category: 'Stock', amount: 100);
      expect(result, isFalse);
      expect(state.expenses.length, initialExpenseCount);
      expect(state.cloudError, contains('Simulated Firestore write failure'));
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('toggleSavedShop handles write failure and preserves local set',
        () async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      final initialContains = state.savedShops.contains('Test Shop');

      final result = await state.toggleSavedShop('Test Shop');
      expect(result, isFalse);
      expect(state.savedShops.contains('Test Shop'), initialContains);
      expect(state.cloudError, contains('Simulated Firestore write failure'));
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('updateProfile handles write failure and preserves local fields',
        () async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      final initialName = state.customerName;

      final result = await state.updateProfile(
          name: 'New Name', email: 'test@example.com', location: 'City');
      expect(result, isFalse);
      expect(state.customerName, initialName);
      expect(state.cloudError, contains('Simulated Firestore write failure'));
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test(
        'signOut completes when Firebase emits auth change synchronously',
        () async {
      final auth = ControlledFirebaseAuth()..user = MockUser();
      final state = AppState(auth: auth)
        ..isDemoMode = false
        ..page = 'logout';

      final result = await state.signOut();

      expect(result, isTrue);
      expect(auth.currentUser, isNull);
      expect(state.page, 'splash');
      expect(state.isSigningOut, isFalse);

      state.dispose();
      await auth.events.close();
    });
    test(
        'signOut calls Firebase and clears account-specific state only on success',
        () async {
      final state = AppState();
      final auth = MockFirebaseAuth();
      state.auth = auth;
      state.isDemoMode = false;
      state.customerName = 'Private Account Name';
      state.phoneNumber = '+919876543210';
      state.bills
        ..clear()
        ..add(DemoBill(
          id: 'PRIVATE-1',
          store: 'Private Shop',
          items: [BillLine(name: 'Private item', quantity: 1, unitPrice: 1)],
          createdAt: DateTime.now(),
          paymentMode: 'Cash',
        ));

      final result = await state.signOut();

      expect(result, isTrue);
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
      expect(state.page, 'splash');
      expect(state.customerName, isNot('Private Account Name'));
      expect(state.phoneNumber, isEmpty);
      expect(state.bills.any((bill) => bill.id == 'PRIVATE-1'), isFalse);
      expect(state.isDemoMode, isTrue);
      state.dispose();
    });

    test('signOut failure keeps the current screen and private state',
        () async {
      final state = AppState();
      final auth = MockFirebaseAuth()..failSignOut = true;
      state.auth = auth;
      state.isDemoMode = false;
      state.page = 'logout';
      state.customerName = 'Private Account Name';

      final result = await state.signOut();

      expect(result, isFalse);
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNotNull);
      expect(state.page, 'logout');
      expect(state.customerName, 'Private Account Name');
      expect(state.signOutError, contains('Check your connection'));
      state.dispose();
    });

    test('profile read failure is distinct from a confirmed missing profile',
        () async {
      final failureState = AppState();
      failureState.auth = MockFirebaseAuth();
      failureState.isDemoMode = false;
      failureState.role = UserRole.streetVendor;
      failureState.firestoreService = ProfileFirestoreService(
        profileError: Exception('permission-denied'),
      );

      final failedResult = await failureState.loadUserDataFromCloud();
      failureState.navigateAfterAuth();

      expect(failedResult, CloudProfileStatus.failed);
      expect(failureState.profileStatus, CloudProfileStatus.failed);
      expect(failureState.page, 'profileLoadError');
      failureState.setRole(UserRole.customer);
      expect(failureState.role, UserRole.streetVendor);
      expect(failureState.page, 'profileLoadError');
      failureState.dispose();

      final missingState = AppState();
      missingState.auth = MockFirebaseAuth();
      missingState.isDemoMode = false;
      missingState.role = UserRole.streetVendor;
      missingState.firestoreService = ProfileFirestoreService();

      final missingResult = await missingState.loadUserDataFromCloud();
      missingState.navigateAfterAuth();

      expect(missingResult, CloudProfileStatus.missing);
      expect(missingState.profileStatus, CloudProfileStatus.missing);
      expect(missingState.page, 'customerSetup');
      expect(missingState.role, UserRole.streetVendor);
      missingState.setRole(UserRole.shopOwner);
      expect(missingState.role, UserRole.customer);
      expect(missingState.page, 'customerSetup');
      missingState.dispose();
    });

    test(
        'createBill rejects duplicate cloud submissions while the first is pending',
        () async {
      final state = AppState();
      final service = BlockingBillFirestoreService();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = service;
      final items = [BillLine(name: 'Tea', quantity: 1, unitPrice: 10)];

      final firstWrite = state.createBill(
        items: items,
        paymentMode: 'Cash',
        vendorMode: false,
      );
      expect(state.isCloudLoading, isTrue);
      await expectLater(
        state.createBill(items: items, paymentMode: 'Cash', vendorMode: false),
        throwsA(isA<StateError>()),
      );
      expect(service.saveBillCalls, 1);

      service.billWrite.complete();
      final bill = await firstWrite;
      expect(state.selectedBill?.id, bill.id);
      expect(state.page, 'receipt');
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('Firestore generated bill IDs are unique across AppState instances',
        () async {
      final service = InMemoryBillFirestoreService();
      final firstState = AppState()
        ..isDemoMode = false
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;
      final secondState = AppState()
        ..isDemoMode = false
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;
      final items = <BillLine>[
        BillLine(name: 'Tea', quantity: 1, unitPrice: 10)
      ];

      final first = await firstState.createBill(
        items: items,
        paymentMode: 'Cash',
        vendorMode: false,
      );
      final second = await secondState.createBill(
        items: items,
        paymentMode: 'Cash',
        vendorMode: false,
      );

      expect(first.id, isNot(second.id));
      expect(first.displayNumber, startsWith('PP-'));
      expect(service.existingBills.keys,
          containsAll(<String>[first.id, second.id]));
      firstState.dispose();
      secondState.dispose();
    });

    test('bill identity stays stable across a lost write acknowledgement retry',
        () async {
      final state = AppState();
      final service = InMemoryBillFirestoreService()
        ..commitThenFailNextCreate = true;
      state
        ..isDemoMode = false
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;
      final items = <BillLine>[
        BillLine(name: 'Milk', quantity: 1, unitPrice: 50)
      ];

      await expectLater(
        state.createBill(items: items, paymentMode: 'UPI', vendorMode: false),
        throwsA(isA<Exception>()),
      );
      final retry = await state.createBill(
        items: items,
        paymentMode: 'UPI',
        vendorMode: false,
      );

      expect(service.attemptedIds, hasLength(2));
      expect(service.attemptedIds[0], service.attemptedIds[1]);
      expect(service.existingBills, hasLength(1));
      expect(retry.id, service.attemptedIds.first);
      expect(state.page, 'receipt');
      state.dispose();
    });

    test(
        'existing bill ID collision is rejected without overwriting the record',
        () async {
      final state = AppState();
      final existing = DemoBill(
        id: 'collision-bill',
        store: 'Original Store',
        items: <BillLine>[
          BillLine(name: 'Original', quantity: 1, unitPrice: 25)
        ],
        createdAt: DateTime(2026, 1, 1),
        paymentMode: 'Cash',
      );
      final service = InMemoryBillFirestoreService()
        ..firstId = existing.id
        ..existingBills[existing.id] = existing;
      state
        ..isDemoMode = false
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;

      await expectLater(
        state.createBill(
          items: <BillLine>[
            BillLine(name: 'Different', quantity: 1, unitPrice: 99)
          ],
          paymentMode: 'Cash',
          vendorMode: false,
        ),
        throwsA(isA<BillIdCollisionException>()),
      );

      expect(service.existingBills[existing.id], same(existing));
      expect(service.existingBills[existing.id]!.store, 'Original Store');
      expect(state.page, 'splash');
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    testWidgets(
        'customer setup stays on setup and reports a failed profile write',
        (tester) async {
      final state = AppState();
      state.isDemoMode = false;
      state.profileStatus = CloudProfileStatus.missing;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      state.page = 'customerSetup';

      await tester
          .pumpWidget(MaterialApp(home: CustomerSetupScreen(state: state)));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(state.page, 'customerSetup');
      expect(find.textContaining('Simulated Firestore write failure'),
          findsNWidgets(2));
      expect(find.text('Save & Continue'), findsOneWidget);
      state.dispose();
    });

    testWidgets(
        'bill creation failure stays on the form and is shown to the user',
        (tester) async {
      final state = AppState();
      state.isDemoMode = false;
      state.auth = MockFirebaseAuth();
      state.firestoreService = FailingFirestoreService();
      state.page = 'createBill';

      await tester
          .pumpWidget(MaterialApp(home: CreateBillScreen(state: state)));
      await tester.enterText(find.byType(TextField).at(0), 'Tea');
      await tester.enterText(find.byType(TextField).at(2), '10');
      await tester.tap(find.text('Add item to bill'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Generate Bill'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Generate Bill'));
      await tester.pumpAndSettle();

      expect(state.page, 'createBill');
      expect(find.textContaining('Simulated Firestore write failure'),
          findsNWidgets(2));
      expect(find.text('Generate Bill'), findsOneWidget);
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test('household expenses validate amounts and stay separate from business expenses',
        () async {
      final state = AppState();
      final initialLength = state.householdExpenses.length;

      final rejected = await state.addHouseholdExpense(
        title: 'Milk',
        category: 'Dairy',
        amount: 0,
      );
      expect(rejected, isFalse);
      expect(state.householdExpenses.length, initialLength);

      final saved = await state.addHouseholdExpense(
        title: 'Milk',
        category: 'Dairy',
        amount: 60,
        source: 'voice',
      );
      expect(saved, isTrue);
      expect(state.householdExpenses.first.title, 'Milk');
      expect(state.householdExpenses.first.category, 'Dairy');
      expect(state.householdExpenses.first.amount, 60);
      expect(state.householdExpenses.first.source, 'voice');
      expect(state.page, 'householdExpenses');
      state.dispose();
    });

    test('cloud household expense uses its own owner-scoped write', () async {
      final service = CountingFirestoreService();
      final state = AppState()
        ..isDemoMode = false
        ..auth = MockFirebaseAuth()
        ..firestoreService = service;
      state.householdExpenses.clear();

      final saved = await state.addHouseholdExpense(
        title: 'Vegetables',
        category: 'Vegetables',
        amount: 250,
        source: 'manual',
      );

      expect(saved, isTrue);
      expect(service.writes, 1);
      expect(state.householdExpenses.single.id, 'test-household-expense');
      expect(state.householdExpenses.single.title, 'Vegetables');
      expect(state.page, 'householdExpenses');
      expect(state.isCloudLoading, isFalse);
      state.dispose();
    });

    test(
        'role consistency: new user sets initial role, existing cloud user preserves role',
        () {
      final state = AppState();
      state.isDemoMode = false;
      state.hasExistingCloudProfile = false;
      state.profileStatus = CloudProfileStatus.missing;

      state.setRole(UserRole.shopOwner);
      expect(state.role, UserRole.customer);
      expect(state.page, 'customerSetup');

      // Existing stored seller roles remain intact; only the active experience
      // is redirected while these modes are paused.
      state.role = UserRole.shopOwner;
      state.hasExistingCloudProfile = true;
      state.profileStatus = CloudProfileStatus.loaded;
      state.setRole(UserRole.customer);
      expect(state.role,
          UserRole.shopOwner); // Stored profile role is not rewritten
      expect(state.lastNotice, contains('locked'));
      state.dispose();
    });

    test(
        'navigateAfterAuth routes profiles to household home and new users to setup',
        () {
      final state = AppState();
      state.isDemoMode = false;

      // Existing customer
      state.hasExistingCloudProfile = true;
      state.profileStatus = CloudProfileStatus.loaded;
      state.role = UserRole.customer;
      state.navigateAfterAuth();
      expect(state.page, 'customerHome');

      // Existing shop owner
      state.role = UserRole.shopOwner;
      state.profileStatus = CloudProfileStatus.loaded;
      state.navigateAfterAuth();
      expect(state.page, 'shopHome');

      // Existing street vendor
      state.role = UserRole.streetVendor;
      state.profileStatus = CloudProfileStatus.loaded;
      state.navigateAfterAuth();
      expect(state.page, 'customerHome');

      // New user without profile
      state.hasExistingCloudProfile = false;
      state.profileStatus = CloudProfileStatus.missing;
      state.navigateAfterAuth();
      expect(state.page, 'roleSelection');

      state.dispose();
    });
  });
}
