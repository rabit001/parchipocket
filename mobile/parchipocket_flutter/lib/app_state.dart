import 'package:flutter/foundation.dart';

enum UserRole { customer, shopOwner, streetVendor }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.shopOwner => 'Shop Owner',
        UserRole.streetVendor => 'Street Vendor',
      };
}

class BillLine {
  BillLine({required this.name, required this.quantity, required this.unitPrice});

  final String name;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}

class DemoBill {
  DemoBill({
    required this.id,
    required this.store,
    required this.items,
    required this.createdAt,
    required this.paymentMode,
    this.customerPhone = '',
    this.isUdhaar = false,
    this.isSettled = false,
    this.isSaved = true,
  });

  final String id;
  final String store;
  final List<BillLine> items;
  final DateTime createdAt;
  final String paymentMode;
  final String customerPhone;
  bool isUdhaar;
  bool isSettled;
  bool isSaved;
  double get total => items.fold<double>(0, (sum, item) => sum + item.total);
}

class DemoExpense {
  DemoExpense({required this.title, required this.category, required this.amount, required this.createdAt});
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;
}

class AppState extends ChangeNotifier {
  String page = 'splash';
  UserRole role = UserRole.customer;
  String customerName = 'Rabit Mansuri';
  String customerEmail = '';
  String city = 'Ujjain, Madhya Pradesh';
  String shopName = 'Mansuri General Store';
  String shopCategory = 'Kirana';
  String shopAddress = 'Ujjain, Madhya Pradesh';
  String vendorName = 'Raju Tea Stall';
  String vendorCategory = 'Tea / Snacks';
  DemoBill? selectedBill;
  String supportReference = 'PP-SUP-1042';
  String lastNotice = '';
  String language = 'English';
  bool notificationsEnabled = true;
  bool spendingSummaryEnabled = true;
  bool productUpdatesEnabled = false;

  final List<DemoBill> bills = <DemoBill>[
    DemoBill(id: 'PP-10482', store: 'Sharma Kirana Store', items: <BillLine>[
      BillLine(name: 'Maggi', quantity: 1, unitPrice: 40),
      BillLine(name: 'Bread', quantity: 1, unitPrice: 30),
      BillLine(name: 'Milk', quantity: 1, unitPrice: 50),
      BillLine(name: 'Chips', quantity: 1, unitPrice: 60),
    ], createdAt: DateTime(2026, 10, 12, 17, 24), paymentMode: 'Cash', isSaved: true),
    DemoBill(id: 'PP-10481', store: 'Gupta General Store', items: <BillLine>[
      BillLine(name: 'Household items', quantity: 1, unitPrice: 240),
    ], createdAt: DateTime(2026, 10, 10, 11, 8), paymentMode: 'UPI', isSaved: true),
    DemoBill(id: 'PP-10480', store: 'Fresh Mart', items: <BillLine>[
      BillLine(name: 'Groceries', quantity: 1, unitPrice: 320),
    ], createdAt: DateTime(2026, 10, 8, 18, 42), paymentMode: 'UPI', isSaved: true),
    DemoBill(id: 'PP-10470', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Grocery order', quantity: 1, unitPrice: 450),
    ], createdAt: DateTime(2026, 10, 12, 12), paymentMode: 'Udhaar', customerPhone: '•••• 4421', isUdhaar: true, isSettled: false, isSaved: false),
    DemoBill(id: 'PP-10462', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Walk-in purchase', quantity: 1, unitPrice: 300),
    ], createdAt: DateTime(2026, 10, 11, 16), paymentMode: 'Udhaar', isUdhaar: true, isSettled: false, isSaved: false),
    DemoBill(id: 'PP-10455', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Household order', quantity: 1, unitPrice: 650),
    ], createdAt: DateTime(2026, 10, 10, 10), paymentMode: 'Udhaar', customerPhone: '•••• 1184', isUdhaar: true, isSettled: false, isSaved: false),
  ];

  final List<DemoExpense> expenses = <DemoExpense>[
    DemoExpense(title: 'Stock purchase', category: 'Stock', amount: 300, createdAt: DateTime(2026, 10, 19, 10, 30)),
    DemoExpense(title: 'Transport', category: 'Transport', amount: 150, createdAt: DateTime(2026, 10, 19, 9, 20)),
  ];
  final Set<String> savedShops = <String>{'Sharma Kirana Store', 'Gupta General Store', 'Fresh Mart'};
  int _billSequence = 10500;
  int _vendorBillSequence = 2403;

  void go(String nextPage) {
    page = nextPage;
    notifyListeners();
  }

  void setRole(UserRole value) {
    role = value;
    page = switch (value) {
      UserRole.customer => 'customerSetup',
      UserRole.shopOwner => 'shopSetup',
      UserRole.streetVendor => 'vendorSetup',
    };
    notifyListeners();
  }

  String get activeStoreName => role == UserRole.streetVendor ? vendorName : shopName;

  List<DemoBill> get customerBills => bills.where((bill) => bill.isSaved).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get shopBills => bills.where((bill) => bill.store == shopName || bill.store == vendorName)
    .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get udhaarBills => bills.where((bill) => bill.isUdhaar && !bill.isSettled).toList();

  double get recordedSales => shopBills.where((b) => !b.isUdhaar).fold<double>(0, (sum, bill) => sum + bill.total);
  double get expensesTotal => expenses.fold<double>(0, (sum, item) => sum + item.amount);
  double get outstandingTotal => udhaarBills.fold<double>(0, (sum, bill) => sum + bill.total);

  void openBill(DemoBill bill) {
    selectedBill = bill;
    page = 'billDetail';
    notifyListeners();
  }

  DemoBill createBill({
    required List<BillLine> items,
    required String paymentMode,
    String customerPhone = '',
    required bool vendorMode,
  }) {
    final bill = DemoBill(
      id: vendorMode ? 'PP-${_vendorBillSequence++}' : 'PP-${_billSequence++}',
      store: vendorMode ? vendorName : shopName,
      items: List<BillLine>.from(items),
      createdAt: DateTime.now(),
      paymentMode: paymentMode,
      customerPhone: customerPhone,
      isUdhaar: paymentMode == 'Udhaar',
      isSaved: false,
    );
    bills.insert(0, bill);
    selectedBill = bill;
    page = vendorMode ? 'vendorReceipt' : 'receipt';
    notifyListeners();
    return bill;
  }

  void saveSelectedBill() {
    if (selectedBill != null) {
      selectedBill!.isSaved = true;
      lastNotice = 'Receipt saved to My Bills (demo).';
      notifyListeners();
    }
  }

  void markSettled(DemoBill bill) {
    bill.isSettled = true;
    lastNotice = '${bill.id} marked as settled (demo).';
    notifyListeners();
  }

  void addExpense({required String title, required String category, required double amount}) {
    expenses.insert(0, DemoExpense(title: title.trim().isEmpty ? 'Other expense' : title.trim(), category: category, amount: amount, createdAt: DateTime.now()));
    lastNotice = 'Expense recorded locally (demo).';
    page = 'expenseSaved';
    notifyListeners();
  }

  void toggleSavedShop(String name) {
    if (savedShops.contains(name)) {
      savedShops.remove(name);
    } else {
      savedShops.add(name);
    }
    notifyListeners();
  }

  void submitSupport() {
    supportReference = 'PP-SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    page = 'supportSubmitted';
    notifyListeners();
  }

  void updateProfile({required String name, required String email, required String location}) {
    customerName = name.trim().isEmpty ? customerName : name.trim();
    customerEmail = email.trim();
    city = location.trim().isEmpty ? city : location.trim();
    lastNotice = 'Profile updated locally (demo).';
    page = 'customerProfile';
    notifyListeners();
  }

  void updateShop({required String name, required String category, required String address}) {
    shopName = name.trim().isEmpty ? shopName : name.trim();
    shopCategory = category;
    shopAddress = address.trim().isEmpty ? shopAddress : address.trim();
    page = 'shopHome';
    notifyListeners();
  }

  void updateVendor({required String name, required String category}) {
    vendorName = name.trim().isEmpty ? vendorName : name.trim();
    vendorCategory = category;
    page = 'vendorHome';
    notifyListeners();
  }
}
